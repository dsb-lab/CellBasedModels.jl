import MacroTools: @capture, prettify, postwalk, unblock

# Function to solve tridiagonal system explicitly with minimized allocations
macro createOperator!(dim)

    #Structure of the function
    baseFunction = quote
        function operator!(mainDiag, off_diag, xOld, x_new, difussion)
            (dummy,nx,) = size(xOld)
            for i in 2:nx-1
                for l in difussion
                    x_new[l, i] = XX
                end
            end
        end
    end

    m = copy(baseFunction)

    #Change name
    s = Symbol("operator$(dim)D!")
    m = postwalk(x -> @capture(x, a_) && a == :operator! ? s : x, m)
    
    #Change acording to dimensions the input
    if dim > 1
        m = postwalk(x -> @capture(x, for i = 2:nx-1; a_; end) ? :(for i = 2:nx-1; for j = 2:ny-1; $a; end; end) : x, m)
        m = postwalk(x -> @capture(x, (dummy,nx,)) ? :((dummy,nx,ny)) : x, m)
        m = postwalk(x -> @capture(x, a_[l,b_]) ? :($a[l,$b,j]) : x, m)
    end
    m = prettify(m)
    if dim > 2
        m = postwalk(x -> @capture(x, for j = 2:ny-1; a_; end) ? :(for j = 2:ny-1; for k = 2:nz-1; $a; end; end) : x, m)
        m = postwalk(x -> @capture(x, (dummy,nx,ny)) ? :((dummy,nx,ny,nz)) : x, m)
        m = postwalk(x -> @capture(x, a_[l,b_,c_]) ? :($a[l,$b,$c,k]) : x, m)
    end
    if dim == 1
        m = postwalk(x -> @capture(x, XX) ? :(main_diag * xOld[l,i] + off_diag[0]*x_old[l,i-1] + off_diag[1]*x_old[l,i+1]) : x, m)
    elseif dim == 2
        m = postwalk(x -> @capture(x, XX) ? :(mainDiag * xOld[i] 
                                                + off_diag[l,0]*xOld[l,i-1,j] + off_diag[1]*xOld[l,i+1,j] 
                                                + off_diag[l,3]*xOld[l,i,j-1] + off_diag[4]*xOld[l,i,j+1]) : x, m)
    elseif dim == 3
        m = postwalk(x -> @capture(x, XX) ? :(mainDiag * xOld[i] 
                                                + off_diag[0]*xOld[l,i-1,j,k] + off_diag[1]*xOld[l,i+1,j,k] 
                                                + off_diag[3]*xOld[l,i,j-1,k] + off_diag[4]*xOld[l,i,j+1,k]
                                                + off_diag[5]*xOld[l,i,j,k-1] + off_diag[6]*xOld[l,i,j,k+1]) : x, m)
    end
    m = prettify(m)
end

@createOperator! 1
@createOperator! 2
@createOperator! 3

# macro createTridiagonalSolver!(dim, x)

#     baseFunction = quote
#         function operator!(sub_diag, main_diag, super_diag, x_old, x_new, c_star, d_star, difussion)
#             (dummy,nx,) = size(x_old)
            
#             code
            
#             return
#         end
#     end  
    
#     code = quote
#         for l in difussion
#             # Forward sweep
#             c_star[l,2] = super_diag / main_diag
#             d_star[l,2] = (x_old[l,2] - sub_diag * x_old[l,1]) / main_diag
#             for i in 3:1:nx-2
#                 m = 1.0 / (main_diag - sub_diag * c_star[l,i-1])
#                 c_star[l,i] = super_diag * m
#                 d_star[l,i] = (x_old[l,i] - sub_diag * d_star[l,i-1]) * m
#             end
#             m = 1.0 / (main_diag - sub_diag * c_star[l,nx-2])
#             d_star[l,nx-1] = (x_old[l,nx-1] - super_diag * x_old[l,nx] - sub_diag * d_star[l,nx-2]) * m #Newman
            
#             # Back substitution
#             x_new[l,nx-1] = d_star[l,nx-1]
#             for i in nx-2:-1:2
#                 x_new[l,i] = d_star[l,i] - c_star[l,i] * x_new[l,i+1]
#             end
#         end
#     end

