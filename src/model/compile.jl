"""
    function compile(abm,space=SimulationFree();platform="cpu", integrator = "euler", save = "RAM", debug = false, user_=true)

Function that takes an Agent and a simulation space and constructs the function in charge of the evolutions of the model.
"""
function compile(abmOriginal::Union{Agent,Array{Agent}},space::SimulationSpace=SimulationFree();platform="cpu", integrator::String = "Euler", save::String = "RAM", debug = false, user_=true)

    abm = deepcopy(abmOriginal)
    
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
    addEventDivision_!(p,abm,space,platform)
    addEventDeath_!(p,abm,space,platform)
    addUpdate_!(p,abm,space,platform)
    
    #Saving
    addSaving_![save](p,abm,space,platform)

    program = quote
        function (com::Community; dt::Real, tMax::Real, t::Real=com.t, N::Integer=com.N, nMax::Integer=com.N, $(p.argsEval...))
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
        program = postwalk(x->@capture(x,@platformAdapt v_(ARGS__)) ? :(@cuda $v(ARGS_)) : x, program)
        program = cudaAdapt_(program)
    end
    program = subsArguments_(program,:ARGS_,p.args)
    program = randomAdapt_(p,program,platform)
    program = gensym_ids(program)
    program = flatten(program)
    
    # if debug == true
    #     s = string(program)
    #     for (i,j) in enumerate(split(s,"\n"))
    #         println(string("#####",i,"#")[end-5:end]," ",j)
    #     end
    #     #println(program)
    # end

    if user_ == true
        model = Model(abm,space,program,Main.eval(program))
    else
        model = Model(abm,space,program,AgentBasedModels.eval(program))
    end

    return model
end
