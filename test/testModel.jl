@testset "model" begin
    @test_nowarn Model()
    @test_throws ErrorException Model().eval()
    @test_throws ErrorException Model().eval(34,:t)
end