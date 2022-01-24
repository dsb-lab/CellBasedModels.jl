"""
    function compile(abm=SimulationFree();platform="cpu", neighbors="full", integrator = "euler", save = "RAM", debug = false, user_=true)

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
    addParameters_!(p,platform)
    addCopyInitialisation_!(p,platform)
    addIntegrator_![integrator](p,platform)
    addUpdateGlobal_!(p,platform)
    addUpdateLocal_!(p,platform)
    addUpdateLocalInteraction_!(p,platform)
    addCheckBounds_!(p,platform)
    addUpdateMediumInteraction_!(p,platform)
    addIntegratorMedium_![integratorMedium](p,platform)
    addUpdate_!(p,platform)

    #Saving
    addSaving_![save](p,platform)

    if platform == "cpu"
        declareCheckNMax = :(limNMax_ = Threads.Atomic{$INT}(1))
        checkNMax = :(limNMax_[] == 1)
    else
        gpuConf = :()

        declareCheckNMax = :(limNMax_ = CUDA.ones($INTCUDA,1))
        checkNMax = :(Core.Array(limNMax_)[1] == 1)
    end

    cleanLocal = :()
    if !isempty(p.agent.declaredSymbols["LocalInteraction"])
        cleanLocal = :(localInteractionV .= 0)
    end
    cleanInteraction = :()
    if !isempty(p.agent.declaredSymbols["IdentityInteraction"])
        cleanInteraction = :(identityInteractionV .= 0)
    end

    program = quote
        function (com::Community;
                dt::Real, tMax::Real,
                nMax::Integer=com.N, 
                dtSave::Real=dt,
                tSave::Real=0, saveFile::String="")
            #Promoting to the correct type
            dt = $FLOAT(dt)
            tMax = $FLOAT(tMax)
            t = $FLOAT(com.t)
            N = $INT(com.N)
            $declareCheckNMax
            #Declaration of variables
            $(p.declareVar)
            #Declaration of functions
            $(p.declareF)
            
            #Execution of the program
            
            $(p.execInit)
            while t <= (tMax-dt) && $checkNMax
                $cleanLocal
                $cleanInteraction
                $(p.execInloop)

                t += dt
            end

            if $checkNMax
                $(p.execAfter)
            else
                @warn("nMax exceded at t=$t. Please, call again the system declaring a bigger size.")
            end            
            return $(p.returning)
        end
    end

    if platform == "cpu"
        program = postwalk(x->@capture(x,@platformAdapt v_(ARGS__)) ? :($v($(ARGS...))) : x, program)
    elseif platform == "gpu"
        program = postwalk(x->@capture(x,@platformAdapt v_(ARGS__)) ? :(kernel_ = @cuda launch = false $v($(ARGS...)); 
                                                                    prop_ = AgentBasedModels.configurator_(kernel_,N); 
                                                                    kernel_($(ARGS...);threads=prop_[1],blocks=prop_[2])) : x, program)
        program = cudaAdapt_(program)
    end
    program = postwalk(x->@capture(x,v_(g_)) && g == :ARGS_ ? :($v($(p.args...))) : x, program)
    program = postwalk(x->@capture(x,v_(g_;h__)) && g == :ARGS_ ? :($v($(p.args...);$(h...))) : x, program)
    program = randomAdapt_(p,program,platform)
    programugly = gensym_ids(program)
    program = flatten(programugly)
    
    if debug == true
        println(prettify(programugly))
    end

    model = Model(abm,program,Main.eval(program))

    return model
end
