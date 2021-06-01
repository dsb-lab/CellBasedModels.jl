@testset "agent" begin
    @test_nowarn @agent(
        Hola
    )

    @test_nowarn @agent(
        Hola,
        id::Identity,
        l::Local,
        v::Variable,
        g::Global,
        ga::GlobalArray=[2,3],
        i::Interaction,
        e::Equation = dv = 34*dt ,
        ul::UpdateLocal = l += 1,
        ug::UpdateGlobal = g += 1,
        ug::UpdateInteraction = i += 1,
        uli::UpdateLocalInteraction = i += 1
    )

    m = @agent(
        Hola,
        id::Identity,
        l::Local,
        v::Variable,
        g::Global,
        ga::GlobalArray=[2,3],
        i::Interaction,
        e::Equation = dv = 34*dt ,
        ul::UpdateLocal = l += 1,
        ug::UpdateGlobal = g += 1,
        ug::UpdateInteraction = i += 1,
        uli::UpdateLocalInteraction = i += 1)
    for i in keys(m.declaredSymbols)
        @test length(m.declaredSymbols[i]) == 1
    end
    for i in keys(m.declaredUpdates)
        @test length(m.declaredUpdates[i]) == 1
    end
    
    @test_nowarn @agent(
        Hola,
        [id,id2]::Identity,
        [l,l2]::Local,
        [v,v2]::Variable,
        [g,g2]::Global,
        [ga,ga2]::GlobalArray=[2,3],
        [i,i2]::Interaction,
        ::Equation = dv = 34*dt ,
        ::UpdateLocal = l += 1,
        ::UpdateGlobal = g += 1,
        ::UpdateInteraction = i += 1,
        ::UpdateLocalInteraction = i += 1)
    
    m = @agent(
        Hola,
        [id,id2]::Identity,
        [l,l2]::Local,
        [v,v2]::Variable,
        [g,g2]::Global,
        [ga,ga2]::GlobalArray=[2,3],
        [i,i2]::Interaction,
        ::Equation = dv = 34*dt ,
        ::UpdateLocal = l += 1,
        ::UpdateGlobal = g += 1,
        ::UpdateInteraction = i += 1,
        ::UpdateLocalInteraction = i += 1)
    for i in keys(m.declaredSymbols)
        @test length(m.declaredSymbols[i]) == 2
    end
    for i in keys(m.declaredUpdates)
        @test length(m.declaredUpdates[i]) == 1
    end
        
    @test_nowarn @add(id::Identity,
        l::Local,
        v::Variable,
        g::Global,
        ga::GlobalArray=[2,3],
        i::Interaction,
        ::Equation = dv = 34*dt ,
        ::UpdateLocal = l += 1,
        ::UpdateGlobal = g += 1,
        ::UpdateInteraction = i += 1,
        ::UpdateLocalInteraction = i += 1)

    l = @add(id::Identity,
        l::Local,
        v::Variable,
        g::Global,
        ga::GlobalArray=[2,3],
        i::Interaction,
        ::Equation = dv = 34*dt ,
        ::UpdateLocal = l += 1,
        ::UpdateGlobal = g += 1,
        ::UpdateInteraction = i += 1,
        ::UpdateLocalInteraction = i += 1)

    @test typeof(l) == Array{Expr,1}

    m = @agent cell
    @test_nowarn agent!(m,l)

    @test_throws ErrorException try @eval @agent(cell, [l,l]::Local) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(cell, [l,l]::Global) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(cell, [l,l]::Variable) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(cell, [l,l]::Interaction) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(cell, [l,l]::GlobalArray) catch err; throw(err.error) end

    @test_throws ErrorException try @eval @agent(cell, l::Local, l::Global) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(cell, l::Local, l::Variable) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(cell, l::Local, l::Interaction) catch err; throw(err.error) end
    @test_throws ErrorException try @eval @agent(cell, l::Local, l::GlobalArray) catch err; throw(err.error) end

    m = @agent cell l::Local
    @test_throws ErrorException try @eval agent!(m, @add l::Local) catch err; throw(err.error) end
    m = @agent cell l::Local
    @test_throws ErrorException try @eval agent!(m, @add l::Global) catch err; throw(err.error) end
    m = @agent cell l::Local
    @test_throws ErrorException try @eval agent!(m, @add l::Interaction) catch err; throw(err.error) end
    m = @agent cell l::Local
    @test_throws ErrorException try @eval agent!(m, @add l::GlobalArray) catch err; throw(err.error) end
end