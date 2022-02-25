@testset "optimization" begin

    abm = @agent(1,
        a::Global,
        UpdateVariable = begin
            d(x) = -a*x*dt
        end
    
    )
    model = compile(abm)

    loosf(comt) = sum((comt[1].x[1] .*exp.(-3*comt.t) .- comt.x[:,1]).^2) 
    function initialisationF(com; a = 0) 

        com.a = a

        return nothing
    end
    com = Community(model,N=1)
    com.a = 2
    com.x .= 10

    evolveParams = Dict([
        :dt => .01,
        :tMax => 10
    ])

    #Grid search
    explore = Dict([
        :a => [1,2,2.9,3,3.1,4,5]
    ])
    @test begin
        m = AgentBasedModels.Optimization.gridSearch(com,model,loosf,explore,evolveParams)
        m["a"] ≈ 3
    end


    #Optimization algorithms

    explore = Dict([
        :a => (.1,10)
    ])

    #Stochastic descent
    @test begin
        m = AgentBasedModels.Optimization.stochasticDescentAlgorithm(com,model,loosf,explore,evolveParams,jumpVarianceStart=.5)
        abs(m["a"] - 3 ) < .1
    end
    @test begin
        m = AgentBasedModels.Optimization.stochasticDescentAlgorithm(com,model,loosf,explore,evolveParams,jumpVarianceStart=.5,
                                                                    initialisationF=initialisationF)
        abs(m["a"] - 3 ) < .1
    end
    @test begin
        m = AgentBasedModels.Optimization.stochasticDescentAlgorithm(com,model,loosf,explore,evolveParams,jumpVarianceStart=.5,
                                                                    initialisation=DataFrame(:a=>[5]),
                                                                    initialisationF=initialisationF)
        abs(m["a"] - 3 ) < .1
    end

    #Genetic algorithm
    @test begin
        m = AgentBasedModels.Optimization.geneticAlgorithm(com,model,loosf,explore,evolveParams,population=100,mutationRate=0.8,returnAll=false)
        abs(m["a"] - 3 ) < .5
    end
    @test begin
        m = AgentBasedModels.Optimization.geneticAlgorithm(com,model,loosf,explore,evolveParams,population=100,mutationRate=0.8,
                                                            initialisationF=initialisationF,returnAll=false)
        abs(m["a"] - 3 ) < .5
    end
    @test begin
        m = AgentBasedModels.Optimization.geneticAlgorithm(com,model,loosf,explore,evolveParams,population=100,mutationRate=0.8,
                                                            initialisation=DataFrame(:a=>rand(100)),
                                                            initialisationF=initialisationF,returnAll=false)
        abs(m["a"] - 3 ) < .5
    end

    #Swarm algorithm
    @test begin
        m = AgentBasedModels.Optimization.swarmAlgorithm(com,model,loosf,explore,evolveParams,population=10,stopMaxGenerations=100,returnAll=false)
        abs(m["a"] - 3 ) < .1
    end
    @test begin
        m = AgentBasedModels.Optimization.swarmAlgorithm(com,model,loosf,explore,evolveParams,population=10,stopMaxGenerations=100,initialisationF=initialisationF,returnAll=false)
        abs(m["a"] - 3 ) < .1
    end
    @test begin
        m = AgentBasedModels.Optimization.swarmAlgorithm(com,model,loosf,explore,evolveParams,population=10,stopMaxGenerations=100,
                                                            initialisation=DataFrame(:a=>rand(10).*10),
                                                            initialisationF=initialisationF,returnAll=false)
        abs(m["a"] - 3 ) < .1
    end
    
    #Bee Colony algorithm
    @test begin
        m = AgentBasedModels.Optimization.beeColonyAlgorithm(com,model,loosf,explore,evolveParams,population=10,stopMaxGenerations=100,returnAll=false)
        abs(m["a"] - 3 ) < .1
    end
    @test begin
        m = AgentBasedModels.Optimization.beeColonyAlgorithm(com,model,loosf,explore,evolveParams,population=10,stopMaxGenerations=100,
                                                            initialisationF=initialisationF,returnAll=false)
        abs(m["a"] - 3 ) < .1
    end
    @test begin
        m = AgentBasedModels.Optimization.beeColonyAlgorithm(com,model,loosf,explore,evolveParams,population=10,stopMaxGenerations=100,
                                                            initialisation=DataFrame(:a=>rand(10).*10),
                                                            initialisationF=initialisationF,returnAll=false)
        abs(m["a"] - 3 ) < .1
    end

end