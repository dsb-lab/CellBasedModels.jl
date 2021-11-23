"""
Structure containing the agents definitions and the simulation space. It incorporates a function evolve that is the compiled program for running simulations.
"""
struct Model
    agent::Agent

    program::Expr
    evolve::Function
end