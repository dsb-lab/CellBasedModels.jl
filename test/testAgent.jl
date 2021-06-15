@testset "agent" begin

    @test_nowarn Agent()

    @test_nowarn @agent(
        Hola
    )

    @test_throws ErrorException try @eval @agent cell sin::Local catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent cell Normal::Local catch err; throw(err.error) end

    @test_nowarn @agent(
        Hola,
        
        id::Identity,
        l::Local,
        v::Variable,
        g::Global,
        ga::GlobalArray,
        i::Interaction,
        
        Equation = dv = 34*dt ,
        UpdateLocal = l += 1,
        UpdateGlobal = g += 1,
        UpdateInteraction = i += 1,
        UpdateLocalInteraction = i += 1
    )

    m = @agent(
        Hola,

        id::Identity,
        l::Local,
        v::Variable,
        g::Global,
        ga::GlobalArray,
        i::Interaction,

        Equation = dv = 34*dt ,
        UpdateLocal = l += 1,
        UpdateGlobal = g += 1,
        UpdateInteraction = i += 1,
        UpdateLocalInteraction = i += 1
    )
    for i in keys(m.declaredSymbols)
        @test length(m.declaredSymbols[i]) == 1
    end
    for i in keys(m.declaredUpdates)
        @test [i for i in m.declaredUpdates[i].args if typeof(i) != LineNumberNode] != []
    end
    
    @test_nowarn @agent(
        Hola,

        [id,id2]::Identity,
        [l,l2]::Local,
        [v,v2]::Variable,
        [g,g2]::Global,
        [ga,ga2]::GlobalArray,
        [i,i2]::Interaction,

        Equation = dv = 34*dt ,
        UpdateLocal = l += 1,
        UpdateGlobal = g += 1,
        UpdateInteraction = i += 1,
        UpdateLocalInteraction = i += 1
    )

    m = @agent(
        Hola,

        [id,id2]::Identity,
        [l,l2]::Local,
        [v,v2]::Variable,
        [g,g2]::Global,
        [ga,ga2]::GlobalArray,
        [i,i2]::Interaction,

        Equation = dv = 34*dt ,
        UpdateLocal = l += 1,
        UpdateGlobal = g += 1,
        UpdateInteraction = i += 1,
        UpdateLocalInteraction = i += 1,

    )
    for i in keys(m.declaredSymbols)
        @test length(m.declaredSymbols[i]) == 2
    end
    for i in keys(m.declaredUpdates)
        @test [i for i in m.declaredUpdates[i].args if typeof(i) != LineNumberNode] != []
    end

    @test_throws ErrorException try @eval @agent(cell, [l,l]::Local) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(cell, [l,l]::Global) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(cell, [l,l]::Variable) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(cell, [l,l]::Interaction) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(cell, [l,l]::GlobalArray) catch err; throw(err.error) end

    @test_throws ErrorException try @eval @agent(cell, l::Local, l::Global) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(cell, l::Local, l::Variable) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(cell, l::Local, l::Interaction) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(cell, l::Local, l::GlobalArray) catch err; throw(err.error) end
    
    @test_nowarn begin
        m1 = @agent cell1 l1::Local
        m2 = @agent cell2 l2::Local

        m3 = add(m1,m2)
    end

    @test_throws MethodError begin
        m1 = @agent cell1 l1::Local

        m3 = add(m1,3)
    end

end