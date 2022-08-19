@testset "auxiliar" begin

    m = @agent 2 [x1,y1]::Local
    # @test_nowarn AgentBasedModels.checkIsDeclared_(m,:x1) 
    # @test_nowarn AgentBasedModels.checkIsDeclared_(m,[:x1]) 
    # @test_nowarn AgentBasedModels.checkIsDeclared_(m,[:x1,:y1]) 
    # @test_throws ErrorException AgentBasedModels.checkIsDeclared_(m,:g) 
    # @test_throws ErrorException AgentBasedModels.checkIsDeclared_(m,[:g]) 
    # @test_throws ErrorException AgentBasedModels.checkIsDeclared_(m,[:x1,:g]) 

    # @test AgentBasedModels.subs_(:(x += 3*x),:x,:y) == :(y += 3*y)
    # @test AgentBasedModels.subs_(:(x += 3*x),:x,:y,update=true) == :(y += 3*x)

    m = @agent(
        0,
        l::Local,
        g::Global,
        h::GlobalArray
    )
    p = AgentBasedModels.AgentCompiled(m);
    AgentBasedModels.updates_!(p)
    @test AgentBasedModels.vectorize_(m,:(l = 1), p) == :(localV[ic1_,1]=1)
    @test AgentBasedModels.vectorize_(m,:(l.i = 1), p) == :(localV[ic1_,1]=1)
    @test AgentBasedModels.vectorize_(m,:(l.j = 1), p) == :(localV[nnic2_,1]=1)
    @test AgentBasedModels.vectorize_(m,:(g = 1), p) == :(globalV[1]=1)
    @test AgentBasedModels.vectorize_(m,:(h[1,2] = 1), p) == :(h[1,2]=1)
    @test AgentBasedModels.vectorize_(m,:(id = 1), p) == :(identityV[ic1_,1]=1)
    @test AgentBasedModels.vectorize_(m,:(id.i = 1), p) == :(identityV[ic1_,1]=1)
    @test AgentBasedModels.vectorize_(m,:(id.j = 1), p) == :(identityV[nnic2_,1]=1)

    @test AgentBasedModels.vectorize_(m,:(l = l), p) == :(localV[ic1_,1]=localV[ic1_,1])
    @test AgentBasedModels.vectorize_(m,:(l.i = l.i), p) == :(localV[ic1_,1]=localV[ic1_,1])
    @test AgentBasedModels.vectorize_(m,:(l.j = l.j), p) == :(localV[nnic2_,1]=localV[nnic2_,1])
    @test AgentBasedModels.vectorize_(m,:(g = g), p) == :(globalV[1]=globalV[1])
    @test AgentBasedModels.vectorize_(m,:(h[1,2] = h[1,2]), p) == :(h[1,2]=h[1,2])
    @test AgentBasedModels.vectorize_(m,:(id = id), p) == :(identityV[ic1_,1]=identityV[ic1_,1])
    @test AgentBasedModels.vectorize_(m,:(id.i = id.i), p) == :(identityV[ic1_,1]=identityV[ic1_,1])
    @test AgentBasedModels.vectorize_(m,:(id.j = id.j), p) == :(identityV[nnic2_,1]=identityV[nnic2_,1])

    @test AgentBasedModels.cudaAdapt_(:(sin(e^2^x))) == :(CUDA.sin(Float32(e)^Float32(2)^x))
    @test AgentBasedModels.cudaAdapt_(:(zeros(e^2))) == :(CUDA.zeros(e^2))
    
    # @test begin
    #     code = :(x .+= 1)
    #     f = AgentBasedModels.wrapInFunction_(:func,code)
    #     f = AgentBasedModels.subs_(f,:ARGS_,:x)
    #     eval(quote
    #         $f
    #         y = ones(10)
    #         func(y) 
    #         y == 2*ones(10)
    #     end)
    # end 

    # @test begin
    #     code = :(x[ic1_] += 1)
    #     code = AgentBasedModels.simpleFirstLoop_("cpu",code)
    #     f = AgentBasedModels.wrapInFunction_(:func,code)
    #     f = AgentBasedModels.subsArguments_(f,:ARGS_,[:x,:N])
    #     eval(quote
    #         $f
    #         N = 10
    #         y = ones(N)
    #         func(y,N) 
    #         y == 2*ones(N)
    #     end)        
    # end

    # @test begin
    #     code = :(x[ic1_] += 1)
    #     f = AgentBasedModels.simpleFirstLoopWrapInFunction_("cpu",:func,code)
    #     f = AgentBasedModels.subsArguments_(f,:ARGS_,[:x,:N])
    #     eval(quote
    #         $f
    #         N = 10
    #         y = ones(N)
    #         func(y,N) 
    #         y == 2*ones(N)
    #     end)        
    # end

    # if CUDA.has_cuda()
    #     @test begin
    #         code = :(x[ic1_] += 1)
    #         code = AgentBasedModels.simpleFirstLoop_("gpu",code)
    #         f = AgentBasedModels.wrapInFunction_(:func,code)
    #         f = AgentBasedModels.subsArguments_(f,:ARGS_,[:x,:N])
    #         eval(quote
    #             $f
    #             N = 10
    #             y = CUDA.ones(N)
    #             CUDA.@cuda func(y,N) 
    #             Array(y) == 2*ones(N)
    #         end)        
    #     end

    #     @test begin
    #         code = :(x[ic1_] += 1)
    #         f = AgentBasedModels.simpleFirstLoopWrapInFunction_("gpu", :func, code)
    #         f = AgentBasedModels.subsArguments_(f,:ARGS_,[:x,:N])
    #         eval(quote
    #             $f
    #             N = 10
    #             y = CUDA.ones(N)
    #             CUDA.@cuda func(y,N) 
    #             Array(y) == 2*ones(N)
    #         end)        
    #     end
    # end

    @test_nowarn begin
        
        abm = @agent(
            1,

            [l1,l2]::Local,
            [g1,g2]::Global,
            [id1,id2]::Identity,
            [ga1,ga2]::GlobalArray,

            UpdateLocal = 
            begin
                l1.new += 1
                l2.new = 3
                id1.new = 1
            end,

            UpdateVariable =
            begin
                d(x) = a*dt + b*dW
            end,

            UpdateGlobal = 
            begin
                g1.new += 1
                g2.new = 0
                ga1[1,2].new += 1
            end
        )
        p = AgentBasedModels.AgentCompiled(abm); 

        AgentBasedModels.updates_!(p)

        if p.update["Identity"] != Dict(:id1=>1) error() end
        if p.update["Global"] != Dict(:g1=>1,:g2=>2) error() end
        if p.update["GlobalArray"] != Dict(:ga1=>1) error() end
        if p.update["Local"] != Dict(:l2=>3,:l1=>2,:x=>1) error() end
        if p.update["Variables"] != Dict(:x=>1) error() end
    end    

    # @test AgentBasedModels.extract(:(f(x)*1+4),:f) == (:x)

end