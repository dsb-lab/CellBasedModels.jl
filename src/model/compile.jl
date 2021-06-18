"""
    function compile(abm,space=SimulationFree();platform="cpu", integrator = "euler", save = "RAM", debug = false, user_=true)

Function that takes an Agent and a simulation space and constructs the function in charge of the evolutions of the model.
"""
function compile(abm::Union{Agent,Array{Agent}},space::SimulationSpace=SimulationFree();platform="cpu", integrator::String = "Euler", save::String = "RAM", debug = false, user_=true)

    p = Program_()

    #Update
    updates_!(p,abm)

    #Neighbours declare
    arguments_!(p,abm,space,platform)
    
    #Declare all the agent properties related functions, arguments, code...
    addCleanInteraction_!(p,abm,space,platform)
    addParameters_!(p,abm,space,platform)
    addIntegrator_![integrator](p,abm,space,platform)
    addUpdateGlobal_!(p,abm,space,platform)
    addUpdateLocal_!(p,abm,space,platform)
    addUpdateLocalInteraction_!(p,abm,space,platform)
    addUpdate_!(p,abm,space,platform)
    
    #Saving
    addSaving_![save](p,abm,space,platform)

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

    if platform == "cpu"
        program = postwalk(x->@capture(x,@platformAdapt v_(ARGS__)) ? :($v(ARGS_)) : x, program)
    elseif platform == "gpu"
        program = postwalk(x->@capture(x,@platformAdapt v_(ARGS__)) ? :(@cuda $v(ARGS_)) : x, program)
        program = cudaAdapt_(program)
    end
    program = subsArguments_(program,:ARGS_,p.args)
    program = randomAdapt_(p,program,platform)
    program = gensym_ids(program)
    
    if debug == true
        println(prettify(program))
    end

    if user_ == true
        model = Model(abm,space,Base.MainInclude.eval(program))
    else
        model = Model(abm,space,AgentBasedModel.eval(program))
    end

    return model
end
