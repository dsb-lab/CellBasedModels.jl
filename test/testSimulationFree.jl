@testset "free simulation" begin

    @test hasmethod(AgentBasedModels.arguments_!,(SimulationFree,Agent,AgentBasedModels.Program_,String))
    @test hasmethod(AgentBasedModels.loop_,(SimulationFree,Agent,Expr,String))

    @test AgentBasedModels.arguments_!(SimulationFree(),@createAgent(cell),AgentBasedModels.Program_(),"gpu") == Nothing
    
    @test begin     
        code = :(global g += v[nnic2_])
        loop = AgentBasedModels.loop_(SimulationFree(),@createAgent(cell),code,"cpu")
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