#     s = Symbol("tridiagonal$(dim)D$(x)!")
#     m = copy(baseFunction)
#     m = postwalk(x -> @capture(x, a_) && a == :operator! ? s : x, m)
#     if dim == 1
#         m = postwalk(x -> @capture(x, code) ? code : x, m)
#     elseif dim == 2
#         m = postwalk(x -> @capture(x, (dummy,nx,)) ? :((dummy,nx,ny)) : x, m)
#         if x == :x
#             m = postwalk(x -> @capture(x, code) ? quote @inbounds Threads.@threads for j = 2:ny-1; $code; end end : x, m)
#             m = postwalk(x -> @capture(x, a_[l,b_]) ? :($a[l,$b,j]) : x, m)
#         elseif x == :y
#             code = postwalk(x -> @capture(x, i) ? :j : x, code)
#             code = postwalk(x -> @capture(x, nx) ? :ny : x, code)
#             m = postwalk(x -> @capture(x, code) ? quote @inbounds Threads.@threads for i = 2:nx-1; $code; end end : x, m)
#             m = postwalk(x -> @capture(x, a_[l,b_]) ? :($a[l,i,$b]) : x, m)
#         end
#     elseif dim == 3
#         m = postwalk(x -> @capture(x, (dummy,nx,)) ? :((dummy,nx,ny,nz)) : x, m)
#         if x == :x
#             m = postwalk(x -> @capture(x, code) ? quote @inbounds Threads.@threads for j = 2:ny-1; @inbounds Threads.@threads for k = 2:nz-1; $code; end end end : x, m)
#             m = postwalk(x -> @capture(x, a_[l,b_]) ? :($a[l,$b,j,k]) : x, m)
#         elseif x == :y
#             code = postwalk(x -> @capture(x, i) ? :j : x, code)
#             code = postwalk(x -> @capture(x, nx) ? :ny : x, code)
#             m = postwalk(x -> @capture(x, code) ? quote @inbounds Threads.@threads for i = 2:nx-1; @inbounds Threads.@threads for k = 2:nz-1; $code; end end end : x, m)
#             m = postwalk(x -> @capture(x, a_[l,b_]) ? :($a[l,i,$b,k]) : x, m)
#         elseif x == :z
#             code = postwalk(x -> @capture(x, i) ? :k : x, code)
#             code = postwalk(x -> @capture(x, nx) ? :nz : x, code)
#             m = postwalk(x -> @capture(x, code) ? quote @inbounds Threads.@threads for i = 2:nx-1; @inbounds Threads.@threads for j = 2:ny-1; $code; end end end : x, m)
#             m = postwalk(x -> @capture(x, a_[l,b_]) ? :($a[l,i,j,$b]) : x, m)
#         end
#     end
#     # m = prettify(m)
#     m = unblock(m)
#     println(prettify(m))
#     m
# end

# @createTridiagonalSolver! 1 x
# @createTridiagonalSolver! 2 x
# @createTridiagonalSolver! 2 y
# @createTridiagonalSolver! 3 x
# @createTridiagonalSolver! 3 y
# @createTridiagonalSolver! 3 z

function tridiagonal1Dx!(sub_diag, main_diag, super_diag, x_old, x_new, c_star, d_star, difussion)
    (dummy, nx) = size(x_old)
    for l = difussion
        c_star[l, 2] = super_diag / main_diag
        d_star[l, 2] = (x_old[l, 2] - sub_diag * x_old[l, 1]) / main_diag
        for i = 3:1:nx - 2
            m = 1.0 / (main_diag - sub_diag * c_star[l, i - 1])
            c_star[l, i] = super_diag * m
            d_star[l, i] = (x_old[l, i] - sub_diag * d_star[l, i - 1]) * m
        end
        m = 1.0 / (main_diag - sub_diag * c_star[l, nx - 2])
        d_star[l, nx - 1] = ((x_old[l, nx - 1] - super_diag * x_old[l, nx]) - sub_diag * d_star[l, nx - 2]) * m
        x_new[l, nx - 1] = d_star[l, nx - 1]
        for i = nx - 2:-1:2
            x_new[l, i] = d_star[l, i] - c_star[l, i] * x_new[l, i + 1]
        end
    end
    return
