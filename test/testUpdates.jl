f(x,y,z) = (z-y)*x+y

@testset "Updates" begin

    if CUDA.has_cuda()
        testplatforms = ["cpu","gpu"]
    else
        testplatforms = ["cpu"]
    end

    for i in ["gpu","cpu"]#testplatforms

        #Update Local
        m = @agent(
            Hola,
            
            [x,y,z,w]::Local,
            
            UpdateLocal = 
            begin
                x += 1 
                z += 2
                w = Uniform(1.,2.)
            end
        )
        mo = compile(m, platform = i, debug=false)
        #println(mo.program)

        @test_nowarn begin

            com = Community(mo,N=1000)
            com.x .= 0.
            com.y .= 0.
            com.z .= 0.
            com.w = rand(Uniform(1,2),com.N)
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
            Hola,
            
            [x,y,z,w1,w2]::Identity,
            
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
            Hola,
            
            [x,y,z,w]::Global,
            
            UpdateGlobal = 
            begin
                x += 1 
                z += 2
                w = Uniform(1.,2.)
            end
        )
        mo = compile(m, platform = i, debug=true)
        #println(mo.program)

        @test_nowarn begin

            com = Community(mo,N=10)
            com.x = 0.
            com.y = 0.
            com.z = 0.
            com.w = 1.2
            comt = mo.evolve(com,dt=1.,tMax=10)#,t=0.,N=com.N,nMax=com.N)

            for i in 1:10
                if comt[i].x != 1. *(i-1) println("x ", i, " ", comt[i].x);error() end 
                if comt[i].y != 0. println("y ", i, " ", comt[i].y);error() end 
                if comt[i].z != 2. *(i-1) println("z ", i, " ", comt[i].z);error() end 
                if !prod(Bool((comt[i].w .>= 1) * (comt[i].w .<= 2))) println("w ", i, " ", comt[i].w);error() end 
            end
        end


        #Update Local Interaction
        m = @agent(
            Hola,
            
            [x,y,z]::Local,
            
            UpdateLocalInteraction = 
            begin
                x += 1
                z += 2
            end
        )
        mo = compile(m, platform = i, debug=false)
        #println(mo.program)

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