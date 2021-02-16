@testset "basic" begin

    #Tests addGlobal
    a = Model()
    @test_nowarn addGlobal!(a,:x)
    @test :x in a.declaredSymb["glob"]
    @test_throws ErrorException addGlobal!(a,:x)

    a = Model()
    @test_nowarn addGlobal!(a,[:x,:y])
    @test :x in a.declaredSymb["glob"] && :y in a.declaredSymb["glob"]
    @test_throws ErrorException addGlobal!(a,:x)
    @test_throws ErrorException addGlobal!(a,:y)

    a = Model()
    @test_nowarn addGlobal!(a,:x,updates="x += 1")

    a = Model()
    @test_nowarn addGlobal!(a,[:x,:y],updates="x += 1; y += 3*dt")

    a = Model()
    @test_nowarn addGlobal!(a,:x,updates="x += f",randVar=[(:f,Uniform(0,1))])

    a = Model()
    @test_nowarn addGlobal!(a,[:x,:y],updates="x += 1; y += 3*dt",randVar=[(:f,Uniform(0,1)),(:g,Uniform(0,1))])

    #Tests addLocal!
    a = Model()
    @test_nowarn addLocal!(a,:x)
    @test :x in a.declaredSymb["loc"]
    @test_throws ErrorException addLocal!(a,:x)

    a = Model()
    @test_nowarn addLocal!(a,[:x,:y])
    @test :x in a.declaredSymb["loc"] && :y in a.declaredSymb["loc"]
    @test_throws ErrorException addLocal!(a,:x)
    @test_throws ErrorException addLocal!(a,:y)

    a = Model()
    @test_nowarn addLocal!(a,:x,updates="x += 1")

    a = Model()
    @test_nowarn addLocal!(a,[:x,:y],updates="x += 1; y += 3*dt")

    a = Model()
    @test_nowarn addLocal!(a,:x,updates="x += f",randVar=[(:f,Uniform(0,1))])

    a = Model()
    @test_nowarn addLocal!(a,[:x,:y],updates="x += 1; y += 3*dt",randVar=[(:f,Uniform(0,1)),(:g,Uniform(0,1))])

    #Tests addLocalInteraction!
    a = Model()

    a = Model()
    @test_nowarn addLocalInteraction!(a,:x,"x₁ += 1")

    a = Model()
    @test_nowarn addLocalInteraction!(a,[:x,:y],"x += 1; y += 3*dt")

    a = Model()
    @test_nowarn addLocalInteraction!(a,:x,"x += f",randVar=[(:f,Uniform(0,1))])

    a = Model()
    @test_nowarn addLocalInteraction!(a,[:x,:y],"x += 1; y += 3*dt",randVar=[(:f,Uniform(0,1)),(:g,Uniform(0,1))])

end