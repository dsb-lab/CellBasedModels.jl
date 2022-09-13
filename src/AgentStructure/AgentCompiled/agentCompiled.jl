emptyFunction(Community) = nothing

"""
    struct AgentCompiled

Structure containing the compiled code ready to be executed after calling `compile`.

# Elements
 - **agent::Agent**: `Agent` structure with the raw information when created.
 - **program::Expr**: `Expr` with the generated code.
 - **evolve::Function**: Compiled function to use for evolving the agents of a `Community` structure.
"""
mutable struct AgentCompiled

    #Agent object
    agent::Agent
    platform::String
    integrator::String
    integratorMedium::String
    neighbors::String
    neighborsPeriodic::Vector{Bool}
    velocities::Dict{Symbol,Symbol}
    update::Dict{String,Dict{Symbol,Int}}

    #Functions
    f_initialise::Function
    f_update::Function
    f_neighbors::Function
    f_integration_step::Function
    f_step::Function
    f_interaction::Function
    f_save::Function
    evolve::Function

    #Code of functions
    program_initialise::Expr
    program_update::Expr
    program_neighbors::Expr
    program_integration_step::Expr
    program_step::Expr
    program_interaction::Expr
    program_save::Expr
    program_evolve::Expr

    function AgentCompiled(agent::Agent)
        new(
            agent,
            "cpu",
            "Euler",
            "FTCS",
            "full",
            Vector{Bool}([false,false,false]),
            Dict{Symbol,Symbol}(),
            Dict{String,Dict{Symbol,Int}}(),
            emptyFunction,
            emptyFunction,
            emptyFunction,
            emptyFunction,
            emptyFunction,
            emptyFunction,
            emptyFunction,
            emptyFunction,
            quote end,
            quote end,
            quote end,
            quote end,
            quote end,
            quote end,
            quote end,
            quote end,
        )
    end

end

