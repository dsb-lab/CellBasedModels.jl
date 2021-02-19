@testset "lattice" begin

    @test_nowarn latticeCompactHexagonal([[0.,5.]],.5)
    @test_nowarn latticeCompactHexagonal([[0.,5.],[0.,5.]],.5)
    @test_nowarn latticeCompactHexagonal([[0.,5.],[0.,5.],[0.,5.]],.5)
    
    @test_nowarn latticeCompactHexagonal([[0.,5.]],.5,noiseRatio=0.1,holesRatio=0.5)
    @test_nowarn latticeCompactHexagonal([[0.,5.],[0.,5.]],.5,noiseRatio=0.1,holesRatio=0.5)
    @test_nowarn latticeCompactHexagonal([[0.,5.],[0.,5.],[0.,5.]],.5,noiseRatio=0.1,holesRatio=0.5)

    @test_nowarn latticeCubic([[0.,5.]],.5)
    @test_nowarn latticeCubic([[0.,5.],[0.,5.]],.5)
    @test_nowarn latticeCubic([[0.,5.],[0.,5.],[0.,5.]],.5)

    @test_nowarn latticeCubic([[0.,5.]],.5,noiseRatio=0.1,holesRatio=0.5)
    @test_nowarn latticeCubic([[0.,5.],[0.,5.]],.5,noiseRatio=0.1,holesRatio=0.5)
    @test_nowarn latticeCubic([[0.,5.],[0.,5.],[0.,5.]],.5,noiseRatio=0.1,holesRatio=0.5)

end