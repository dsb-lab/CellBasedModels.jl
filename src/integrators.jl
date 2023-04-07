module CBMIntegrators

    export CustomIntegrator

    using DifferentialEquations
    using Random

    abstract type CustomIntegrator end

    ################################################################
    # ODE
    ################################################################

    ##########################################
    # Euler
    ##########################################

"""
    mutable struct Euler <: CustomIntegrator

Euler integrator for ODE problems.
"""
    mutable struct Euler <: CustomIntegrator

        f
        p
        u
        t
        du
        dt

        function Euler(problem,kwargs)

            return new(problem.f,problem.p,problem.u0,problem.tspan[1],copy(problem.u0),kwargs[:dt])

        end

        function Euler()

            return new(nothing,nothing,nothing,nothing,nothing,nothing)

        end

    end

    function DifferentialEquations.step!(obj::Euler,dt=obj.dt,_=nothing)

        obj.f(obj.du,obj.u,obj.p,obj.t)

        if typeof(obj.du) <: Array
            r = 1:obj.p[3][1]
            obj.u[:,r] .+= obj.du[:,r].*dt
        else
            obj.u .+= obj.du.*dt
        end

        obj.t += dt

        return

    end

    ##########################################
    # Heun
    ##########################################

"""
    mutable struct Heun <: CustomIntegrator

Heun integrator for ODE problems.
"""
    mutable struct Heun <: CustomIntegrator

        f
        p
        u
        t
        du
        h1
        dt

        function Heun(problem,kwargs)

            return new(problem.f,problem.p,problem.u0,problem.tspan[1],copy(problem.u0),copy(problem.u0),kwargs[:dt])

        end

        function Heun()

            return new(nothing,nothing,nothing,nothing,nothing,nothing,nothing)

        end


    end

    function DifferentialEquations.step!(obj::Heun,dt=obj.dt,_=nothing)

        #First step
        obj.f(obj.du,obj.u,obj.p,obj.t)

        #Save step in h1
        if typeof(obj.du) <: Array
            r = 1:obj.p[3][1]
            obj.h1[:,r] .= obj.u[:,r] .+ obj.du[:,r].*dt
        else
        obj.h1 .= obj.u .+ obj.du.*dt
        end

        #Second step
        obj.f(obj.du,obj.h1,obj.p,obj.t+dt)

        #Compute step inplace
        if typeof(obj.du) <: Array
            r = 1:obj.p[3][1]
            obj.u[:,r] .= ( obj.h1[:,r] .+ (obj.u[:,r] .+ obj.du[:,r].*dt) ) ./ 2
        else
        obj.u .= ( obj.h1 .+ ( obj.u .+ obj.du.*dt ) ) ./ 2
        end

        obj.t += dt

        return

    end

    ##########################################
    # RungeKutta4
    ##########################################
"""
    mutable struct RungeKutta4 <: CustomIntegrator

RungeKutta4 for ODE integrators
"""
    mutable struct RungeKutta4 <: CustomIntegrator

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

        function RungeKutta4(problem,kwargs)

            return new(problem.f,problem.p,problem.u0,problem.tspan[1],copy(problem.u0),copy(problem.u0),copy(problem.u0),copy(problem.u0),copy(problem.u0),kwargs[:dt])

        end

        function RungeKutta4()

            return new(nothing,nothing,nothing,nothing,nothing,nothing,nothing,nothing,nothing,nothing)

        end

    end

    function DifferentialEquations.step!(obj::RungeKutta4,dt=obj.dt,_=nothing)

        #First step
        obj.f(obj.k1,obj.u,obj.p,obj.t)

        #Save step in h1
        if typeof(obj.u) <: Array
            r = 1:obj.p[3][1]
            obj.h1[:,r] .= obj.u[:,r] .+ obj.k1[:,r].*dt ./2
        else
        obj.h1 .= obj.u .+ obj.k1.*dt./2
        end

        #Second step
        obj.f(obj.k2,obj.h1,obj.p,obj.t+dt/2)

        #Save step in h1
        if typeof(obj.u) <: Array
            r = 1:obj.p[3][1]
            obj.h1[:,r] .= obj.u[:,r] .+ obj.k2[:,r].*dt ./2
        else
            obj.h1 .= obj.u .+ obj.k2.*dt./2
        end

        #Third step
        obj.f(obj.k3,obj.h1,obj.p,obj.t+dt/2)

        #Save step in h1
        if typeof(obj.u) <: Array
            r = 1:obj.p[3][1]
            obj.h1[:,r] .= obj.u[:,r] .+ obj.k3[:,r].*dt
        else
            obj.h1 .= obj.u .+ obj.k3.*dt
        end

        #Fourth step
        obj.f(obj.k4,obj.h1,obj.p,obj.t+dt/2)

        #Compute step inplace
        if typeof(obj.u) <: Array
            r = 1:obj.p[3][1]
            obj.u[:,r] .= obj.u[:,r] .+ ( obj.k1[:,r] .+ 2 .* obj.k2[:,r] .+ 2 .* obj.k3[:,r] .+ obj.k4[:,r]) .*dt ./ 6
        else
            obj.u .= obj.u .+ ( obj.k1 .+ 2 .* obj.k2 .+ 2 .* obj.k3 .+ obj.k4 ) .*dt ./ 6
        end

        obj.t += dt

        return

    end

    ################################################################
    # SDE
    ################################################################


    ##########################################
    # EM
    ##########################################
