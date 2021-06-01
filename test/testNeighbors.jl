@testset "neighbors" begin

    #Test Neighbors full
    @test hasmethod(AgentBasedModels.arguments_,(NeighborsFull,String))
    @test hasmethod(AgentBasedModels.loop_,(NeighborsFull,Expr))

    @test AgentBasedModels.arguments_(NeighborsFull(),"gpu") == (Nothing,Nothing,Nothing,Nothing,Nothing,Nothing,Nothing)
    
    code = :(global g += v[nnic2_])
    loop = AgentBasedModels.loop_(NeighborsFull(),code)
    eval(
        quote
            i2_ = 0
            N = 40
            v = ones(Int,N)
            g = 0
            $loop
        end
        )
    @test g == 40

    #Test Neighbors Grid
    @test hasmethod(AgentBasedModels.arguments_,(NeighborsGrid,String))
    @test hasmethod(AgentBasedModels.loop_,(NeighborsGrid,Expr))

    m = @agent cell [x,y,z,w]::Local
    @test_throws MethodError NeighborsGrid(m,())
    @test_throws MethodError NeighborsGrid(m,[(:x,1.,2.,3.,4.)])
    @test_throws MethodError NeighborsGrid(m,[(:x,1.,2.)])
    @test_throws ErrorException NeighborsGrid(m,[(:x,2.,1.,3.)])
    @test_throws ErrorException NeighborsGrid(m,[(:g,1.,2.,3.)])
    @test_throws ErrorException NeighborsGrid(m,[(:x,1.,2.,3.),(:x,1.,2.,3.)])
    @test_throws ErrorException NeighborsGrid(m,[(:x,1.,2.,3.),(:y,1.,2.,3.),(:z,1.,2.,3.),(:w,1.,2.,3.)])
    
    @test_nowarn NeighborsGrid(m,[(:x,0.,1.,.5),(:y,0.,2.,.5),(:z,0.,3.,.5)])
    @test_nowarn NeighborsGrid(m,[(:x,0.,1.),(:y,0.,2.),(:z,0.,3.)],.5)

    nn = NeighborsGrid(m,[(:x,0.,1.,.5),(:y,0.,2.,.5),(:z,0.,3.,.5)])
    @test nn.dim == 3
    @test nn.n == 3*4*5
    @test nn.axisSize == [3,4,5]
    @test nn.cumSize == [1,3,12] 

    @test_nowarn AgentBasedModels.arguments_(nn,"cpu")

    m = @agent cell [x]::Local   
    nn = NeighborsGrid(m,[(:x,0.,10.,.5)])
    declareVar, declareF, args, argsEval, execInit, execInloop, execAfter = AgentBasedModels.arguments_(nn,"cpu")
    append!(args,AgentBasedModels.agentArguments_(m))
    declareF=AgentBasedModels.subsArguments_(declareF,:ARGS_,args)
    declareF=AgentBasedModels.vectorize_(m,declareF)
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
            $(declareVar...)
            $declareF
            computeNN_($(args...))
        end
    )
    @test nnGId_ == loc_.+1.5
    @test nnVId_ == reshape(loc_.+1.5,(:))
    @test nnGC_ == [i for i in 0:11]
    @test nnGCCum_ == cumsum(0:11)
    @test nnGCAux_ == nnGC_.+1

    """m = @agent cell [x,y,z]::Local   
    nn = NeighborsGrid(m,[(:x,0.,1.,.5),(:y,0.,2.,.5),(:z,0.,3.,.5)])
    declareVar, declareF, args, argsEval, execInit, execInloop, execAfter = AgentBasedModels.arguments_(nn,"cpu")
    append!(args,AgentBasedModels.agentArguments_(m))
    declareF=AgentBasedModels.subsArguments_(declareF,:ARGS_,args)
    declareF=AgentBasedModels.vectorize_(m,declareF)
    eval(
        quote
            m = [[i,j,k] for i in -1:1 for j in -1:2 for k in -1:3]
            loc_ = zeros(length(3*4*5),3)
            for (j,i) in enumerate(m) 
                loc_[j,:] .= i .+ .5
            end

            N = size(loc_)[1]
            nMax = N
            t = 0
            $(declareVar...)
            $declareF
            computeNN_($(args...))
        end
    )
    @test [i in nnVId_ for i in cumsum(ones(N))] == [true for i in cumsum(ones(N))]
    @test nnGC_ == ones(N)
    @test nnGCCum_ == cumsum(ones(Int,N))
    @test [i in nnId_ for i in cumsum(ones(N))] == [true for i in cumsum(ones(N))]
    @test nnGCAux_ == 2*ones(N)"""

end