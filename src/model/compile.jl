"""
    function compile(abm=SimulationFree();platform="cpu", neighbours="full", integrator = "euler", save = "RAM", debug = false, user_=true)

Function that takes an Agent and a simulation and constructs the function in charge of the evolutions of the model.
"""
function compile(abmOriginal::Union{Agent,Array{Agent}}; platform="cpu", integrator::String = "Euler", integratorMedium::String = "FTCS", neighbors::String="full", save::String = "RAM", debug = false, user_=true)

    abm = deepcopy(abmOriginal)
    
    p = Program_(abm)
    p.integrator = integrator
    p.integratorMedium = integratorMedium
    p.neighbors = neighbors

    #Update
    updates_!(p)

    #Neighbours declare
    arguments_![neighbors](p,platform)
    
    #Declare all the agent properties related functions, arguments, code...
    addCleanInteraction_!(p,platform)
    addCleanLocalInteraction_!(p,platform)
    addParameters_!(p,platform)
    addCopyInitialisation_!(p,platform)
    addIntegrator_![integrator](p,platform)
    addUpdateGlobal_!(p,platform)
    addUpdateLocal_!(p,platform)
    addUpdateLocalInteraction_!(p,platform)
    # addCheckBounds_!(p,platform)
    addUpdateMediumInteraction_!(p,platform)
    addIntegratorMedium_![integratorMedium](p,platform)
    addUpdate_!(p,platform)
    #Events
    addEventDivision_!(p,platform)
    addEventDeath_!(p,platform)


    #Saving
    addSaving_![save](p,platform)

    if platform == "gpu"
        gpuConf = :()
    end

    program = quote
        function (com::Community; dt::Real, tMax::Real, t::Real=com.t, N::Integer=com.N, nMax::Integer=com.N, 
                dtSave::Real=dt,tSave::Real=0,saveFile::String="",box::Array{<:Real}=Array{Real,1}([]),r::Union{<:Real,Array{<:Real,1}}=Array{Real,1}([]))
            #Promoting to the correct type
            dt = Float64(dt)
            tMax = Float64(tMax)
            t = Float64(t)
            N = Int(N)
            #Declaration of variables
            $(p.declareVar)
            #Declaration of functions
            $(p.declareF)
            
            #Execution of the program
            
            $(p.execInit)
            while t <= (tMax-dt)
                $(p.execInloop)

                t += dt
            end
            $(p.execAfter)
                
            return $(p.returning)
        end
    end

    if platform == "cpu"
        program = postwalk(x->@capture(x,@platformAdapt v_(ARGS__)) ? :($v(ARGS_)) : x, program)
    elseif platform == "gpu"
        program = postwalk(x->@capture(x,@platformAdapt v_(ARGS__)) ? :(kernel_ = @cuda launch = false $v(ARGS_); 
                                                                    prop_ = AgentBasedModels.configurator_(kernel_,N); 
                                                                    kernel_(ARGS_;threads=prop_[1],blocks=prop_[2])) : x, program)
        program = cudaAdapt_(program)
    end
    program = subsArguments_(program,:ARGS_,p.args)
    program = randomAdapt_(p,program,platform)
    programugly = gensym_ids(program)
    program = flatten(programugly)
    
    if debug == true
        println(prettify(programugly))
    end

    if user_ == true
        model = Model(abm,program,Main.eval(program))
    else
        model = Model(abm,program,AgentBasedModels.eval(program))
    end

    return model
end
