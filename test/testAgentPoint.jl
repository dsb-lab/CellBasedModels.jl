@testset "AgentPoint" begin

    agentPoint = AgentPoint(:cell, (health=Float64, age=Int64))

    @test agentPoint.name == :cell
    @test length(agentPoint.agentProperties) == 2
    @test haskey(agentPoint.agentProperties, :health)
    @test agentPoint.agentProperties[:health] == Float64
    @test haskey(agentPoint.agentProperties, :age)
    @test agentPoint.agentProperties[:age] == Int64

    community = CommunityPoint(agentPoint, 100)
    @test community.agent == agentPoint
    @test community.N == 100
    
    @test community.health == zeros(Float64, 100)
    @test community.age == zeros(Int64, 100)

end