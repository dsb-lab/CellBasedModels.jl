@testset "agent" begin

    @test_nowarn Agent()

    #Check you can declare agent of any size
    @test_nowarn @agent(0)
    @test_nowarn @agent(1)
    @test_nowarn @agent(2)
    @test_nowarn @agent(3)
    @test_throws ErrorException try @eval @agent(4) catch err; throw(err.error) end

    #Check you cannot declare variables from Base
    @test_throws ErrorException try @eval @agent 0 sin::LocalFloat catch err; throw(err.error) end
    #Check you cannot declare variables from Distributions
    @test_throws ErrorException try @eval @agent 0 Normal::LocalInt catch err; throw(err.error) end

    #Check all possible declarations
    @test_nowarn @agent(
        
        0,
        
        v::LocalFloat,
        [l,l2]::LocalFloat,
        li::LocalFloatInteraction,
        [li2,li3]::LocalFloatInteraction,
        id2::LocalInt,
        [id3,id4]::LocalInt,
        ind::LocalIntInteraction,
        [ind2,ind3]::LocalIntInteraction,
        g::GlobalFloat,
        [g2,g3]::GlobalFloat,
        ga::GlobalInt,
        [ga2,ga3]::GlobalInt,
        gi::GlobalFloatInteraction,
        [gi2,gi3]::GlobalFloatInteraction,
        gai::GlobalIntInteraction,
        [gai2,gai3]::GlobalIntInteraction,
        m::Medium,
        [m1,m2]::Medium,

        UpdateVariable = d(v) = 34*dt ,
        UpdateLocal = begin l += 1; v += 1 end,
        UpdateGlobal = g += 1,
        UpdateInteraction = i += 1,
        UpdateGlobalInteraction = gi += 1,
        UpdateMedium = ∂t(x) = x,

        NeighborsFull::NeighborsAlgorithm,
        Euler::IntegrationAlgorithm,
        RAM::SavingPlatform,
        CPU::ComputingPlatform,

    )

    #Neighbors
    @test_nowarn @agent(3, NeighborsFull::NeighborsAlgorithm)
    @test_nowarn @agent(3, NeighborsCell::NeighborsAlgorithm)
    @test_throws ErrorException try @eval @agent(3, Hola::NeighborsAlgorithm) catch err; throw(err.error) end

    #IntegrationAlgorithm
    @test_nowarn @agent(3, Euler::IntegrationAlgorithm)
    @test_throws ErrorException try @eval @agent(3, Hola::IntegrationAlgorithm) catch err; throw(err.error) end

    #ComputingPlatforms
    @test_nowarn @agent(3, CPU::ComputingPlatform)
    @test_nowarn @agent(3, GPU::ComputingPlatform)
    @test_throws ErrorException try @eval @agent(3, Hola::ComputingPlatform) catch err; throw(err.error) end

    #ComputingPlatforms
    @test_nowarn @agent(3, RAM::SavingPlatform)
    @test_nowarn @agent(3, JLD::SavingPlatform)
    @test_throws ErrorException try @eval @agent(3, Hola::SavingPlatform) catch err; throw(err.error) end

    #Check no doble declarations allowed
    @test_throws ErrorException try @eval @agent(0, [l,l]::LocalFloat) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::LocalFloatInteraction) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::LocalInt) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::LocalIntInteraction) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::GlobalFloat) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::GlobalFloatInteraction) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::GlobalInt) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::GlobalIntInteraction) catch err; throw(err.error) end

end