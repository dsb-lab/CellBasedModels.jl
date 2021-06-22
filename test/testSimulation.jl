@testset "free simulation" begin

    @test hasmethod(AgentBasedModels.arguments_!,(AgentBasedModels.Program_,Agent,SimulationFree,String))
    @test hasmethod(AgentBasedModels.loop_,(AgentBasedModels.Program_,Agent,SimulationFree,Expr,String))

    @test AgentBasedModels.arguments_!(AgentBasedModels.Program_(),@agent(cell),SimulationFree(),"gpu") == Nothing
    
    @test_nowarn begin
        
        m = @agent(
            cell,

            [l1,l2]::Local,
            [i1,i2]::Identity,

            UpdateLocalInteraction = begin
                if sqrt((l1₂-l1₁)^2+(l2₂-l2₁)^2) < 5
                    l1 += 1
                end
            end
        )
        
        s = SimulationFree()

        m = compile(m,s)
    end

    m = @agent(
        cell,

        [l1,l2,intLocal,int]::Local,
        [i1,i2]::Identity,

        Equation = begin
            nothing
        end,

        UpdateInteraction = begin
            if sqrt((l1₂-l1₁)^2+(l2₂-l2₁)^2) < 5
                int += 1
            end
        end,

        UpdateLocalInteraction = begin
            if sqrt((l1₂-l1₁)^2+(l2₂-l2₁)^2) < 5
                intLocal += 1
            end
        end
    )
    s = SimulationFree()
    m = compile(m,s)

    @test_nowarn begin
        com = Community(m,N=4)
        com.l1 = [1,1,0,0]
        com.l2 = [0,1,1,0]

        comt = m.evolve(com,dt=0.1,tMax=1)
        comt[1].int == [4,4,4,4] 
    end    

    @test_nowarn begin
        com = Community(m,N=4)
        com.l1 = [1,1,0,0]
        com.l2 = [0,1,1,0]

        comt = m.evolve(com,dt=0.1,tMax=1)
        comt[1].intLocal == [4,4,4,4] 
    end    

    @test_nowarn begin
        com = Community(m,N=4)
        com.l1 = [7,7,0,0]
        com.l2 = [0,7,7,0]

        comt = m.evolve(com,dt=0.1,tMax=1)
        comt[1].int == [1,1,1,1] 
    end    

    @test_nowarn begin
        com = Community(m,N=4)
        com.l1 = [7,7,0,0]
        com.l2 = [0,7,7,0]

        comt = m.evolve(com,dt=0.1,tMax=1)
        comt[1].intLocal == [1,1,1,1] 
    end    

    # @test begin     
    #     code = :(global g += v[nnic2_])
    #     loop = AgentBasedModels.loop_(@agent(cell),SimulationFree(),code,"cpu")
    #     eval(
    #         quote
    #             i2_ = 0
    #             N = 40
    #             v = ones(Int,N)
    #             g = 0
    #             $loop
    #         end
    #         )
    #     g == 40*40
    # end
end

