using Base: LogicalIndex
@testset "event" begin

    for platform in ["cpu","gpu"]

        @test_nowarn begin
            m = @agent(
                cell,

                [active,id1]::Identity,
                loc::Local,

                EventDivision = 
                begin
                    if active == 1
                        active₁ == 2
                        active₂ == 1
                    end
                end
            )

            m = compile(m,platform=platform)
        end


        m = @agent(
            cell,

            [active,id1]::Identity,
            loc::Local,

            EventDivision = 
            begin
                if active == 1
                    active₁ = 2
                    active₂ = 1
                end
            end
        )

        m = compile(m,platform=platform)
        println(m.program)

        @test_nowarn begin

            com = Community(m,N=1)
            n = com.N 

            com.id1 .= 4
            com.active .= 1
            com.loc .= 67.

            comt = m.evolve(com,dt=1,tMax=10,nMax=100)

            println(comt[end].N)
            println(comt[1].declaredSymbols_)
            println(comt.active)
            if comt[end].N != 10*n error() end

        end
    end
end