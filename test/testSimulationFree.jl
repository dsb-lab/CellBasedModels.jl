@testset "free simulation" begin

    @test hasmethod(AgentBasedModels.arguments_!,(Agent,SimulationFree,AgentBasedModels.Program_,String))
    @test hasmethod(AgentBasedModels.loop_,(Agent,SimulationFree,Expr,String))

    @test AgentBasedModels.arguments_!(@agent(cell),SimulationFree(),AgentBasedModels.Program_(),"gpu") == Nothing
    
    @test begin     
        code = :(global g += v[nnic2_])
        loop = AgentBasedModels.loop_(@agent(cell),SimulationFree(),code,"cpu")
        eval(
            quote
                i2_ = 0
                N = 40
                v = ones(Int,N)
                g = 0
                $loop
            end
            )
        g == 40*40
    end
end