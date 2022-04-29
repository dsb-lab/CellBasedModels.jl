@testset "agent" begin

    @test_nowarn Agent()

    @test_nowarn @agent(0)
    @test_nowarn @agent(1)
    @test_nowarn @agent(2)
    @test_nowarn @agent(3)

    @test_throws ErrorException try @eval @agent 0 sin::Local catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent 0 Normal::Local catch err; throw(err.error) end

    @test_nowarn @agent(
        0,
        
        l::Local,
        li::LocalInteraction,
        id2::Identity,
        id3::IdentityInteraction,
        g::Global,
        ga::GlobalArray,
        l2::Local=0,
        li2::LocalInteraction=0,
        id4::Identity=0,
        id5::IdentityInteraction=0,
        g2::Global=0,
        ga2::GlobalArray=0,

        UpdateVariable = d(v) = 34*dt ,
        UpdateLocal = l += 1,
        UpdateGlobal = g += 1,
        UpdateInteraction = i += 1,
        UpdateLocalInteraction = l.i += 1
    )

    m = @agent(
        1,

        l::LocalInteraction,
        l1::IdentityInteraction,
        g::Global,
        ga::GlobalArray,
        m::Medium,

        UpdateVariable = d(v) = 34*dt ,
        UpdateLocal = l += 1,
        UpdateGlobal = g += 1,
        UpdateInteraction = i += 1,
        UpdateLocalInteraction = i += 1,
    )
    for i in keys(m.declaredSymbols)
        @test length(keys(m.declaredSymbols[i])) == 1
    end
    for i in keys(m.declaredUpdates)
        @test [i for i in m.declaredUpdates[i].args if typeof(i) != LineNumberNode] != []
    end
    
    @test_nowarn @agent(
        0,

        [id2]::Identity,
        [l,l2]::Local,
        [g,g2]::Global,
        [ga,ga2]::GlobalArray,
        [id3,id4]::Identity = [nothing,1],
        [l3,l4]::Local = [nothing,1],
        [g3,g4]::Global = [nothing,1],
        [ga3,ga4]::GlobalArray = [nothing,1],

        UpdateVariable = d(v) = 34*dt ,
        UpdateLocal = l += 1,
        UpdateGlobal = g += 1,
        UpdateInteraction = i += 1,
        UpdateLocalInteraction = i += 1
    )

    m = @agent(
        2,

        [id2]::Identity,
        [li,li2]::LocalInteraction,
        [idi,idi2]::IdentityInteraction,
        [g,g2]::Global,
        [ga,ga2]::GlobalArray,
        [m1,m2]::Medium,

        UpdateVariable = d(v) = 34*dt ,
        UpdateLocal = l += 1,
        UpdateGlobal = g += 1,
        UpdateInteraction = i += 1,
        UpdateLocalInteraction = i += 1,
    )
    for i in keys(m.declaredSymbols)
        @test length(keys(m.declaredSymbols[i])) == 2
    end
    for i in keys(m.declaredUpdates)
        @test [i for i in m.declaredUpdates[i].args if typeof(i) != LineNumberNode] != []
    end

    @test_throws ErrorException try @eval @agent(0, [l,l]::Local) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::LocalInteraction) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::Identity) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::IdentityInteraction) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::Global) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::Variable) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::GlobalArray) catch err; throw(err.error) end

    @test_throws ErrorException try @eval @agent(0, l::Local, l::Global) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, l::Local, l::Variable) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, l::Local, l::GlobalArray) catch err; throw(err.error) end

end