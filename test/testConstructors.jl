@testset "constructors" begin

    sphere(v) = sqrt(sum(v.^2)) < 10
    @test randomSphereFilling(sphere,1,[0,0,0])

end