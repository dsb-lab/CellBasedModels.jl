@testset "BaseFunctions" begin

    @test isDimension(:L)  # true
    @test isDimension(:M) # true
    @test !isDimension(:a) # false
    @test isDimension(:(L^2)) # true
    @test isDimension(:(L/M)) # true

    @test isDimensionUnit(:m)  # true
    @test isDimensionUnit(:s) # true
    @test !isDimensionUnit(:(a/k)) # false
    @test isDimensionUnit(:(m/s^2)) # true
    @test isDimensionUnit(:(m/s)) # true

    @test dimensionUnits2dimensions(:m) == :L # returns :(L/T)
    @test dimensionUnits2dimensions(:(m/s)) == :(L/T) # returns :(L/T)
    
    @test compareDimensionsUnits2dimensions(:m, :L) # true
    @test compareDimensionsUnits2dimensions(:(m/ms), :(L/T)) # true
    @test !compareDimensionsUnits2dimensions(:m, :(L^2)) # false

end
