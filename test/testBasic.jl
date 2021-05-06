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
    @test_throws ErrorException addGlobal!(a,[:x,:x])

    a = Model()
    @test_nowarn addGlobal!(a,:x,updates="x += 1")

    a = Model()
    @test_nowarn addGlobal!(a,[:x,:y],updates="x += 1; y += 3*dt")

    a = Model()
    @test_nowarn addGlobal!(a,:x,updates="x += f",randVar=[(:f,:(Uniform(0,1)))])
    @test_throws ErrorException addGlobal!(a,:z,randVar=[(:f,:(Uniform(0,1)))])

    a = Model()
    @test_nowarn addGlobal!(a,[:x,:y],updates="x += 1; y += 3*dt",randVar=[(:f,:(Uniform(0,1))),(:g,:(Uniform(0,1)))])
    @test_throws ErrorException addGlobal!(a,:z,randVar=[(:f,:(Uniform(0,1)))])
    @test_throws ErrorException addGlobal!(a,:z,randVar=[(:g,:(Uniform(0,1)))])

    a = Model()
    @test_nowarn addGlobal!(a,(:x,[2,3]))
    @test (:x,[2,3]) in a.declaredSymbArrays["glob"]
    @test_throws ErrorException addGlobal!(a,(:x,[2,2]))

    a = Model()
    @test_nowarn addGlobal!(a,(:x,[2,3]),updates="x[1,2] += 1")

    a = Model()
    @test_nowarn addGlobal!(a,(:x,[2,3]),updates="x[1,2]=2",randVar=[((:f,[2,3]),:(Uniform(0,1))),((:g,[2,3]),:(Uniform(0,1),[4]))])
    @test_throws ErrorException addGlobal!(a,(:y,[2,3]),updates="y[1,2]=2",randVar=[((:f,[2,3]),:(Uniform(0,1)))])

    a = Model()
    @test_nowarn addGlobal!(a,[(:x,[2,3]),(:y,[4])])
    @test (:x,[2,3]) in a.declaredSymbArrays["glob"]
    @test (:y,[4]) in a.declaredSymbArrays["glob"]
    @test_throws ErrorException addGlobal!(a,(:y,[2,3]))

    a = Model()
    @test_nowarn addGlobal!(a,[(:x,[2,3]),(:y,[4])],updates="x[1,2]=2;y[3]=5")

    a = Model()
    @test_nowarn addGlobal!(a,[(:x,[2,3]),(:y,[4])],updates="x[1,2]=2;y[3]=5",randVar=[((:f,[2,3]),:(Uniform(0,1))),((:g,[2,3]),:(Uniform(0,1),[4]))])
    @test_throws ErrorException addGlobal!(a,[(:z,[2,3])],updates="x[1,2]=2;y[3]=5",randVar=[((:f,[2,3]),:(Uniform(0,1)))])

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