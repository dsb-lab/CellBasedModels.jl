@testset "compile" begin

    @test_nowarn begin
        agent = @agent(3,
        UpdateLocal=
        begin
            x += 1
            if x > 5
                nothing
            else
                addAgent(x=0,y=0,z=0)
            end
        end
        )

        println(agent.declaredUpdatesCode[:UpdateLocal])
    end
end