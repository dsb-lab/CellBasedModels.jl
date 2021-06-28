@testset "auxiliar" begin

    m = @agent cell [x,y]::Local
    @test_nowarn AgentBasedModels.checkIsDeclared_(m,:x) 
    @test_nowarn AgentBasedModels.checkIsDeclared_(m,[:x]) 
    @test_nowarn AgentBasedModels.checkIsDeclared_(m,[:x,:y]) 
    @test_throws ErrorException AgentBasedModels.checkIsDeclared_(m,:g) 
    @test_throws ErrorException AgentBasedModels.checkIsDeclared_(m,[:g]) 
    @test_throws ErrorException AgentBasedModels.checkIsDeclared_(m,[:x,:g]) 

    @test AgentBasedModels.subs_(:(x += 3*x),:x,:y) == :(y += 3*y)
    @test AgentBasedModels.subs_(:(x += 3*x),:x,:y,update=true) == :(y += 3*x)

    m = @agent(
        cell,
        l::Local,
        g::Global,
        h::GlobalArray,
        id::Identity
    )
    p = AgentBasedModels.Program_(); s = SimulationFree()
    AgentBasedModels.updates_!(p,m,s)
    @test AgentBasedModels.vectorize_(m,:(l = 1), p) == :(localV[ic1_,1]=1)
    @test AgentBasedModels.vectorize_(m,:(l_i = 1), p) == :(localV[ic1_,1]=1)
    @test AgentBasedModels.vectorize_(m,:(l_j = 1), p) == :(localV[nnic2_,1]=1)
    @test AgentBasedModels.vectorize_(m,:(g = 1), p) == :(globalV[1]=1)
    @test AgentBasedModels.vectorize_(m,:(h[1,2] = 1), p) == :(h[1,2]=1)
    @test AgentBasedModels.vectorize_(m,:(id = 1), p) == :(identityV[ic1_,2]=1)
    @test AgentBasedModels.vectorize_(m,:(id_i = 1), p) == :(identityV[ic1_,2]=1)
    @test AgentBasedModels.vectorize_(m,:(id_j = 1), p) == :(identityV[nnic2_,2]=1)

    @test AgentBasedModels.vectorize_(m,:(l = l), p) == :(localV[ic1_,1]=localV[ic1_,1])
    @test AgentBasedModels.vectorize_(m,:(l_i = l_i), p) == :(localV[ic1_,1]=localV[ic1_,1])
    @test AgentBasedModels.vectorize_(m,:(l_j = l_j), p) == :(localV[nnic2_,1]=localV[nnic2_,1])
    @test AgentBasedModels.vectorize_(m,:(g = g), p) == :(globalV[1]=globalV[1])
    @test AgentBasedModels.vectorize_(m,:(h[1,2] = h[1,2]), p) == :(h[1,2]=h[1,2])
    @test AgentBasedModels.vectorize_(m,:(id = id), p) == :(identityV[ic1_,2]=identityV[ic1_,2])
    @test AgentBasedModels.vectorize_(m,:(id_i = id_i), p) == :(identityV[ic1_,2]=identityV[ic1_,2])
    @test AgentBasedModels.vectorize_(m,:(id_j = id_j), p) == :(identityV[nnic2_,2]=identityV[nnic2_,2])
    
    @test begin
        m = @agent(
            cell,
            l::Local,
            g::Global,
            h::GlobalArray,
            id::Identity
        )
            
        prod([i in [:t,:N,:loc_,:glob_,:id_,:h] for i in AgentBasedModels.agentArguments_(m)])
    end

    @test AgentBasedModels.cudaAdapt_(:(sin(e^2^x))) == :(CUDA.sin(CUDA.pow(e,CUDA.pow(2,x))))
    @test AgentBasedModels.cudaAdapt_(:(zeros(e^2))) == :(CUDA.zeros(CUDA.pow(e,2)))
    
    @test begin
        code = :(x .+= 1)
        f = AgentBasedModels.wrapInFunction_(:func,code)
        f = AgentBasedModels.subs_(f,:ARGS_,:x)
        eval(quote
            $f
            y = ones(10)
            func(y) 
            y == 2*ones(10)
        end)
    end 

    @test begin
        code = :(x[ic1_] += 1)
        code = AgentBasedModels.simpleFirstLoop_("cpu",code)
        f = AgentBasedModels.wrapInFunction_(:func,code)
        f = AgentBasedModels.subsArguments_(f,:ARGS_,[:x,:N])
        eval(quote
            $f
            N = 10
            y = ones(N)
            func(y,N) 
            y == 2*ones(N)
        end)        
    end

    @test begin
        code = :(x[ic1_] += 1)
        f = AgentBasedModels.simpleFirstLoopWrapInFunction_("cpu",:func,code)
        f = AgentBasedModels.subsArguments_(f,:ARGS_,[:x,:N])
        eval(quote
            $f
            N = 10
            y = ones(N)
            func(y,N) 
            y == 2*ones(N)
        end)        
    end

    if CUDA.has_cuda()
        @test begin
            code = :(x[ic1_] += 1)
            code = AgentBasedModels.simpleFirstLoop_("gpu",code)
            f = AgentBasedModels.wrapInFunction_(:func,code)
            f = AgentBasedModels.subsArguments_(f,:ARGS_,[:x,:N])
            eval(quote
                $f
                N = 10
                y = CUDA.ones(N)
                CUDA.@cuda func(y,N) 
                Array(y) == 2*ones(N)
            end)        
        end

        @test begin
            code = :(x[ic1_] += 1)
            f = AgentBasedModels.simpleFirstLoopWrapInFunction_("gpu", :func, code)
            f = AgentBasedModels.subsArguments_(f,:ARGS_,[:x,:N])
            eval(quote
                $f
                N = 10
                y = CUDA.ones(N)
                CUDA.@cuda func(y,N) 
                Array(y) == 2*ones(N)
            end)        
        end
    end

    @test begin

        m = DataFrame(Symbol=Symbol[], updated=Bool[], assigned=Bool[], referenced=Bool[], called=Bool[], placeDeclaration=Symbol[], type=Symbol[])
        push!(m,(:l,false,true,false,false,:Model,:Local))
        push!(m,(:g,true,false,true,false,:Model,:GlobalArray))
        push!(m,(:h_j,true,false,false,false,:Model,:Localj))
        push!(m,(:+,false,false,false,true,:Math,:None))
        push!(m,(:l_i,false,false,false,false,:Model,:Locali))
        push!(m,(:g,false,false,false,false,:Model,:GlobalArray))
        push!(m,(:u,false,false,false,true,:NotDefined,:None))

        #println(m)

        abm = @agent cell [l,h]::Local g::GlobalArray

        m2 = AgentBasedModels.symbols_(abm,
            quote
                l = 5
                g[1,2] -= 7
                h_j += l_i+g+u(1)
            end
        )
        
        #println(m2)

        m == m2
    end

    @test_nowarn begin
        
        abm = @agent(
            cell,

            [l1,l2]::Local,
            [g1,g2]::Global,
            [id1,id2]::Identity,
            [ga1,ga2]::GlobalArray,

            UpdateLocal = 
            begin
                l1 += 1
                l2 = 3
                id1 = 1
            end,

            Equation =
            begin
                d_l1 = a*dt + b*dW
            end,

            UpdateGlobal = 
            begin
                g1 += 1
                ga1[1,2] += 1
            end
        )

        p = AgentBasedModels.Program_(); s= SimulationFree()

        AgentBasedModels.updates_!(p,abm,s)

        if p.update["Identity"] != Dict(:id1=>1) error() end
        if p.update["Global"] != Dict(:g1=>1) error() end
        if p.update["GlobalArray"] != Dict(:ga1=>1) error() end
        if p.update["Local"] != Dict(:l2=>2,:l1=>1) error() end
        if p.update["Variables"] != Dict(:l1=>1) error() end
    end    

end