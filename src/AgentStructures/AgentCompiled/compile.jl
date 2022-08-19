"""
    function compile(abmOriginal::Agent;
                    platform::String="cpu", 
                    neighbors::String="full", 
                    periodic::Vector{Bool}=[false,false,false],
                    integrator::String = "Euler", 
                    integratorMedium::String = "FTCS", 
                    save::String = "RAM", 
                    showPorgress::Bool = false,
                    checkInBounds::Bool=true)

Function that takes an Agent and creates the code to use for evolving the model.

# Args
 - **abmOriginal::AgentCompiled** : AgentCompiled to be compiled

# KwArgs
 - **platform::String ="cpu"** : Platfrom to compile the model on. Choose between "cpu" or "gpu".
 - **neighbors::String ="full"** : Algorithm to compute the neigbours of each agent. Choose between "full" or "grid".
 - **periodic::Vector{Bool}=[false,false,false]** : If agents are in  periodic boundary conditions and neighbors = "grid", connects the edge boxes.
 - **integrator::String = "Euler"** : Integrator used for agent based models equation sdeclared in UpdateVariable.
 - **integratorMedium::String = "FTCS"** : Integrator used for agent based models declared in UpdateMedium.
 - **save::String = "RAM"** : Place to save the outcome of the simulations. Choose between "RAM", "JLD" (julia datafile format) and "CSV" (not recomended).
 - **showPorgress::Bool = false**: Wheter to show a progress bar of the evolution.
 - **checkInBounds::Bool=true** : Wheter to add @checkinbounds to all the for loops in the functions.

# Returns
 - `AgentCompiled` structure with the code generated and compiled ready for evolve a `Community`.
"""
function compile(abmOriginal::Union{Agent,Array{Agent}}; 
    platform::String ="cpu", 
    integrator::String = "Euler", 
    velocities::Dict{Symbol,Symbol} = Dict{Symbol,Symbol}(),
    integratorMedium::String = "FTCS", 
    neighbors::String="full",
    periodic::Vector{Bool}=[false,false,false],
    save::String = "RAM", 
    showProgress::Bool = false,
    checkInBounds::Bool=true)

    abm = deepcopy(abmOriginal)
    abm = AgentCompiled(abm)

    #Update
    updates_!(abm)

#     #Neighbours declare
#     arguments_![neighbors](p,platform)
    
    #Declare all the agent properties related functions, arguments, code...
    addCopyInitialisation_!(abm)
    neighborsF_![neighbors](abm)
    addUpdateInteraction_!(abm)
    addIntegrator_![integrator](abm)
#     addUpdateMediumInteraction_!(p,platform)
#     addIntegratorMedium_![integratorMedium](p,platform)
#     addUpdateGlobal_!(p,platform)
#     addUpdateLocal_!(p,platform)
# #    addCheckBounds_!(p,platform)
#     addUpdate_!(p,platform)

#     #Saving
#     addSaving_![save](p,platform)

#     if platform == "cpu"
#         declareCheckNMax = :(limNMax_ = Threads.Atomic{$INT}(1))
#         checkNMax = :(limNMax_[] == 1)
#     else
#         gpuConf = :()

#         declareCheckNMax = :(limNMax_ = CUDA.ones($INTCUDA,1))
#         checkNMax = :(Core.Array(limNMax_)[1] == 1)
#     end

#     cleanLocal = :()
#     if !isempty(p.agent.declaredSymbols["LocalInteraction"])
#         cleanLocal = :(localInteractionV .= 0)
#     end
#     cleanInteraction = :()
#     if !isempty(p.agent.declaredSymbols["IdentityInteraction"])
#         cleanInteraction = :(identityInteractionV .= 0)
#     end

#     program = quote
#         function (com::Community;
#                 dt::Real, tMax::Real, nStop::Real=Inf,
#                 nMax::Integer=com.N, 
#                 dtSave::Real=dt, 
#                 saveFile::String="",
#                 relativeErrorIntegrator::Real=10E-2,
#                 learningRateIntegrator::Real=1.,
#                 maxLearningStepsIntegrator::Int=100)
#             #Promoting to the correct type
#             dt = $FLOAT(dt)
#             tMax = $FLOAT(tMax)
#             t = $FLOAT(com.t)
#             N = $INT(com.N)
#             nSteps_ = Int(round((tMax-t)/dt))
#             nSave_ = max(Int(round(dtSave/dt)),1)
#             countSave_ = 1
#             $declareCheckNMax
#             #Declaration of variables
#             $(p.declareVar)
#             #Declaration of functions
#             $(p.declareF)
            
#             #Execution of the program
            
#             $(p.execInit)
#             timeStart_ = time()
#             for step_ in 1:nSteps_
#                 $cleanLocal
#                 $cleanInteraction
#                 $(p.execInloop)

#                 t += dt

#                 if !($checkNMax)
#                     break
#                 end

#                 if N > nStop
#                     break
#                 end
#             end

#             if $checkNMax
#                 $(p.execAfter)
#             else
#                 @warn("nMax exceded at t=$t. Please, call again the system declaring a bigger size.")
#             end            
#             return $(p.returning)
#         end
#     end

#     if showProgress
#         program = postwalk(x->@capture(x,for i in 1:Int(round(tMax-dt)/dt) v__ end) ? 
#         :(AgentBasedModels.@showprogress(for i in 1:Int(round(tMax-dt)/dt); $(v...) end)) : x, program)
#     end

#     program = postwalk(x->@capture(x,v_(g_)) && g == :ARGS_ ? :($v($(p.args...))) : x, program)
#     program = postwalk(x->@capture(x,v_(g_;h__)) && g == :ARGS_ ? :($v($(p.args...);$(h...))) : x, program)
#     program = randomAdapt_(p,program,platform)
#     if checkInBounds
#         program = postwalk(x->@capture(x,Threads.@threads f_) ? :(@inbounds Threads.@threads $f) : x, program)
#     end
#     program = flatten(program)
    
#     #Prettify the LineNumberNode output
#     program = postwalk(x -> isexpr(x,LineNumberNode) ? LineNumberNode(Meta.parse(split(String(gensym("x")),"#")[end]),"evolve_program") : x, program)

    return abm
end
