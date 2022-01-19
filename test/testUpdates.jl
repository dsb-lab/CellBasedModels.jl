@testset "Updates" begin

    for i in testplatforms

        #Update Local
        m = @agent(
            3,
            
            [w]::Local,
            
            UpdateLocal = 
            begin
                x += 1 
                z += 2
                w = Uniform(1.,2.)
            end
        )
        mo = compile(m, platform = i, debug=false)
        # println(mo.program)

        @test_nowarn begin

            com = Community(mo,N=1000)
            com.x .= 0.
            com.y .= 0.
            com.z .= 0.
            com.w = rand(AgentBasedModels.Uniform(1,2),com.N)
            comt = mo.evolve(com,dt=1.,tMax=100)#,t=0.,N=com.N,nMax=com.N)

            for i in 1:10
                if comt[i].x != (i-1)*ones(com.N) println("x ", i, " ", comt[i].x);error() end 
                if comt[i].y != 7*zeros(com.N) println("y ", i, " ", comt[i].y);error() end 
                if comt[i].z != 2*(i-1)*ones(com.N) println("z ", i, " ", comt[i].z);error() end 
                if !prod(Bool.((comt[i].w .>= 1) .* (comt[i].w .<= 2))) println("w ", i, " ", comt[i].w);error() end 
            end
        end


        #Update Identity
        m = @agent(
            3,
            
            [w1,w2]::Identity,
            
            UpdateLocal = 
            begin
                nothing
                x += 1
                z += 2
                w1 = floor(Uniform(1.,2.))
                w2 = ceil(Uniform(1.,2.))
            end
        )
        mo = compile(m, platform = i, debug=false)
        #println(mo.program)

        @test_nowarn begin

            com = Community(mo,N=10)
            com.x .= 0
            com.y .= 0
            com.z .= 0
            com.w1 .= 1
            com.w2 .= 2
            comt = mo.evolve(com,dt=1.,tMax=10)#,t=0.,N=com.N,nMax=com.N)

            for i in 1:10
                if comt[i].x != (i-1)*ones(Int,10) println("x ", i, " ", comt[i].x);error() end 
                if comt[i].y != 7*zeros(Int,10) println("y ", i, " ", comt[i].y);error() end 
                if comt[i].z != 2*(i-1)*ones(Int,10) println("z ", i, " ", comt[i].z);error() end 
                if !prod((comt[i].w1 .== 1)) println("w ", i, " ", comt[i].w1);error() end 
                if !prod((comt[i].w2 .== 2)) println("w ", i, " ", comt[i].w2);error() end 
            end
        end


        #Update Global
        m = @agent(
            3,
            
            [x1,y1,z1,w]::Global,
            
            UpdateGlobal = 
            begin
                x1 += 1 
                z1 += 2
                w = Uniform(1.,2.)
            end
        )
        mo = compile(m, platform = i, debug=false)
        #println(mo.program)

        @test_nowarn begin

            com = Community(mo,N=10)
            com.x1 = 0.
            com.y1 = 0.
            com.z1 = 0.
            com.w = 1.2
            comt = mo.evolve(com,dt=1.,tMax=10)#,t=0.,N=com.N,nMax=com.N)

            for i in 1:10
                if comt[i].x1 != 1. *(i-1) println("x ", i, " ", comt[i].x);error() end 
                if comt[i].y1 != 0. println("y ", i, " ", comt[i].y);error() end 
                if comt[i].z1 != 2. *(i-1) println("z ", i, " ", comt[i].z);error() end 
                if !prod(Bool((comt[i].w .>= 1) * (comt[i].w .<= 2))) println("w ", i, " ", comt[i].w);error() end 
            end
        end


        #Update Local Interaction
        m = @agent(
            3,
            
            UpdateLocalInteraction = 
            begin
                x.i += 1
                z.i += 2
            end
        )
        mo = compile(m, platform = i, debug=false)
        # println(prettify(mo.program))

        @test_nowarn begin

            com = Community(mo,N=10)
            com.x .= 0.
            com.y .= 0.
            com.z .= 0.
            comt = mo.evolve(com,dt=1.,tMax=10)#,t=0.,N=com.N,nMax=com.N)

            for i in 1:10
                if comt[i].x != 10*ones(10) println("x ", i, " ", comt[i].x);error() end 
                if comt[i].y != zeros(10) println("y ", i, " ", comt[i].y);error() end 
                if comt[i].z != 20*ones(10) println("z ", i, " ", comt[i].z);error() end 
            end
        end

    end

end