end
function tridiagonal2Dx!(sub_diag, main_diag, super_diag, x_old, x_new, c_star, d_star, difussion)
    (dummy, nx, ny) = size(x_old)
    @inbounds Threads.@threads for j = 2:ny - 1
                for l = difussion
                    c_star[l, 2, j] = super_diag / main_diag
                    d_star[l, 2, j] = (x_old[l, 2, j] - sub_diag * x_old[l, 1, j]) / main_diag
                    for i = 3:1:nx - 2
                        m = 1.0 / (main_diag - sub_diag * c_star[l, i - 1, j])
                        c_star[l, i, j] = super_diag * m
                        d_star[l, i, j] = (x_old[l, i, j] - sub_diag * d_star[l, i - 1, j]) * m
                    end
                    m = 1.0 / (main_diag - sub_diag * c_star[l, nx - 2, j])
                    d_star[l, nx - 1, j] = ((x_old[l, nx - 1, j] - super_diag * x_old[l, nx, j]) - sub_diag * d_star[l, nx - 2, j]) * m
                    x_new[l, nx - 1, j] = d_star[l, nx - 1, j]
                    for i = nx - 2:-1:2
                        x_new[l, i, j] = d_star[l, i, j] - c_star[l, i, j] * x_new[l, i + 1, j]
                    end
                end
            end
    return
end
function tridiagonal2Dy!(sub_diag, main_diag, super_diag, x_old, x_new, c_star, d_star, difussion)
    (dummy, nx, ny) = size(x_old)
    @inbounds Threads.@threads for i = 2:nx - 1
                for l = difussion
                    c_star[l, i, 2] = super_diag / main_diag
                    d_star[l, i, 2] = (x_old[l, i, 2] - sub_diag * x_old[l, i, 1]) / main_diag
                    for j = 3:1:ny - 2
                        m = 1.0 / (main_diag - sub_diag * c_star[l, i, j - 1])
                        c_star[l, i, j] = super_diag * m
                        d_star[l, i, j] = (x_old[l, i, j] - sub_diag * d_star[l, i, j - 1]) * m
                    end
                    m = 1.0 / (main_diag - sub_diag * c_star[l, i, ny - 2])
                    d_star[l, i, ny - 1] = ((x_old[l, i, ny - 1] - super_diag * x_old[l, i, ny]) - sub_diag * d_star[l, i, ny - 2]) * m
                    x_new[l, i, ny - 1] = d_star[l, i, ny - 1]
                    for j = ny - 2:-1:2
                        x_new[l, i, j] = d_star[l, i, j] - c_star[l, i, j] * x_new[l, i, j + 1]
                    end
                end
            end
    return
end
function tridiagonal3Dx!(sub_diag, main_diag, super_diag, x_old, x_new, c_star, d_star, difussion)
    (dummy, nx, ny, nz) = size(x_old)
    @inbounds Threads.@threads for j = 2:ny - 1
                @inbounds Threads.@threads for k = 2:nz - 1
                            for l = difussion
                                c_star[l, 2, j, k] = super_diag / main_diag
                                d_star[l, 2, j, k] = (x_old[l, 2, j, k] - sub_diag * x_old[l, 1, j, k]) / main_diag
                                for i = 3:1:nx - 2
                                    m = 1.0 / (main_diag - sub_diag * c_star[l, i - 1, j, k])
                                    c_star[l, i, j, k] = super_diag * m
                                    d_star[l, i, j, k] = (x_old[l, i, j, k] - sub_diag * d_star[l, i - 1, j, k]) * m
                                end
                                m = 1.0 / (main_diag - sub_diag * c_star[l, nx - 2, j, k])
                                d_star[l, nx - 1, j, k] = ((x_old[l, nx - 1, j, k] - super_diag * x_old[l, nx, j, k]) - sub_diag * d_star[l, nx - 2, j, k]) * m
                                x_new[l, nx - 1, j, k] = d_star[l, nx - 1, j, k]
                                for i = nx - 2:-1:2
                                    x_new[l, i, j, k] = d_star[l, i, j, k] - c_star[l, i, j, k] * x_new[l, i + 1, j, k]
                                end
                            end
                        end
            end
    return
