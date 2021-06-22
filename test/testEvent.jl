using Base: LogicalIndex
@testset "event" begin

    for platform in ["gpu"]#,"gpu"]

        #Execute
        @test_nowarn begin
            m = @agent(
                cell,

                [active,id1]::Identity,
                loc::Local,

                EventDivision = 
                begin
                    if active == 1
                        active_₁ == 2
                        active_₂ == 1
                    end
                end
            )

            m = compile(m,platform=platform)
        end

        #Linear growth
        m = @agent(
            cell,

            [active,id1]::Identity,
            loc::Local,

            EventDivision = 
            begin
                if active == 1
                    active_₁ = 2
                    active_₂ = 1
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

            comt = m.evolve(com,dt=1,tMax=10,nMax=15)

            if comt[end].N != n*comt[end].t+1 error() end
            if !prod(comt[end].loc .== 67.) error() end
            if !prod(comt[end].id1 .== 4) error() end
            if maximum(x->isnan(x) ? -Inf : x, comt.agentId) != 2*length(comt)-1 error() end

        end

        #Exponential growth
        m = @agent(
            cell,

            [active,id1,d]::Identity,
            loc::Local,

            EventDivision = 
            begin
                if active == 2
                    id1_₁ = id1 + 1
                    id1_₂ = id1 + 1
                end
            end
        )

        m = compile(m,platform=platform)
        #println(m.program)

        @test_nowarn begin

            com = Community(m,N=1)
            n = com.N 

            com.id1 .= 0
            com.active .= 2
            com.loc .= 67.

            comt = m.evolve(com,dt=1,tMax=6,nMax=100)

            if comt[end].N != n*2^(comt[end].t-1) error() end
            if !prod(comt[end].id1 .== comt[end].t) error() end

        end
    end
end