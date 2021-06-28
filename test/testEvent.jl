using Base: LogicalIndex
@testset "event" begin

    for platform in testplatforms

        #Execute Division without problems
        @test_nowarn begin
            m = @agent(
                cell,

                [active,id1]::Identity,
                loc::Local,

                EventDivision = 
                begin
                    if active == 1
                        active_1 = 2
                        active_2 = 1
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
                    active_1 = 2
                    active_2 = 1
                end
            end
        )

        m = compile(m,platform=platform)
        # println(m.program)

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
                    id1_1 = id1 + 1
                    id1_2 = id1 + 1
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

            if comt[end].N != n*2^comt[end].t error() end
            if !prod(comt[end].id1 .== comt[end].t) error() end

        end

        #Execute Death without problems
        @test_nowarn begin
            m = @agent(
                cell,

                [active,id1]::Identity,
                loc::Local,

                EventDeath = loc < t
            )

            m = compile(m,platform=platform)
        end

        m = @agent(
            cell,

            [active,id1]::Identity,
            [x,loc]::Local,

            UpdateLocal = begin
                id1 = 3
                x = x
            end,

            EventDeath = loc <= t
        )

        m = compile(m,platform=platform)
        #println(m.program)
        
        @test_nowarn begin

            com = Community(m,N=100)
            n = com.N 

            com.loc .= 0:99
            com.x .= 1:100

            comt = m.evolve(com,dt=1,tMax=105,nMax=100)

            if !Bool(prod(comt.N[1:101] .== Array(100:-1:0))) error() end
            if !Bool(prod(comt.N[101:end] .== 0)) error() end
            for i in 1:100
                if !Bool(prod(comt[i].agentId .== comt[i].x)) error() end
            end

        end

    end
end