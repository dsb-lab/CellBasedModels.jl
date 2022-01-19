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

end