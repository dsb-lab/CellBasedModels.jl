@testset "auxiliar" begin

    m = @agent cell [x,y]::Local
    @test_nowarn AgentBasedModels.checkIsDeclared_(m,:x) 
    @test_nowarn AgentBasedModels.checkIsDeclared_(m,[:x]) 
    @test_nowarn AgentBasedModels.checkIsDeclared_(m,[:x,:y]) 
    @test_throws ErrorException AgentBasedModels.checkIsDeclared_(m,:g) 
    @test_throws ErrorException AgentBasedModels.checkIsDeclared_(m,[:g]) 
    @test_throws ErrorException AgentBasedModels.checkIsDeclared_(m,[:x,:g]) 

    m = @agent(
        cell,
        l::Local,
        v::Variable,
        i::Interaction,
        g::Global,
        h::GlobalArray,
        id::Identity
    )
    @test AgentBasedModels.vectorize_(m,:(l = 1)) == :(loc_[ic1_,1]=1)
    @test AgentBasedModels.vectorize_(m,:(l₁ = 1)) == :(loc_[ic1_,1]=1)
    @test AgentBasedModels.vectorize_(m,:(l₂ = 1)) == :(loc_[nnic2_,1]=1)
    @test AgentBasedModels.vectorize_(m,:(v = 1)) == :(var_[ic1_,1]=1)
    @test AgentBasedModels.vectorize_(m,:(v₁ = 1)) == :(var_[ic1_,1]=1)
    @test AgentBasedModels.vectorize_(m,:(v₂ = 1)) == :(var_[nnic2_,1]=1)
    @test AgentBasedModels.vectorize_(m,:(i = 1)) == :(inter_[ic1_,1]=1)
    @test AgentBasedModels.vectorize_(m,:(i₁ = 1)) == :(inter_[ic1_,1]=1)
    @test AgentBasedModels.vectorize_(m,:(i₂ = 1)) == :(inter_[nnic2_,1]=1)
    @test AgentBasedModels.vectorize_(m,:(g = 1)) == :(glob_[1]=1)
    @test AgentBasedModels.vectorize_(m,:(h[1,2] = 1)) == :(h[1,2]=1)
    @test AgentBasedModels.vectorize_(m,:(id = 1)) == :(id_[ic1_,1]=1)
    @test AgentBasedModels.vectorize_(m,:(id₁ = 1)) == :(id_[ic1_,1]=1)
    @test AgentBasedModels.vectorize_(m,:(id₂ = 1)) == :(id_[nnic2_,1]=1)
    
    @test begin
        m = @agent(
            cell,
            l::Local,
            v::Variable,
            i::Interaction,
            g::Global,
            h::GlobalArray,
            id::Identity
        )
            
        prod([i in [:t,:N,:var_,:loc_,:glob_,:inter_,:id_,:h] for i in AgentBasedModels.agentArguments_(m)])
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
end