"""
    mutable struct EM <: CustomIntegrator

Euler-Majurana integrator for SDE poblems.
"""
    mutable struct EM <: CustomIntegrator

        f
        g
        p
        u
        t
        du_f
        du_g
        rand
        dt

        function EM(problem,kwargs)

            return new(problem.f,problem.g,problem.p,problem.u0,problem.tspan[1],copy(problem.u0),copy(problem.u0),copy(problem.u0),kwargs[:dt])

        end

        function EM()

            return new(nothing,nothing,nothing,nothing,nothing,nothing,nothing,nothing,nothing)

        end

    end

    function DifferentialEquations.step!(obj::EM,dt=obj.dt,_=nothing)

        #First step
        obj.f(obj.du_f,obj.u,obj.p,obj.t)
        obj.g(obj.du_g,obj.u,obj.p,obj.t)
        Random.randn!(obj.rand)

        #Save step
        if typeof(obj.u) <: Array
            r = 1:obj.p[3][1]
            Random.randn!(@views(obj.rand[r]))
            obj.u[:,r] .= obj.u[:,r] .+ obj.du_f[:,r].*dt .+ obj.du_g[:,r] .* obj.rand[:,r] .* sqrt(dt)
        else
            Random.randn!(obj.rand)
            obj.u .= obj.u .+ obj.du_f .*dt .+ obj.du_g .* obj.rand .* sqrt(dt)
        end

        obj.t += dt

        return

    end

    ##########################################
    # EulerHeun
    ##########################################
"""
    mutable struct EulerHeun <: CustomIntegrator

Euler-Heun method for SDE integration.
"""
    mutable struct EulerHeun <: CustomIntegrator

        f
        g
        p
        u
        t
        du_f1
        du_g1
        du_f2
        du_g2
        h1
        rand
        dt

        function EulerHeun(problem,kwargs)

            return new(problem.f,problem.g,problem.p,problem.u0,problem.tspan[1],copy(problem.u0),copy(problem.u0),copy(problem.u0),copy(problem.u0),copy(problem.u0),copy(problem.u0),kwargs[:dt])

        end

        function EulerHeun()

            return new(nothing,nothing,nothing,nothing,nothing,nothing,nothing,nothing,nothing,nothing,nothing,nothing)

        end

    end

    function DifferentialEquations.step!(obj::EulerHeun,dt=obj.dt,_=nothing)

        #First step
        obj.f(obj.du_f1,obj.u,obj.p,obj.t)
        obj.g(obj.du_g1,obj.u,obj.p,obj.t)

        #Step h1
        if typeof(obj.u) <: Array
            r = 1:obj.p[3][1]
            Random.randn!(@views(obj.rand[r]))
            obj.h1[:,r] .= obj.u[:,r] .+ obj.du_f1[:,r].*dt .+ obj.du_g1[:,r] .* obj.rand[:,r] .* sqrt(dt)
        else
            Random.randn!(obj.rand)
            obj.h1 .= obj.u .+ obj.du_f1 .*dt .+ obj.du_g1 .* obj.rand .* sqrt(dt)
        end

        #Second step
        obj.f(obj.du_f2,obj.h1,obj.p,obj.t+dt)
        obj.g(obj.du_g2,obj.h1,obj.p,obj.t+dt)
        Random.randn!(obj.rand)

        #Step update
        if typeof(obj.u) <: Array
            r = 1:obj.p[3][1]
            Random.randn!(@views(obj.rand[r]))
            obj.u[:,r] .= obj.u[:,r] .+ ( ( obj.du_f1[:,r].+ obj.du_f2[:,r] ) .*dt .+ ( obj.du_g1[:,r] .+ obj.du_g2[:,r] ) .* obj.rand[:,r] .* sqrt(dt) ) ./ 2
        else
            Random.randn!(obj.rand)
            obj.u .= obj.u .+ obj.du_f1 .*dt .+ obj.du_g1 .* obj.rand .* sqrt(dt)
        end

        obj.t += dt

        return

    end


    ################################################################
    # Init
    ################################################################

    function DifferentialEquations.init(problem::DifferentialEquations.SciMLBase.AbstractDEProblem,alg::CustomIntegrator;kwargs...)

        if typeof(alg) <: Euler

            return Euler(problem,kwargs)

        elseif typeof(alg) <: Heun

            return Heun(problem,kwargs)

        elseif typeof(alg) <: RungeKutta4

            return RungeKutta4(problem,kwargs)

        elseif typeof(alg) <: EM

            return EM(problem,kwargs)

        elseif typeof(alg) <: EulerHeun

            return EulerHeun(problem,kwargs)

        else

            error("No custom algorithm implemented with this name.")

        end

    end

end