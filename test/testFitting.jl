@testset "Fitting" begin

    loosf(com,x0) = (x0.*exp.(-3 .*com.t) .- com.x).^2
    function simulation(dataframe,dt=0.01) 
    
        model = ABM(1,
            agent = Dict(
                :a => Float64
            ),
            agentODE = quote
                dt( x ) = -a*x
            end
        )

        com = Community(model,N=1,dt=dt)
        com.a = dataframe.a
        com.x .= 10
        loadToPlatform!(com)
    
        l = 0
        for i in 1:1000
            step!(com)
            l += loosf(com,10.)[1]
        end
        bringFromPlatform!(com)
    
        return l
    
    end

    #Grid search
    explore = Dict([
        :a => [1,2,2.9,3,3.1,4,5]
    ])
    @test begin
        m = CBMFitting.gridSearch(simulation,explore)
        m.a ≈ 3
    end

    #Fitting algorithms
    explore = Dict([
        :a => (.1,10)
    ])

    #Stochastic descent
    @test begin
        m = CBMFitting.stochasticDescentAlgorithm(simulation,explore,jumpVarianceStart=.5)
        abs(m.a - 3 ) < .1
    end
    @test begin
        m = CBMFitting.stochasticDescentAlgorithm(simulation,explore,jumpVarianceStart=.5,
                                                                    initialisation=DataFrame(:a=>[5]),args=[0.01])
        abs(m.a - 3 ) < .1
    end

    #Genetic algorithm
    @test begin
        m = CBMFitting.geneticAlgorithm(simulation,explore,population=20,mutationRate=0.8,returnAll=false)
        abs(m.a - 3 ) < .5
    end
    @test begin
        m = CBMFitting.geneticAlgorithm(simulation,explore,population=20,mutationRate=0.8,
                                                            initialisation=DataFrame(:a=>rand(100)),returnAll=false,args=[0.01])
        abs(m.a - 3 ) < .5
    end

    #Swarm algorithm
    @test begin
        m = CBMFitting.swarmAlgorithm(simulation,explore,population=10,stopMaxGenerations=50,returnAll=false)
        abs(m.a - 3 ) < .1
    end
    @test begin
        m = CBMFitting.swarmAlgorithm(simulation,explore,population=10,stopMaxGenerations=50,
                                                            initialisation=DataFrame(:a=>rand(10).*10),returnAll=false)
        abs(m.a - 3 ) < .1
    end
    
    #Bee Colony algorithm
    @test begin
        m = CBMFitting.beeColonyAlgorithm(simulation,explore,population=10,stopMaxGenerations=50,returnAll=false)
        abs(m.a - 3 ) < .1
    end
    @test begin
        m = CBMFitting.beeColonyAlgorithm(simulation,explore,population=10,stopMaxGenerations=50,
                                                            initialisation=DataFrame(:a=>rand(10).*10),returnAll=false,args=[0.01])
        abs(m.a - 3 ) < .1
    end

end