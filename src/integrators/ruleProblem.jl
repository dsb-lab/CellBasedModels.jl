import DifferentialEquations

struct RuleProblem <: DifferentialEquations.DEProblem

    f
    u0
    tspan
    p

end

mutable struct Rule

    problem
    u
    uNew
    dt
    t

end

function DifferentialEquations.init(problem::RuleProblem; dt::Real)

    return Rule(
        problem,
        copy(problem.u0),
        copy(problem.u0),
        dt,
        problem.tspan[1],
    )

end

function DifferentialEquations.reinit!(integrator::Rule, u; kwargs...)
    """
    Reinitialize a Rule integrator with a new mesh state.
    Updates both u and uNew to point to the new mesh object.
    
    Args:
        integrator: The Rule integrator to reinitialize
        u: The new mesh state to use
    """

    return Rule(
        integrator.problem,
        copy(u),
        copy(u),
        integrator.dt,
        integrator.problem.tspan[1],
    )

end

function DifferentialEquations.step!(integrator::Rule)

    integrator.problem.f(integrator.uNew, integrator.u, integrator.problem.p, integrator.t)

    if isOverflowed(integrator.uNew)
        return nothing
    else
        copyto!(integrator.u, integrator.uNew)

        integrator.t += integrator.dt

        return nothing
    end

end