end
function tridiagonal3Dy!(sub_diag, main_diag, super_diag, x_old, x_new, c_star, d_star, difussion)
    (dummy, nx, ny, nz) = size(x_old)
    @inbounds Threads.@threads for i = 2:nx - 1
                @inbounds Threads.@threads for k = 2:nz - 1
                            for l = difussion
                                c_star[l, i, 2, k] = super_diag / main_diag
                                d_star[l, i, 2, k] = (x_old[l, i, 2, k] - sub_diag * x_old[l, i, 1, k]) / main_diag
                                for j = 3:1:ny - 2
                                    m = 1.0 / (main_diag - sub_diag * c_star[l, i, j - 1, k])
                                    c_star[l, i, j, k] = super_diag * m
                                    d_star[l, i, j, k] = (x_old[l, i, j, k] - sub_diag * d_star[l, i, j - 1, k]) * m
                                end
                                m = 1.0 / (main_diag - sub_diag * c_star[l, i, ny - 2, k])
                                d_star[l, i, ny - 1, k] = ((x_old[l, i, ny - 1, k] - super_diag * x_old[l, i, ny, k]) - sub_diag * d_star[l, i, ny - 2, k]) * m
                                x_new[l, i, ny - 1, k] = d_star[l, i, ny - 1, k]
                                for j = ny - 2:-1:2
                                    x_new[l, i, j, k] = d_star[l, i, j, k] - c_star[l, i, j, k] * x_new[l, i, j + 1, k]
                                end
                            end
                        end 
            end 
    return
end
function tridiagonal3Dz!(sub_diag, main_diag, super_diag, x_old, x_new, c_star, d_star, difussion)
    (dummy, nx, ny, nz) = size(x_old)
    @inbounds Threads.@threads for i = 2:nx - 1
                @inbounds Threads.@threads for j = 2:ny - 1
                            for l = difussion
                                c_star[l, i, j, 2] = super_diag / main_diag
                                d_star[l, i, j, 2] = (x_old[l, i, j, 2] - sub_diag * x_old[l, i, j, 1]) / main_diag
                                for k = 3:1:nz - 2
                                    m = 1.0 / (main_diag - sub_diag * c_star[l, i, j, k - 1])
                                    c_star[l, i, j, k] = super_diag * m
                                    d_star[l, i, j, k] = (x_old[l, i, j, k] - sub_diag * d_star[l, i, j, k - 1]) * m
                                end
                                m = 1.0 / (main_diag - sub_diag * c_star[l, i, j, nz - 2])
                                d_star[l, i, j, nz - 1] = ((x_old[l, i, j, nz - 1] - super_diag * x_old[l, i, j, nz]) - sub_diag * d_star[l, i, j, nz - 2]) * m
                                x_new[l, i, j, nz - 1] = d_star[l, i, j, nz - 1]
                                for k = nz - 2:-1:2
                                    x_new[l, i, j, k] = d_star[l, i, j, k] - c_star[l, i, j, k] * x_new[l, i, j, k + 1]
                                end
                            end
                        end 
            end 
    return
end

module CBMIntegrators

    export CustomIntegrator, CustomMediumIntegrator, CustomAgentIntegrator

    using CellBasedModels
    using DifferentialEquations
    using Random

    abstract type CustomIntegrator end
    abstract type CustomMediumIntegrator <: CustomIntegrator end
    abstract type CustomAgentIntegrator <: CustomIntegrator end

    function cleanArray(du,p)
        #Clean array
        if typeof(du) <: Array
            r = 1:1:p[3][1]
            du[:,r] .= 0
        else
            du .= 0
        end
    end

    ################################################################
    # ODE
    ################################################################

    ##########################################
    # Euler
    ##########################################

"""
    mutable struct Euler <: CustomAgentIntegrator

Euler integrator for ODE problems.
"""
    mutable struct Euler <: CustomAgentIntegrator

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

        cleanArray(obj.du,obj.p)

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
    mutable struct Heun <: CustomAgentIntegrator

