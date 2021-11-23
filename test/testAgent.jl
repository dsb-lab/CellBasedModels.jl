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
        g::Global,
        ga::GlobalArray,
        
        Equation = d_v = 34*dt ,
        UpdateLocal = l += 1,
        UpdateGlobal = g += 1,
        UpdateInteraction = i += 1,
        UpdateLocalInteraction = i += 1
    )

    m = @agent(
        1,

        g::Global,
        ga::GlobalArray,
        m::Medium,

        Equation = d_v = 34*dt ,
        UpdateLocal = l += 1,
        UpdateGlobal = g += 1,
        UpdateInteraction = i += 1,
        UpdateLocalInteraction = i += 1,
        Boundary = BoundaryFlat(1)
    )
    for i in keys(m.declaredSymbols)
        @test length(m.declaredSymbols[i]) == 1
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

        Equation = d_v = 34*dt ,
        UpdateLocal = l += 1,
        UpdateGlobal = g += 1,
        UpdateInteraction = i += 1,
        UpdateLocalInteraction = i += 1
    )

    m = @agent(
        2,

        [id2]::Identity,
        [g,g2]::Global,
        [ga,ga2]::GlobalArray,
        [m1,m2]::Medium,

        Equation = d_v = 34*dt ,
        UpdateLocal = l += 1,
        UpdateGlobal = g += 1,
        UpdateInteraction = i += 1,
        UpdateLocalInteraction = i += 1,
        Boundary = BoundaryFlat(2)
    )
    for i in keys(m.declaredSymbols)
        @test length(m.declaredSymbols[i]) == 2
    end
    for i in keys(m.declaredUpdates)
        @test [i for i in m.declaredUpdates[i].args if typeof(i) != LineNumberNode] != []
    end

    @test_throws ErrorException try @eval @agent(0, [l,l]::Local) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::Global) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::Variable) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::Interaction) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, [l,l]::GlobalArray) catch err; throw(err.error) end

    @test_throws ErrorException try @eval @agent(0, l::Local, l::Global) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, l::Local, l::Variable) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, l::Local, l::Interaction) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(0, l::Local, l::GlobalArray) catch err; throw(err.error) end

    @test_nowarn @agent(0, Boundary=BoundaryFlat())
    @test_throws ErrorException try @eval @agent(0, Boundary=Periodic()) catch err; throw(err.error) end

end