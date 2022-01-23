using Base: LogicalIndex
@testset "event" begin

    for platform in testplatforms

        #Execute add agent without problems
        @test_nowarn begin
            m = @agent(
                0,

                [active,id1]::Identity,
                loc::Local,

                UpdateLocal = 
                begin
                    addAgent(
                        active = 1,
                        id1 = 1,
                        loc = 0.5
                    )
                end
            )

            m = compile(m,platform=platform)
        end

        #Linear growth
        m = @agent(
            0,

            [active,id1]::Identity,
            loc::Local,

            UpdateLocal = 
            begin
                if active == 1
                    addAgent(
                        active = 1,
                        id1 = 4,
                        loc = 67.
                    )
                    active = 0
                end
            end
        )

        m = compile(m,platform=platform,debug=false)
        # println(m.program)

        @test_nowarn begin

            com = Community(m,N=1)
            n = com.N 

            com.id1 .= 4
            com.active .= 1
            com.loc .= 67.

            comt = m.evolve(com,dt=1,tMax=10,nMax=11)

            if comt[end].N != 11 error() end
            if !prod(comt[end].loc .== 67.) error() end
            if !prod(comt[end].id1 .== 4) error() end
            if !any(comt[end].id .== 1:11) error() end

        end

        #Execute Death without problems
        @test_nowarn begin
            m = @agent(
                0,

                [active,id1]::Identity,
                loc::Local,

                UpdateLocal = begin
                    if loc < t
                        removeAgent()
                    end
                end
            )

            m = compile(m,platform=platform)
        end

        m = @agent(
            1,

            [active,id1]::Identity,
            [loc]::Local,

            UpdateLocal = begin
                id1 = 3
                x = x
                if loc < t
                    removeAgent()
                end
            end,
        )

        m = compile(m,platform=platform)
        # println(m.program)
        
        @test_nowarn begin

            com = Community(m,N=100)
            n = com.N 

            com.loc .= 0:99
            com.x .= 1:100

            comt = m.evolve(com,dt=1,tMax=105,nMax=100)

            if !any(comt.N[2:102] .== Array(100:-1:0)) error() end
            if !any(comt.N[102:end] .== 0) error() end
            for i in 1:100
                if !Bool(prod(comt[i].id .== comt[i].x)) error() end
            end

        end

        #Add and remove agents at the same time
        m = @agent(
            0,

            [active,id1]::Identity,
            [loc]::Local,

            UpdateLocal = begin
                if active == 1
                    addAgent(id1 = 4,
                            active = 1,
                            loc = 67
                            )
                    removeAgent()
                end
            end,
        )

        m = compile(m,platform=platform)
        # println(prettify(m.program))
        
        @test_nowarn begin

            com = Community(m,N=1)
            n = com.N 

            com.id1 .= 4
            com.loc .= 67

            comt = m.evolve(com,dt=1,tMax=105,nMax=100)

            if any(comt.N .!= 1) error() end
            if any([comt.id1[i,i] for i in 1:105] .!= 4) error() end
            if any([comt.loc[i,i] for i in 1:105] .!= 67) error() end
            if any(comt[end].id .!= 106) error() end
        end

        #Remove randomly
        m = @agent(2,
            l::Local,
            tDie::Local,
            UpdateLocal=begin
                if tDie < t
                    # addAgent(x=x,y=y,tDie=tDie+1,l=l)
                    removeAgent()
                end
            end
        )
        model = compile(m,platform=platform,neighbors="grid")
        com = Community(model,N=1000)
        com.x .= rand(com.N)
        com.y .= rand(com.N)
        com.tDie .= rand(com.N)
        com.simulationBox .= [0 1;0 1]
        com.radiusInteraction = .1

        @test_nowarn begin
            model.evolve(com,dt=0.01,tMax=.9,nMax=1000,dtSave=10)
        end    

    end
    
end