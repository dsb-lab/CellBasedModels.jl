@testset "grid simulation" begin

    @test hasmethod(SimulationGrid,(Agent, Array{<:Union{<:Tuple{Symbol,<:Real,<:Real},<:FlatBoundary},1}, Union{<:Real,Array{<:Real,1}}))
    @test hasmethod(AgentBasedModels.arguments_!,(Agent,SimulationGrid,AgentBasedModels.Program_,String))
    @test hasmethod(AgentBasedModels.loop_,(Agent,SimulationFree,Expr,String))

    m = @agent cell [x,y,z,w]::Local;
    @test_throws ErrorException SimulationGrid(m,[(:x,2.,1.)],1)
    @test_throws ErrorException SimulationGrid(m,[(:g,1.,2.)],1)
    @test_throws ErrorException SimulationGrid(m,[(:x,1.,2.),(:x,1.,2.)],1)
    @test_throws ErrorException SimulationGrid(m,[(:x,1.,2.),(:y,1.,2.),(:z,1.,2.),(:w,1.,2.)],1)
    @test_throws ErrorException SimulationGrid(m,[(:x,1.,2.),(:y,1.,2.),(:z,1.,2.),(:w,1.,2.)],[1,2])

    @test_nowarn SimulationGrid(m,[(:x,0.,1.),(:y,0.,2.),(:z,0.,3.)],1)
    @test_nowarn SimulationGrid(m,[(:x,0.,1.),(:y,0.,2.),(:z,0.,3.)],[1.,2.,3.])
    @test_nowarn SimulationGrid(m,[Open(:x,0.,1.),Periodic(:y,0.,2.),HardReflecting(:z,0.,3.)],5.)

    nn = SimulationGrid(m,[(:x,0.,1.),(:y,0.,2.),(:z,0.,3.)],.5)
    @test nn.dim == 3
    @test nn.n == 3*4*5
    @test nn.axisSize == [3,4,5]
    @test nn.cumSize == [1,3,12] 

    @test_nowarn AgentBasedModels.arguments_!(m,nn,AgentBasedModels.Program_(),"cpu")

    m = @agent cell [x]::Local   
    nn = SimulationGrid(m,[(:x,0.,10.)],.5)
    p = AgentBasedModels.Program_()
    AgentBasedModels.arguments_!(m,nn,p,"cpu")
    append!(p.args,AgentBasedModels.agentArguments_(m))
    p.declareF=AgentBasedModels.subsArguments_(p.declareF,:ARGS_,p.args)
    p.declareF=AgentBasedModels.vectorize_(m,p.declareF)

    eval(
        quote
            loc_ = []
            for i in 0:11
                for j in 1:i
                    push!(loc_, i - 0.5)
                end
            end
            loc_=reshape(loc_,(:,1))
            N = size(loc_)[1]; nMax = N; t = 0;
            $(p.declareVar)
            $(p.declareF)
            computeNN_($(p.args...))
        end
    )
    @test nnGId_ == loc_.+1.5
    @test nnVId_ == reshape(loc_.+1.5,(:))
    @test nnGC_ == [i for i in 0:11]
    @test nnGCCum_ == cumsum(0:11)
    @test nnGCAux_ == nnGC_.+1

    m = @agent cell [x,y,z]::Local   
    nn = SimulationGrid(m,[(:x,0.,1.),(:y,0.,2.),(:z,0.,3.)],.5)
    p = AgentBasedModels.Program_()
    AgentBasedModels.arguments_!(m,nn,p,"cpu")
    append!(p.args,AgentBasedModels.agentArguments_(m))
    p.declareF=AgentBasedModels.subsArguments_(p.declareF,:ARGS_,p.args)
    p.declareF=AgentBasedModels.vectorize_(m,p.declareF)
    eval(
        quote
            m = [[i,j,k] for i in -1:1 for j in -1:2 for k in -1:3]
            loc_ = zeros(3*4*5,3)
            for (j,i) in enumerate(m) 
                loc_[j,:] .= i .+ .5
            end

            N = size(loc_)[1]
            nMax = N
            t = 0
            $(p.declareVar)
            $(p.declareF)
            computeNN_($(p.args...))
        end
    )
    @test prod([i in nnVId_ for i in cumsum(ones(N))])
    @test nnGC_ == ones(N)
    @test nnGCCum_ == cumsum(ones(Int,N))
    @test prod([i in nnId_ for i in cumsum(ones(N))])
    @test nnGCAux_ == 2*ones(N)

    if CUDA.has_cuda()

        @test_nowarn AgentBasedModels.arguments_!(@agent(cell),nn,AgentBasedModels.Program_(),"gpu")

        m = @agent cell [x]::Local   
        nn = SimulationGrid(m,[(:x,0.,10.)],.5)
        p = AgentBasedModels.Program_()
        AgentBasedModels.arguments_!(m,nn,p,"gpu")
        append!(p.args,AgentBasedModels.agentArguments_(m))
        p.declareF=AgentBasedModels.subsArguments_(p.declareF,:ARGS_,p.args)
        p.declareF=AgentBasedModels.vectorize_(m,p.declareF)

        code = 
            quote
                loc_ = Array{Float64,1}()
                for i in 0:11
                    for j in 1:i
                        push!(loc_, i - 0.5)
                    end
                end
                loc_=reshape(loc_,(:,1))
                loc_=CUDA.CuArray(loc_)
                N = size(loc_)[1]; nMax = N; t = 0;
                $(p.declareVar)
                $(p.declareF)
                computeNN_($(p.args...))
            end
        code = AgentBasedModels.cudaAdapt_(code)
        eval(code)
        @test Array(nnGId_) == Array(loc_.+1.5)
        @test Array(nnVId_) == reshape(Array(loc_.+1.5),(:))
        @test Array(nnGC_) == [i for i in 0:11]
        @test Array(nnGCCum_) == cumsum(0:11)
        @test Array(nnGCAux_) == Array(nnGC_.+1)

        m = @agent cell [x,y,z]::Local   
        nn = SimulationGrid(m,[(:x,0.,1.),(:y,0.,2.),(:z,0.,3.)],.5)
        p = AgentBasedModels.Program_()
        AgentBasedModels.arguments_!(m,nn,p,"gpu")
        append!(p.args,AgentBasedModels.agentArguments_(m))
        p.declareF=AgentBasedModels.subsArguments_(p.declareF,:ARGS_,p.args)
        p.declareF=AgentBasedModels.vectorize_(m,p.declareF)

        code =
            quote
                m = [[i,j,k] for i in -1:1 for j in -1:2 for k in -1:3]
                loc_ = zeros(Float32,3*4*5,3); loc_ = Array(loc_)
                for (j,i) in enumerate(m) 
                    loc_[j,:] .= i .+ .5
                end
                loc_ = CUDA.CuArray(loc_)

                N = size(loc_)[1]
                nMax = N
                t = 0
                $(p.declareVar)
                $(p.declareF)
                computeNN_($(p.args...))
            end
        code = AgentBasedModels.cudaAdapt_(code)
        eval(code)            
        @test prod([i in Array(nnVId_) for i in cumsum(ones(N))])
        @test Array(nnGC_) == ones(N)
        @test Array(nnGCCum_) == cumsum(ones(Int,N))
        @test prod([i in Array(nnId_) for i in cumsum(ones(N))])
        @test Array(nnGCAux_) == 2*ones(N)

    end



end