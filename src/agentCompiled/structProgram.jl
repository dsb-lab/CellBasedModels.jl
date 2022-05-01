"""
    mutable struct Program_

Auxiliar structure used to keep all the intermediate parts of the code before creating the final `evolve` function of the `AgentCompiled` struture.

# Elements
 - **agent::Agent**: Agent struture with the raw definition of the agent.
 - **integrator::String**: Integrator for `UpdateVariable`.
 - **integratorMedium::String**: Integrator for `UpdateMedium`.
 - **neighbors::String**: Neighbors algorithm for `UpdateInteraction`.
 - **neighborsPeriodic::Vector{Bool}**: Whether the boundary is periodic.
 - **declareVar::Expr**: Code containing the declaration of variables.
 - **declareF::Expr**: Code containing the declaration of functions.
 - **args::Array{Symbol,1}**: Arguments of the functions to be declared.
 - **execInit::Expr**: Code to be executed before the steps start.
 - **execInloop::Expr**: Code to be executed after the steps start.
 - **execAfter::Expr**: Code to be executed after the steps have finished.
 - **returning::Expr**: Code indicating what to return in the end of the evolution function.
 - **velocities::Dict{Symbol,Symbol}**: Velocities symbols (For VerletVelocity integration).
 - **update::Dict{String,Dict{Symbol,Int}}**: Varibales to be updated and their corresponding locations.
"""
mutable struct Program_

    agent::Agent
    integrator::String
    integratorMedium::String
    neighbors::String
    neighborsPeriodic::Vector{Bool}
    declareVar::Expr
    declareF::Expr
    args::Array{Symbol,1}
    execInit::Expr
    execInloop::Expr
    execAfter::Expr
    returning::Expr
    velocities::Dict{Symbol,Symbol}
    update::Dict{String,Dict{Symbol,Int}}

end

function Program_(abm::Agent)
    return Program_(abm,"Euler","FTCS","full",Vector{Bool}([false,false,false]),quote end,quote end,Array{Symbol,1}(BASICARGS),
                    quote end,quote end,quote end,quote end,Dict{Symbol,Symbol}(),Dict{String,Dict{Symbol,Int}}())
end