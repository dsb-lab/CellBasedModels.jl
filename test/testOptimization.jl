@testset "optimization" begin

    abm = @agent(1,
        a::Global,
        UpdateVariable = begin
            d(x) = -a*x*dt
        end
    
    )
    model = compile(abm)

    loosf(comt) = sum((comt[1].x[1] .*exp.(-3*comt.t) .- comt.x[:,1]).^2) 
    function simulation(dataframe,dt=0.01) 

        com = Community(model,N=1)
        com.a = dataframe.a
        com.x .= 10

        comt = model.evolve(com,dt=dt,tMax=10)

        return loosf(comt)
    end

    #Grid search
    explore = Dict([
        :a => [1,2,2.9,3,3.1,4,5]
    ])
    @test begin
        m = AgentBasedModels.Optimization.gridSearch(simulation,explore)
        m["a"] ≈ 3
    end

    #Optimization algorithms

    explore = Dict([
        :a => (.1,10)
    ])

    #Stochastic descent
    @test begin
        m = AgentBasedModels.Optimization.stochasticDescentAlgorithm(simulation,explore,jumpVarianceStart=.5)
        abs(m["a"] - 3 ) < .1
    end
    @test begin
        m = AgentBasedModels.Optimization.stochasticDescentAlgorithm(simulation,explore,jumpVarianceStart=.5,
                                                                    initialisation=DataFrame(:a=>[5]),args=[0.01])
        abs(m["a"] - 3 ) < .1
    end

    #Genetic algorithm
    @test begin
        m = AgentBasedModels.Optimization.geneticAlgorithm(simulation,explore,population=100,mutationRate=0.8,returnAll=false)
        abs(m["a"] - 3 ) < .5
    end
    @test begin
        m = AgentBasedModels.Optimization.geneticAlgorithm(simulation,explore,population=100,mutationRate=0.8,
                                                            initialisation=DataFrame(:a=>rand(100)),returnAll=false,args=[0.01])
        abs(m["a"] - 3 ) < .5
    end

    #Swarm algorithm
    @test begin
        m = AgentBasedModels.Optimization.swarmAlgorithm(simulation,explore,population=10,stopMaxGenerations=100,returnAll=false)
        abs(m["a"] - 3 ) < .1
    end
    @test begin
        m = AgentBasedModels.Optimization.swarmAlgorithm(simulation,explore,population=10,stopMaxGenerations=100,
                                                            initialisation=DataFrame(:a=>rand(10).*10),returnAll=false)
        abs(m["a"] - 3 ) < .1
    end
    
    #Bee Colony algorithm
    @test begin
        m = AgentBasedModels.Optimization.beeColonyAlgorithm(simulation,explore,population=10,stopMaxGenerations=100,returnAll=false)
        abs(m["a"] - 3 ) < .1
    end
    @test begin
        m = AgentBasedModels.Optimization.beeColonyAlgorithm(simulation,explore,population=10,stopMaxGenerations=100,
                                                            initialisation=DataFrame(:a=>rand(10).*10),returnAll=false,args=[0.01])
        abs(m["a"] - 3 ) < .1
    end

end