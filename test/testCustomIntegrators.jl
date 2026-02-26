using KernelAbstractions
using Atomix 
using DifferentialEquations
using CellBasedModels.IntegrationAlgs

@testset verbose=verbose "Custom Integration Algorithms" begin

    ############################################################################
    # ODE Tests - Exponential Decay: dx/dt = -λx, analytical solution: x(t) = x₀*exp(-λt)
    ############################################################################
    
    @testset "ODE Integrators" begin
        
        # Define a model for ODE testing
        model_ode = AgentPoint(
            2,
            (
                state = AbstractFloat,  # State variable (not x since x is reserved for position)
            ),
        )

        @addODE model=model_ode function odeEvolution(du, u, p, t)
            λ = 0.1  # Decay rate
            @kernel_launch ndrange=length(du.n.state) function ode_step(du, u, p, t)
                i = @index(Global)
                du.n.state[i] = -λ * u.n.state[i]
            end
        end

        # Test Euler integrator
        @testset "Euler" begin
            obj = createObject(model_ode, n=100)
            obj.n.state .= 1.0

            problem = CBProblem(model_ode, obj)
            integrator = init(problem, dt=0.01, odeEvolution=IntegrationAlgs.Euler())

            for _ in 1:100
                step!(integrator)
            end
            
            t_final = integrator.t
            expected = exp(-0.1 * t_final)
            # Euler has O(h) error, allow larger tolerance
            @test all(isapprox.(integrator.u.n.state, expected; atol=0.05))
        end

        # Test Heun integrator
        @testset "Heun" begin
            obj = createObject(model_ode, n=100)
            obj.n.state .= 1.0

            problem = CBProblem(model_ode, obj)
            integrator = init(problem, dt=0.01, odeEvolution=IntegrationAlgs.Heun())

            for _ in 1:100
                step!(integrator)
            end
            
            t_final = integrator.t
            expected = exp(-0.1 * t_final)
            # Heun has O(h²) error, should be more accurate
            @test all(isapprox.(integrator.u.n.state, expected; atol=0.01))
        end

        # Test RungeKutta4 integrator
        @testset "RungeKutta4" begin
            obj = createObject(model_ode, n=100)
            obj.n.state .= 1.0

            problem = CBProblem(model_ode, obj)
            integrator = init(problem, dt=0.01, odeEvolution=IntegrationAlgs.RungeKutta4())

            for _ in 1:100
                step!(integrator)
            end
            
            t_final = integrator.t
            expected = exp(-0.1 * t_final)
            # RK4 has O(h⁴) error, should be most accurate
            @test all(isapprox.(integrator.u.n.state, expected; atol=1e-4))
        end

        # Compare accuracy: RK4 > Heun > Euler
        @testset "Accuracy Comparison" begin
            dt = 0.1
            nsteps = 10
            
            # Euler
            obj_euler = createObject(model_ode, n=10)
            obj_euler.n.state .= 1.0
            problem_euler = CBProblem(model_ode, obj_euler)
            integrator_euler = init(problem_euler, dt=dt, odeEvolution=IntegrationAlgs.Euler())
            for _ in 1:nsteps
                step!(integrator_euler)
            end
            error_euler = abs(integrator_euler.u.n.state[1] - exp(-0.1 * integrator_euler.t))

            # Heun
            obj_heun = createObject(model_ode, n=10)
            obj_heun.n.state .= 1.0
            problem_heun = CBProblem(model_ode, obj_heun)
            integrator_heun = init(problem_heun, dt=dt, odeEvolution=IntegrationAlgs.Heun())
            for _ in 1:nsteps
                step!(integrator_heun)
            end
            error_heun = abs(integrator_heun.u.n.state[1] - exp(-0.1 * integrator_heun.t))

            # RK4
            obj_rk4 = createObject(model_ode, n=10)
            obj_rk4.n.state .= 1.0
            problem_rk4 = CBProblem(model_ode, obj_rk4)
            integrator_rk4 = init(problem_rk4, dt=dt, odeEvolution=IntegrationAlgs.RungeKutta4())
            for _ in 1:nsteps
                step!(integrator_rk4)
            end
            error_rk4 = abs(integrator_rk4.u.n.state[1] - exp(-0.1 * integrator_rk4.t))

            # RK4 should be more accurate than Heun which should be more accurate than Euler
            @test error_rk4 < error_heun
            @test error_heun < error_euler
        end

    end

    ############################################################################
    # SDE Tests - Testing Euler-Maruyama and EulerHeun integrators
    # For constant drift μ and diffusion σ: dX = μ*dt + σ*dW
    # Expected mean: X₀ + μt, Expected variance: σ²t
    ############################################################################
    
    @testset "SDE Integrators" begin
        
        # Define a model for SDE testing
        model_sde = AgentPoint(
            2,
            (
                state = AbstractFloat,
            ),
        )

        # Constant drift, constant diffusion for easier testing
        μ_const = 1.0  # Drift
        σ_const = 0.1  # Diffusion
        
        @addSDE model=model_sde function sdeEvolution(du, u, p, t)
            μ = 1.0
            @kernel_launch ndrange=length(du.n.state) function sde_f(du, u, p, t)
                i = @index(Global)
                du.n.state[i] = μ
            end
        end function sdeEvolution_g(du, u, p, t)
            σ = 0.1
            @kernel_launch ndrange=length(du.n.state) function sde_g(du, u, p, t)
                i = @index(Global)
                du.n.state[i] = σ
            end
        end

        # Test EM integrator - Euler-Maruyama
        @testset "EM (Euler-Maruyama)" begin
            N = 1000  # Number of particles for statistical testing
            obj = createObject(model_sde, n=N)
            obj.n.state .= 0.0

            problem = CBProblem(model_sde, obj)
            integrator = init(problem, dt=0.01, sdeEvolution=IntegrationAlgs.EM())

            for _ in 1:100
                step!(integrator)
            end
            
            t_final = integrator.t
            
            # Expected mean: state₀ + μt = μt (since state₀=0)
            expected_mean = μ_const * t_final
            # Expected variance: σ²t
            expected_var = σ_const^2 * t_final
            
            sample_mean = mean(integrator.u.n.state)
            sample_var = var(integrator.u.n.state)
            
            # Statistical tests with some tolerance (central limit theorem)
            @test isapprox(sample_mean, expected_mean; atol=0.1)
            @test isapprox(sample_var, expected_var; rtol=0.5)
        end

        # Test EulerHeun integrator
        @testset "EulerHeun" begin
            N = 1000
            obj = createObject(model_sde, n=N)
            obj.n.state .= 0.0

            problem = CBProblem(model_sde, obj)
            integrator = init(problem, dt=0.01, sdeEvolution=IntegrationAlgs.EulerHeun())

            for _ in 1:100
                step!(integrator)
            end
            
            t_final = integrator.t
            
            expected_mean = μ_const * t_final
            expected_var = σ_const^2 * t_final
            
            sample_mean = mean(integrator.u.n.state)
            sample_var = var(integrator.u.n.state)
            
            @test isapprox(sample_mean, expected_mean; atol=0.1)
            @test isapprox(sample_var, expected_var; rtol=0.5)
        end

        # Test that SDE integrators correctly handle stochastic noise
        @testset "Stochastic Independence" begin
            obj = createObject(model_sde, n=100)
            obj.n.state .= 0.0

            problem = CBProblem(model_sde, obj)
            integrator = init(problem, dt=0.1, sdeEvolution=IntegrationAlgs.EM())

            step!(integrator)
            
            # After one step, particles should have different values due to independent Wiener processes
            unique_vals = length(unique(integrator.u.n.state))
            # Most values should be unique (allowing for some floating point coincidences)
            @test unique_vals > 90
        end

    end

    ############################################################################
    # GPU Tests (if available)
    ############################################################################
    
    if CUDA.has_cuda()
        @testset "GPU Support" begin
            
            # ODE on GPU
            @testset "ODE on GPU - Euler" begin
                model_ode = AgentPoint(
                    2,
                    (
                        state = AbstractFloat,
                    ),
                )

                @addODE model=model_ode function odeEvolutionGPU(du, u, p, t)
                    λ = 0.1
                    @kernel_launch ndrange=length(du.n.state) function ode_step(du, u, p, t)
                        i = @index(Global)
                        du.n.state[i] = -λ * u.n.state[i]
                    end
                end

                obj = createObject(model_ode, n=100)
                obj.n.state .= 1.0
                obj_gpu = toBackend(obj, CUDA.CUDABackend())

                problem = CBProblem(model_ode, obj_gpu)
                integrator = init(problem, dt=0.01, odeEvolutionGPU=IntegrationAlgs.Euler())

                for _ in 1:100
                    step!(integrator)
                end
                
                t_final = integrator.t
                expected = exp(-0.1 * t_final)
                @test all(isapprox.(Array(integrator.u.n.state), expected; atol=0.05))
            end

            # SDE on GPU - EM integrator
            @testset "SDE on GPU - EM" begin
                model_sde = AgentPoint(
                    2,
                    (
                        state = AbstractFloat,
                    ),
                )

                μ_gpu = 1.0
                σ_gpu = 0.1
                
                @addSDE model=model_sde function sdeEvolutionGPU(du, u, p, t)
                    μ = 1.0
                    @kernel_launch ndrange=length(du.n.state) function sde_f(du, u, p, t)
                        i = @index(Global)
                        du.n.state[i] = μ
                    end
                end function sdeEvolutionGPU_g(du, u, p, t)
                    σ = 0.1
                    @kernel_launch ndrange=length(du.n.state) function sde_g(du, u, p, t)
                        i = @index(Global)
                        du.n.state[i] = σ
                    end
                end

                N = 1000
                obj = createObject(model_sde, n=N)
                obj.n.state .= 0.0
                obj_gpu = toBackend(obj, CUDA.CUDABackend())

                problem = CBProblem(model_sde, obj_gpu)
                integrator = init(problem, dt=0.01, sdeEvolutionGPU=IntegrationAlgs.EM())

                for _ in 1:100
                    step!(integrator)
                end
                
                t_final = integrator.t
                expected_mean = μ_gpu * t_final
                
                sample_mean = mean(Array(integrator.u.n.state))
                @test isapprox(sample_mean, expected_mean; atol=0.1)
            end

        end
    end

end
