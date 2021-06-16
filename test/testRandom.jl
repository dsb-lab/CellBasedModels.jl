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
        r = MacroTools.gensym_ids(r)

        r == :(Normal_(Normal_1[ic1_],2,3) += Uniform_(Uniform_2[ic1_],3,4))
    end

    @test_throws ErrorException begin
        m = AgentBasedModels.Program_()
        r = :(Normal(2,3) += Gamma(3,4))
        r = AgentBasedModels.randomAdapt_(m, r, "gpu")
        r = MacroTools.gensym_ids(r)

        r == :(rand(Normal(2,3)) += rand(Gamma(3,4)))
    end

end