Heun integrator for ODE problems.
"""
    mutable struct Heun <: CustomAgentIntegrator

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

        cleanArray(obj.du,obj.p)

        #First step
        obj.f(obj.du,obj.u,obj.p,obj.t)

        #Save step in h1
        if typeof(obj.du) <: Array
            r = 1:obj.p[3][1]
            obj.h1[:,r] .= obj.u[:,r] .+ obj.du[:,r].*dt
        else
        obj.h1 .= obj.u .+ obj.du.*dt
        end

        cleanArray(obj.du,obj.p)

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
    mutable struct RungeKutta4 <: CustomAgentIntegrator

RungeKutta4 for ODE integrators
"""
    mutable struct RungeKutta4 <: CustomAgentIntegrator

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

        cleanArray(obj.k1,obj.p)

        #First step
        obj.f(obj.k1,obj.u,obj.p,obj.t)

        #Save step in h1
        if typeof(obj.u) <: Array
            r = 1:obj.p[3][1]
            obj.h1[:,r] .= obj.u[:,r] .+ obj.k1[:,r].*dt ./2
        else
        obj.h1 .= obj.u .+ obj.k1.*dt./2
        end

        cleanArray(obj.k2,obj.p)

        #Second step
        obj.f(obj.k2,obj.h1,obj.p,obj.t+dt/2)

        #Save step in h1
        if typeof(obj.u) <: Array
            r = 1:obj.p[3][1]
            obj.h1[:,r] .= obj.u[:,r] .+ obj.k2[:,r].*dt ./2
        else
            obj.h1 .= obj.u .+ obj.k2.*dt./2
        end

        cleanArray(obj.k3,obj.p)

        #Third step
        obj.f(obj.k3,obj.h1,obj.p,obj.t+dt/2)

        #Save step in h1
        if typeof(obj.u) <: Array
            r = 1:obj.p[3][1]
            obj.h1[:,r] .= obj.u[:,r] .+ obj.k3[:,r].*dt
        else
            obj.h1 .= obj.u .+ obj.k3.*dt
        end

        cleanArray(obj.k4,obj.p)

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
    mutable struct EM <: CustomAgentIntegrator

