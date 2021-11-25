@testset "constructors" begin

    m = @agent 3
    mo = compile(m)
    f(x) = sqrt(sum(x.^2)) < 10

    @test_nowarn initialiseCommunityCompactHexagonal(mo,[-10 10;-10 10;-10 10],.5)
    @test_nowarn initialiseCommunityCompactHexagonal(mo,[-10 10;-10 10;-10 10],.5,fExtrude = f)
    @test_nowarn initialiseCommunityCompactCubic(mo,[-10 10;-10 10;-10 10],.5)
    @test_nowarn initialiseCommunityCompactCubic(mo,[-10 10;-10 10;-10 10],.5,fExtrude = f)

end