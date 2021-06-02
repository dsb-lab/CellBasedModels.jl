@testset "free simulation" begin

    @test hasmethod(AgentBasedModels.arguments_!,(SimulationFree,AgentBasedModels.Program_,String))
    @test hasmethod(AgentBasedModels.loop_,(SimulationFree,Expr))

    @test AgentBasedModels.arguments_!(SimulationFree(),AgentBasedModels.Program_(),"gpu") == Nothing
    
    code = :(global g += v[nnic2_])
    loop = AgentBasedModels.loop_(SimulationFree(),code)
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
end

@testset "grid simulation" begin

    @test hasmethod(SimulationGrid,(Agent, Array{<:Union{<:Tuple{Symbol,<:Real,<:Real},<:FlatBoundary},1}, Union{<:Real,Array{<:Real,1}}))
    @test hasmethod(AgentBasedModels.arguments_!,(SimulationGrid,AgentBasedModels.Program_,String))
    @test hasmethod(AgentBasedModels.loop_,(SimulationGrid,Expr))

    m = @createAgent cell [x,y,z,w]::Local;
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

    @test_nowarn AgentBasedModels.arguments_!(nn,AgentBasedModels.Program_(),"cpu")

    m = @createAgent cell [x]::Local   
    nn = SimulationGrid(m,[(:x,0.,10.)],.5)
    p = AgentBasedModels.Program_()
    AgentBasedModels.arguments_!(nn,p,"cpu")
    append!(p.args,AgentBasedModels.agentArguments_(m))
    p.declareF[1]=AgentBasedModels.subsArguments_(p.declareF[1],:ARGS_,p.args)
    p.declareF[1]=AgentBasedModels.vectorize_(m,p.declareF[1])
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
            $(p.declareVar...)
            $(p.declareF[1])
            computeNN_($(p.args...))
        end
    )
    @test nnGId_ == loc_.+1.5
    @test nnVId_ == reshape(loc_.+1.5,(:))
    @test nnGC_ == [i for i in 0:11]
    @test nnGCCum_ == cumsum(0:11)
    @test nnGCAux_ == nnGC_.+1

    m = @createAgent cell [x,y,z]::Local   
    nn = SimulationGrid(m,[(:x,0.,1.),(:y,0.,2.),(:z,0.,3.)],.5)
    p = AgentBasedModels.Program_()
    AgentBasedModels.arguments_!(nn,p,"cpu")
    append!(p.args,AgentBasedModels.agentArguments_(m))
    p.declareF[1]=AgentBasedModels.subsArguments_(p.declareF[1],:ARGS_,p.args)
    p.declareF[1]=AgentBasedModels.vectorize_(m,p.declareF[1])
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
            $(p.declareVar...)
            $(p.declareF[1])
            computeNN_($(p.args...))
        end
    )
    @test prod([i in nnVId_ for i in cumsum(ones(N))])
    @test nnGC_ == ones(N)
    @test nnGCCum_ == cumsum(ones(Int,N))
    @test prod([i in nnId_ for i in cumsum(ones(N))])
    @test nnGCAux_ == 2*ones(N)


    @test_nowarn AgentBasedModels.arguments_!(nn,AgentBasedModels.Program_(),"gpu")

end