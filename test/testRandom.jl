@testset "random" begin

    abm = @agent(0);

    @test begin
        m = AgentBasedModels.Program_(abm)
        r = :(Normal(2,3) += Gamma(3,4))
        r = AgentBasedModels.randomAdapt_(m, r, "cpu")

        r == :(AgentBasedModels.rand(AgentBasedModels.Normal(2,3)) += AgentBasedModels.rand(AgentBasedModels.Gamma(3,4)))
    end

    @test begin
        m = AgentBasedModels.Program_(abm)
        r = :(Normal(2,3) += Uniform(3,4))
        r = AgentBasedModels.randomAdapt_(m, r, "gpu")

        r == :(AgentBasedModels.NormalCUDA(AgentBasedModels.rand(),2,3) += AgentBasedModels.UniformCUDA(AgentBasedModels.rand(),3,4))
    end

    @test begin
        m = AgentBasedModels.Program_(abm)
        r = :(Exponential(3))
        r = AgentBasedModels.randomAdapt_(m, r, "gpu")

        r == :(AgentBasedModels.ExponentialCUDA(AgentBasedModels.rand(),3))
    end

    @test_throws ErrorException begin
        m = AgentBasedModels.Program_(abm)
        r = :(Normal(2,3) += Gamma(3,4))
        r = AgentBasedModels.randomAdapt_(m, r, "gpu")

        r == :(AgentBasedModels.rand(AgentBasedModels.Normal(2,3)) += AgentBasedModels.rand(AgentBasedModels.Gamma(3,4)))
    end

    #Test distributions
    for platform in testplatforms
        m = @agent(0,UpdateLocal = begin Uniform(0,1) end)
        m = compile(m); com = Community(m); @test_nowarn m.evolve(com,dt=0.1,tMax=10);

        m = @agent(0,UpdateLocal = begin Normal(0,1) end)
        m = compile(m); com = Community(m); @test_nowarn m.evolve(com,dt=0.1,tMax=10);

        m = @agent(0,UpdateLocal = begin Exponential(1) end)
        m = compile(m); com = Community(m); @test_nowarn m.evolve(com,dt=0.1,tMax=10);
    end
end