@testset "grid simulation" begin

    @test hasmethod(SimulationGrid,(Agent, Array{<:Union{<:Tuple{Symbol,<:Real,<:Real},<:FlatBoundary},1}, Union{<:Real,Array{<:Real,1}}))
    @test hasmethod(AgentBasedModels.arguments_!,(AgentBasedModels.Program_, Agent, SimulationGrid, String))
    @test hasmethod(AgentBasedModels.loop_,(AgentBasedModels.Program_, Agent, SimulationGrid, Expr, String))

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

    @test begin
        xx = []
        for x in -2.:1.:2.
            push!(xx,AgentBasedModels.position2gridVectorPosition_(x,-1.5,1.,5))
        end 
        xx == Array(1:5)
    end

    @test begin        
        xx = []
        for y in -3.:1.:3.
            for x in -2.:1.:2.
                push!(xx,AgentBasedModels.position2gridVectorPosition_(x,-1.5,1.,5,y,-2.5,1.,7))
            end 
        end 
        xx == Array(1:5*7)
    end

    @test begin
        xx = []
        for z in -4.:1.:4.
            for y in -3.:1.:3.
                for x in -2.:1.:2.
                    push!(xx,AgentBasedModels.position2gridVectorPosition_(x,-1.5,1.,5,y,-2.5,1.,7,z,-3.5,1.,9))
                end 
            end 
        end
        xx == Array(1:5*7*9)
    end

    @test begin
        xx = []
        for x in 1:3
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour(1,x,5,false))
        end 
        xx == [-1,1,2]
    end

    @test begin
        xx = []
        for x in 1:3
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour(2,x,5,false))
        end 
        xx == [1,2,3]
    end

    @test begin
        xx = []
        for x in 1:3
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour(1,x,5,true))
        end 
        xx == [5,1,2]
    end

    @test begin
        xx = []
        for x in 1:3
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour(5,x,5,true))
        end 
        xx == [4,5,1]
    end

    @test begin
        xx = []
        for x in 1:9
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour(1,x,5,false,7,false))
        end 
        xx == [-1,-1,-1,-1,1,2,-1,6,7]
    end

    @test begin
        xx = []
        for x in 1:9
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour(7,x,5,false,7,false))
        end 
        xx == [1,2,3,6,7,8,11,12,13]
    end

    @test begin
        xx = []
        for x in 1:9
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour(25,x,5,false,5,false))
        end 
        xx == [19,20,-1,24,25,-1,-1,-1,-1]
    end

    @test begin
        xx = []
        for x in 1:9
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour(1,x,5,true,7,false))
        end 
        xx == [-1,-1,-1,5,1,2,10,6,7]
    end

    @test begin
        xx = []
        for x in 1:9
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour(5,x,5,true,7,false))
        end 
        xx == [-1,-1,-1,4,5,1,9,10,6]
    end

    @test begin
        xx = []
        for x in 1:9
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour(1,x,5,false,7,true))
        end 
        xx == [-1,31,32,-1,1,2,-1,6,7]
    end

    @test begin
        xx = []
        for x in 1:9
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour(25,x,5,true,5,true))
        end 
        xx == [19,20,16,24,25,21,4,5,1]
    end

    # @test_nowarn AgentBasedModels.arguments_!(AgentBasedModels.Program_(),m,nn,"cpu")

    # m = @agent(
    #     cell,

    #     [l1,l2,intLocal,int]::Local,
    #     [i1,i2]::Identity,

    #     Equation = begin
    #         nothing
    #     end,

    #     # UpdateInteraction = begin
    #     #     if sqrt((l1₂-l1₁)^2+(l2₂-l2₁)^2) < 5
    #     #         int += 1
    #     #     end
    #     # end,

    #     UpdateLocalInteraction = begin
    #         if sqrt((l1₂-l1₁)^2+(l2₂-l2₁)^2) < 5
    #             intLocal += 1
    #         end
    #     end,

    # )
    # s = SimulationGrid(m,[(:l1,-20,20)],[1.])
    # m = compile(m,s)
    # println(m.program)

    #  @test_nowarn begin
    #      com = Community(m,N=5)
    #      com.l1 .= [-20,10,0,10,20]
    #      com.l2 .= 0

    #      comt = m.evolve(com,dt=0.1,tMax=1)
    #      comt[1].int == [4,4,4,4] 
    # end        

    # @test_nowarn begin
    #     com = Community(m,N=4)
    #     com.l1 = [1,1,0,0]
    #     com.l2 = [0,1,1,0]

    #     comt = m.evolve(com,dt=0.1,tMax=1)
    #     comt[1].int = [4,4,4,4] 
    # end    

    # @test_nowarn begin
    #     com = Community(m,N=4)
    #     com.l1 = [1,1,0,0]
    #     com.l2 = [0,1,1,0]

    #     comt = m.evolve(com,dt=0.1,tMax=1)
    #     comt[1].intLocal = [4,4,4,4] 
    # end    

    # @test_nowarn begin
    #     com = Community(m,N=4)
    #     com.l1 = [7,7,0,0]
    #     com.l2 = [0,7,7,0]

    #     comt = m.evolve(com,dt=0.1,tMax=1)
    #     comt[1].int = [1,1,1,1] 
    # end    

    # @test_nowarn begin
    #     com = Community(m,N=4)
    #     com.l1 = [7,7,0,0]
    #     com.l2 = [0,7,7,0]

    #     comt = m.evolve(com,dt=0.1,tMax=1)
    #     comt[1].intLocal = [1,1,1,1] 
    # end    

    # m = @agent cell [x]::Local   
    # nn = SimulationGrid(m,[(:x,0.,10.)],.5)
    # p = AgentBasedModels.Program_()
    # AgentBasedModels.arguments_!(m,nn,p,"cpu")
    # append!(p.args,AgentBasedModels.agentArguments_(m))
    # unique!(p.args)
    # p.declareF=AgentBasedModels.subsArguments_(p.declareF,:ARGS_,p.args)
    # p.declareF=AgentBasedModels.vectorize_(m,p.declareF)

    # eval(
    #     quote
    #         loc_ = []
    #         for i in 0:11
    #             for j in 1:i
    #                 push!(loc_, i - 0.5)
    #             end
    #         end
    #         loc_=reshape(loc_,(:,1))
    #         N = size(loc_)[1]; nMax = N; t = 0; dt = 0;
    #         $(p.declareVar)
    #         $(p.declareF)
    #         computeNN_($(p.args...))
    #     end
    # )
    # @test nnGId_ == loc_.+1.5
    # @test nnVId_ == reshape(loc_.+1.5,(:))
    # @test nnGC_ == [i for i in 0:11]
    # @test nnGCCum_ == cumsum(0:11)
    # @test nnGCAux_ == nnGC_.+1

    # m = @agent cell [x,y,z]::Local   
    # nn = SimulationGrid(m,[(:x,0.,1.),(:y,0.,2.),(:z,0.,3.)],.5)
    # p = AgentBasedModels.Program_()
    # AgentBasedModels.arguments_!(m,nn,p,"cpu")
    # append!(p.args,AgentBasedModels.agentArguments_(m))
    # unique!(p.args)
    # p.declareF=AgentBasedModels.subsArguments_(p.declareF,:ARGS_,p.args)
    # p.declareF=AgentBasedModels.vectorize_(m,p.declareF)
    # eval(
    #     quote
    #         m = [[i,j,k] for i in -1:1 for j in -1:2 for k in -1:3]
    #         loc_ = zeros(3*4*5,3)
    #         for (j,i) in enumerate(m) 
    #             loc_[j,:] .= i .+ .5
    #         end

    #         N = size(loc_)[1]
    #         nMax = N
    #         t = 0; dt = 0.
    #         $(p.declareVar)
    #         $(p.declareF)
    #         computeNN_($(p.args...))
    #     end
    # )
    # @test prod([i in nnVId_ for i in cumsum(ones(N))])
    # @test nnGC_ == ones(N)
    # @test nnGCCum_ == cumsum(ones(Int,N))
    # @test prod([i in nnId_ for i in cumsum(ones(N))])
    # @test nnGCAux_ == 2*ones(N)

    # if CUDA.has_cuda()

    #     @test_nowarn AgentBasedModels.arguments_!(@agent(cell),nn,AgentBasedModels.Program_(),"gpu")

    #     m = @agent cell [x]::Local   
    #     nn = SimulationGrid(m,[(:x,0.,10.)],.5)
    #     p = AgentBasedModels.Program_()
    #     AgentBasedModels.arguments_!(m,nn,p,"gpu")
    #     append!(p.args,AgentBasedModels.agentArguments_(m))
    #     unique!(p.args)
    #     p.declareF=AgentBasedModels.subsArguments_(p.declareF,:ARGS_,p.args)
    #     p.declareF=AgentBasedModels.vectorize_(m,p.declareF)

    #     code = 
    #         quote
    #             loc_ = Vector{Float32}([])
    #             for i in 0:11
    #                 for j in 1:i
    #                     push!(loc_, i - 0.5)
    #                 end
    #             end
    #             loc_=reshape(loc_,(:,1))
    #             loc_=CUDA.CuArray(loc_)
    #             N = size(loc_)[1]; nMax = N; t = 0.;
    #             $(p.declareVar)
    #             $(p.declareF)
    #             computeNN_($(p.args...))
    #         end
    #     code = AgentBasedModels.cudaAdapt_(code)
    #     eval(code)
    #     @test Array(nnGId_) == Array(loc_.+1.5)
    #     @test Array(nnVId_) == reshape(Array(loc_.+1.5),(:))
    #     @test Array(nnGC_) == [i for i in 0:11]
    #     @test Array(nnGCCum_) == cumsum(0:11)
    #     @test Array(nnGCAux_) == Array(nnGC_.+1)

    #     m = @agent cell [x,y,z]::Local   
    #     nn = SimulationGrid(m,[(:x,0.,1.),(:y,0.,2.),(:z,0.,3.)],.5)
    #     p = AgentBasedModels.Program_()
    #     AgentBasedModels.arguments_!(m,nn,p,"gpu")
    #     append!(p.args,AgentBasedModels.agentArguments_(m))
    #     unique!(p.args)
    #     p.declareF=AgentBasedModels.subsArguments_(p.declareF,:ARGS_,p.args)
    #     p.declareF=AgentBasedModels.vectorize_(m,p.declareF)

    #     code =
    #         quote
    #             m = [[i,j,k] for i in -1:1 for j in -1:2 for k in -1:3]
    #             loc_ = Base.zeros(Float32,3*4*5,3)
    #             for (j,i) in enumerate(m) 
    #                 loc_[j,:] .= i .+ .5
    #             end
    #             loc_ = CUDA.CuArray(loc_)

    #             N = size(loc_)[1]
    #             nMax = N
    #             t = 0
    #             $(p.declareVar)
    #             $(p.declareF)
    #             computeNN_($(p.args...))
    #         end
    #     code = AgentBasedModels.cudaAdapt_(code)
    #     eval(code)            
    #     @test prod([i in Array(nnVId_) for i in cumsum(ones(N))])
    #     @test Array(nnGC_) == ones(N)
    #     @test Array(nnGCCum_) == cumsum(ones(Int,N))
    #     @test prod([i in Array(nnId_) for i in cumsum(ones(N))])
    #     @test Array(nnGCAux_) == 2*ones(N)

    # end

end