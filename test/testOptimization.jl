@testset "community" begin

    abm = @agent(1,
        a::Global,
        UpdateVariable = begin
            d(x) = -a*x*dt
        end
    
    )
    model = compile(abm)

    loosf(comt) = sum((comt[1].x[1] .*exp.(-3*comt.t) .- comt.x[:,1]).^2) 

    com = Community(model,N=1)
    com.a = 2
    com.x .= 10

    evolveParams = Dict([
        :dt => .01,
        :tMax => 10
    ])
    # #Grid search
    # explore = Dict([
    #     :a => [1,2,2.9,3,3.1,4,5]
    # ])
    # @test begin
    #     m = AgentBasedModels.Optimization.gridSearch(com,model,loosf,explore,evolveParams)
    #     m["a"] ≈ 3
    # end

    # #Stochastic descent
    # explore = [:a]
    # @test begin
    #     m = AgentBasedModels.Optimization.stochasticDescent(com,model,loosf,explore,evolveParams,jumpVarianceStart=.5)
    #     abs(m["a"] - 3 ) < .1
    # end

    #Genetic algorithm
    explore = Dict([
        :a => (.1,10)
    ])
    @test begin
        m = AgentBasedModels.Optimization.geneticAlgorithm(com,model,loosf,explore,evolveParams,population=100,mutationRate=0.8,returnAll=false)
        abs(m["a"] - 3 ) < .5
    end
end