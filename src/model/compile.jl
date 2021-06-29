"""
    function compile(abm,space=SimulationFree();platform="cpu", integrator = "euler", save = "RAM", debug = false, user_=true)

Function that takes an Agent and a simulation space and constructs the function in charge of the evolutions of the model.
"""
function compile(abmOriginal::Union{Agent,Array{Agent}},space::SimulationSpace=SimulationFree();platform="cpu", integrator::String = "Euler", save::String = "RAM", debug = false, user_=true)

    abm = deepcopy(abmOriginal)
    
    p = Program_()

    #Update
    updates_!(p,abm,space)

    #Neighbours declare
    arguments_!(p,abm,space,platform)
    
    #Declare all the agent properties related functions, arguments, code...
    addCleanInteraction_!(p,abm,space,platform)
    addCleanLocalInteraction_!(p,abm,space,platform)
    addParameters_!(p,abm,space,platform)
    addCopyInitialisation_!(p,abm,space,platform)
    addIntegrator_![integrator](p,abm,space,platform)
    addUpdateGlobal_!(p,abm,space,platform)
    addUpdateLocal_!(p,abm,space,platform)
    addUpdateLocalInteraction_!(p,abm,space,platform)
    addCheckBounds_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)
    addUpdate_!(p,abm,space,platform)
    #Events
    addEventDivision_!(p,abm,space,platform)
    addEventDeath_!(p,abm,space,platform)


    #Saving
    addSaving_![save](p,abm,space,platform)

    if platform == "gpu"
        gpuConf = :()
    end

    program = quote
        function (com::Community; dt::Real, tMax::Real, t::Real=com.t, N::Integer=com.N, nMax::Integer=com.N, 
                dtSave::Real=dt,tSave::Real=0,saveFolder::String="")
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
        model = Model(abm,space,program,Main.eval(program))
    else
        model = Model(abm,space,program,AgentBasedModels.eval(program))
    end

    return model
end