Euler-Majurana integrator for SDE poblems.
"""
    mutable struct EM <: CustomAgentIntegrator

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

        cleanArray(obj.du_f,obj.p)
        cleanArray(obj.du_g,obj.p)

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
    mutable struct EulerHeun <: CustomAgentIntegrator

Euler-Heun method for SDE integration.
"""
    mutable struct EulerHeun <: CustomAgentIntegrator

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
        cleanArray(obj.du_f1,obj.p)
        cleanArray(obj.du_g1,obj.p)

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

        cleanArray(obj.du_f2,obj.p)
        cleanArray(obj.du_g2,obj.p)

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

    ##########################################
    # DGADI
    ##########################################

    """
    mutable struct DGADI <: CustomIntegrator

Douglas-Gunn integrator for PDE difussion problems.
"""
    mutable struct DGADI <: CustomMediumIntegrator

        f
        p
        u
        t
        u_new
        du
        dt
        r
        c_star
        d_star
        dims
        difussion
        difussionCoefs

        function DGADI(problem,kwargs; difussionCoefs=nothing)

            # Coefficients for the tridiagonal matrix
            nDims = length(problem.p.NMedium)
            r = problem.p.dt ./ (nDims .*((problem.p.simBox[:,2].-problem.p.simBox[:,1])./problem.p.NMedium).^2)
            
            return new(problem.f,problem.p,problem.u0,problem.tspan[1],copy(problem.u0),copy(problem.u0),kwargs[:dt],r,copy(problem.u0),copy(problem.u0),nDims,problem.p.difussionVariables_, difussionCoefs)

        end

        function DGADI(;difussionCoefs=nothing)

            return new(nothing,nothing,nothing,nothing,nothing,nothing,nothing,nothing,nothing,nothing,nothing,nothing,difussionCoefs)

        end

    end

    function specialIntegratorArguments(model::DGADI,abm)

        l = [j for (i,(j,k)) in enumerate(abm.parameters) if k.scope == :medium && k.update]
        e = [i for (i,j) in enumerate(l)]

        return [:difussionVariables_], [NamedTuple{Tuple(l)}(e)]

    end

    function DifferentialEquations.step!(obj::DGADI,dt=obj.dt,_=nothing)

        obj.du .= 0

        obj.f(obj.du,obj.u,obj.p,obj.t)

        r = obj.r .* obj.p[obj.difussionCoefs]

        if obj.dims == 1
            obj.u .+= obj.du
            CellBasedModels.tridiagonal1Dx!(-r[1], 1+2*r[1], -r[1], obj.u, obj.u_new, obj.c_star, obj.d_star, obj.difussion)
            obj.u .= obj.u_new
        elseif obj.dims == 2
            obj.u .+= obj.du
            CellBasedModels.tridiagonal2Dx!(-r[1], 1+2*r[1], -r[1], obj.u, obj.u_new, obj.c_star, obj.d_star, obj.difussion)
            obj.u .= obj.u_new
            CellBasedModels.tridiagonal2Dy!(-r[2], 1+2*r[2], -r[2], obj.u, obj.u_new, obj.c_star, obj.d_star, obj.difussion)
            obj.u .= obj.u_new
        elseif obj.dims == 3
            obj.u .+= obj.du
            CellBasedModels.tridiagonal3Dx!(-r[1], 1+2*r[1], -r[1], obj.u, obj.u_new, obj.c_star, obj.d_star, obj.difussion)
            obj.u .= obj.u_new
            CellBasedModels.tridiagonal3Dy!(-r[2], 1+2*r[2], -r[2], obj.u, obj.u_new, obj.c_star, obj.d_star, obj.difussion)
            obj.u .= obj.u_new
            CellBasedModels.tridiagonal3Dz!(-r[3], 1+2*r[3], -r[3], obj.u, obj.u_new, obj.c_star, obj.d_star, obj.difussion)
            obj.u .= obj.u_new
        end
        
        obj.t += dt

        return

    end

    ################################################################
    # Init
    ################################################################

    function DifferentialEquations.init(problem::DifferentialEquations.SciMLBase.AbstractDEProblem,alg::CustomIntegrator;kwargs...)

        if typeof(alg) <: Euler

            if typeof(problem) <: ODEProblem
                return Euler(problem,kwargs)
            else
                error("Euler algorithm is for ODE problems only, a SDE problem has been detected. Choose an appropiate integrator from CBMIntegrators or DifferentialEquations.")
            end


        elseif typeof(alg) <: Heun

            if typeof(problem) <: ODEProblem
                return Heun(problem,kwargs)
            else
                error("Heun algorithm is for ODE problems only, a SDE problem has been detected. Choose an appropiate integrator from CBMIntegrators or DifferentialEquations.")
            end

        elseif typeof(alg) <: RungeKutta4

            if typeof(problem) <: ODEProblem
                return RungeKutta4(problem,kwargs)
            else
                error("RungeKutta4 algorithm is for ODE problems only, a SDE problem has been detected. Choose an appropiate integrator from CBMIntegrators or DifferentialEquations.")
            end

        elseif typeof(alg) <: EM

            if typeof(problem) <: SDEProblem
                return EM(problem,kwargs)
            else
                error("EM algorithm is for ODE problems only, a SDE problem has been detected. Choose an appropiate integrator from CBMIntegrators or DifferentialEquations.")
            end

        elseif typeof(alg) <: EulerHeun

            if typeof(problem) <: SDEProblem
                return EulerHeun(problem,kwargs)
            else
                error("EulerHeun algorithm is for ODE problems only, a SDE problem has been detected. Choose an appropiate integrator from CBMIntegrators or DifferentialEquations.")
            end

        elseif typeof(alg) <: DGADI

            if typeof(problem) <: ODEProblem
                return DGADI(problem,kwargs; difussionCoefs=alg.difussionCoefs)
            else
                error("DGADI algorithm is for PDE problems only, a SDE problem has been detected. Choose an appropiate integrator from CBMIntegrators or DifferentialEquations.")
            end

        else

            error("No custom algorithm implemented with this name.")

        end

    end

end