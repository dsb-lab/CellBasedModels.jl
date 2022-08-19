@testset "agent" begin

    @test_nowarn Agent()

    @test_nowarn @agent(0)
    @test_nowarn @agent(1)
    @test_nowarn @agent(2)
    @test_nowarn @agent(3)

    @test_throws ErrorException try @eval @agent 0 sin::Local catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent 0 Normal::Local catch err; throw(err.error) end

    @test_nowarn print(@agent(
        0,
        
        v::LocalFloat,
        l::LocalFloat,
        li::LocalFloatInteraction,
        id2::LocalInt,
        id3::LocalIntInteraction,
        g::GlobalFloat,
        ga::GlobalInt,

        UpdateVariable = d(v) = 34*dt ,
        UpdateLocal = begin l += 1; v += 1 end,
        UpdateGlobal = g += 1,
        UpdateInteraction = i += 1,
        UpdateGlobalInteraction = gi += 1,

        NeighborsFull::NeighborsAlgorithm,
        Euler::IntegrationAlgorithm,
        RAM::SavingPlatform,
        CPU::ComputingPlaform,
    ))
    
    @test_nowarn @agent(
        0,

        [id2]::LocalInt,
        [li,li2]::LocalFloatInteraction,
        [idi,idi2]::LocalIntInteraction,
        [l,l2]::LocalFloat,
        [g,g2]::GlobalFloat,
        [gi,gi2]::GlobalFloatInteraction,
        [ga,ga2]::GlobalInt,
        [m1,m2]::Medium,

        UpdateVariable = d(v) = 34*dt ,
        UpdateLocal = l += 1,
        UpdateGlobal = g += 1,
        UpdateInteraction = i += 1,
        UpdateGlobalInteraction = gi += 1,
        UpdateMedium = ∂t(x) = x
    )

    @test_throws ErrorException try @eval @agent(0, [l,l]::LocalFloat) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::LocalFloatInteraction) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::LocalInt) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::LocalIntInteraction) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::GlobalFloat) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::GlobalInt) catch err; throw(err.error) end

    @test_throws ErrorException try @eval @agent(0, l::Local, l::GlobalFloat) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, l::Local, l::GlobalInt) catch err; throw(err.error) end

end