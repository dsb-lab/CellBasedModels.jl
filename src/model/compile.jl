"""
    function compile(abm,space=SimulationFree();platform="cpu", integrator = "euler", save = "RAM", debug = false, user_=true)

Function that takes an Agent and a simulation space and constructs the function in charge of the evolutions of the model.
"""
function compile(abm::Union{Agent,Array{Agent}},space::SimulationSpace=SimulationFree();platform="cpu", integrator::String = "euler", save::String = "RAM", debug = false, user_=true)

    p = Program_()

    #Neighbours declare
    arguments_!(abm,space,p,platform)
    
    #Declare all the agent properties related functions, arguments, code...
    addParameters_!(abm,space,p,platform)
    #addEquations_!(abm,space,p,platform)
    addUpdateGlobal_!(abm,space,p,platform)
    addUpdateLocal_!(abm,space,p,platform)
    addUpdateLocalInteraction_!(abm,space,p,platform)
    #addUpdate_!(abm,space,p,platform)
    
    #Saving
    #save_!(abm,space,platform=platform)

    program = quote
        function (com::Community;$(p.argsEval...),tMax, dt, t=com.t, N=com.N, nMax=com.N)
            #Declaration of variables
            $(p.declareVar)
            #Declaration of functions
            $(p.declareF)
            
            #Execution of the program
            
            $(p.execInit)
            while t <= tMax
                $(p.execInloop)

                t += dt
            end
            $(p.execAfter)
                
            return $(p.returning)
        end
    end
    program = subsArguments_(program,:ARGS_,p.args)
    if platform == "gpu"
        program = cudaAdapt_(program)
    end
    
    if debug == true
        println(clean(copy(program)))
    end

    if user_ == true
        model = Model(abm,space,Base.MainInclude.eval(program))
    else
        model = Model(abm,space,AgentBasedModel.eval(program))
    end

    return model
end
