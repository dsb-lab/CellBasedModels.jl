"""
    struct AgentCompiled

Structure containing the compiled code ready to be executed after calling `compile`.

# Elements
 - **agent::Agent**: `Agent` structure with the raw information when created.
 - **program::Expr**: `Expr` with the generated code.
 - **evolve::Function**: Compiled function to use for evolving the agents of a `Community` structure.
"""
struct AgentCompiled
    agent::Agent

    program::Expr
    evolve::Function
end