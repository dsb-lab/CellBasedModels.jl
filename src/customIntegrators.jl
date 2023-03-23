################################################################
# ODE
################################################################



##########################################
# Euler
##########################################

mutable struct CustomEuler

    f
    p
    u
    t
    du
    dt

    function CustomEuler(problem,kwargs)

        return new(problem.f,problem.p,problem.u0,problem.tspan[1],copy(problem.u0),kwargs[:dt])

    end

end

function DifferentialEquations.step!(obj::CustomEuler,dt=obj.dt,_=nothing)

    obj.f(obj.du,obj.u,obj.p,obj.t)

    if typeof(obj.du) <: Array
        r = 1:obj.p[3][1]
        obj.u[r] .+= obj.du[r].*dt
    else
        obj.u .+= obj.du.*dt

    end

    obj.t += obj.dt

    return

end

##########################################
# Heun
##########################################

mutable struct CustomHeun

    f
    p
    u
    t
    du
    h1
    dt

    function CustomHeun(problem,kwargs)

        return new(problem.f,problem.p,problem.u0,problem.tspan[1],copy(problem.u0),copy(problem.u0),kwargs[:dt])

    end

end

function DifferentialEquations.step!(obj::CustomHeun,dt=obj.dt,_=nothing)

    #First step
    obj.f(obj.du,obj.u,obj.p,obj.t)

    #Save step in h1
    if typeof(obj.du) <: Array
        r = 1:obj.p[3][1]
        obj.h1[r] .= obj.u[r] .+ obj.du[r].*dt
    else
       obj.h1 .= obj.u .+ obj.du.*dt
    end

    #Second step
    obj.f(obj.du,obj.h1,obj.p,obj.t+obj.dt)

    #Compute step inplace
    if typeof(obj.du) <: Array
        r = 1:obj.p[3][1]
        obj.u[r] .= ( obj.h1[r] .+ (obj.u[r] .+ obj.du[r].*dt) ) ./ 2
    else
       obj.h1 .= ( obj.h1 .+ ( obj.u .+ obj.du.*dt ) ) ./ 2
    end

    obj.t += obj.dt

    return

end

##########################################
# RungeKutta4
##########################################
mutable struct CustomRungeKutta4

    f
    p
    u
    t
    h1
    k1
    k2
    k3
    k4
    dt

    function CustomRungeKutta4(problem,kwargs)

        return new(problem.f,problem.p,problem.u0,problem.tspan[1],copy(problem.u0),copy(problem.u0),copy(problem.u0),copy(problem.u0),copy(problem.u0),kwargs[:dt])

    end

end

function DifferentialEquations.step!(obj::CustomRungeKutta4,dt=obj.dt,_=nothing)

    #First step
    obj.f(obj.k1,obj.u,obj.p,obj.t)

    #Save step in h1
    if typeof(obj.u) <: Array
        r = 1:obj.p[3][1]
        obj.h1[r] .= obj.u[r] .+ obj.k1[r].*dt ./2
    else
       obj.h1 .= obj.u .+ obj.k1.*dt./2
    end

    #Second step
    obj.f(obj.k2,obj.h1,obj.p,obj.t+obj.dt/2)

    #Save step in h1
    if typeof(obj.u) <: Array
        r = 1:obj.p[3][1]
        obj.h1[r] .= obj.u[r] .+ obj.k2[r].*dt ./2
    else
        obj.h1 .= obj.u .+ obj.k2.*dt./2
    end

    #Third step
    obj.f(obj.k3,obj.h1,obj.p,obj.t+obj.dt/2)

    #Save step in h1
    if typeof(obj.u) <: Array
        r = 1:obj.p[3][1]
        obj.h1[r] .= obj.u[r] .+ obj.k3[r].*dt
    else
        obj.h1 .= obj.u .+ obj.k3.*dt
    end

    #Fourth step
    obj.f(obj.k4,obj.h1,obj.p,obj.t+obj.dt/2)

    #Compute step inplace
    if typeof(obj.u) <: Array
        r = 1:obj.p[3][1]
        obj.u[r] .= obj.u[r] .+ ( obj.k1[r] .+ 2 .* obj.k2[r] .+ 2 .* obj.k3[r] .+ obj.k4[r]) .*dt ./ 6
    else
        obj.u .= obj.u .+ ( obj.k1 .+ 2 .* obj.k2 .+ 2 .* obj.k3 .+ obj.k4 ) .*dt ./ 6
    end

    obj.t += obj.dt

    return

end

################################################################
# SDE
################################################################





################################################################
# Init
################################################################

function DifferentialEquations.init(problem::DifferentialEquations.SciMLBase.AbstractDEProblem,alg::Symbol;kwargs...)

    if alg == :Euler

        return CustomEuler(problem,kwargs)

    elseif alg == :Heun

        return CustomHeun(problem,kwargs)

    elseif alg == :RungeKutta4

        return CustomRungeKutta4(problem,kwargs)

    else

        error("No custom algorithm implemented with this name.")

    end

end
