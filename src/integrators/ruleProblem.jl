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

function DifferentialEquations.step!(integrator::Rule)

    integrator.problem.f(integrator.uNew, integrator.u, integrator.problem.p, integrator.t)

    copyto!(integrator.u, integrator.uNew)

    integrator.t += integrator.dt

    return nothing

end