@testset "random" begin

    @test begin
        m = AgentBasedModels.Program_()
        r = :(Normal(2,3) += Gamma(3,4))
        r = AgentBasedModels.randomAdapt_(m, r, "cpu")

        r == :(rand(Normal(2,3)) += rand(Gamma(3,4)))
    end

    @test begin
        m = AgentBasedModels.Program_()
        r = :(Normal(2,3) += Uniform(3,4))
        r = AgentBasedModels.randomAdapt_(m, r, "gpu")

        r == :(AgentBasedModels.NormalCUDA(rand(),2,3) += AgentBasedModels.UniformCUDA(rand(),3,4))
    end

    @test_throws ErrorException begin
        m = AgentBasedModels.Program_()
        r = :(Normal(2,3) += Gamma(3,4))
        r = AgentBasedModels.randomAdapt_(m, r, "gpu")

        r == :(rand(Normal(2,3)) += rand(Gamma(3,4)))
    end

end