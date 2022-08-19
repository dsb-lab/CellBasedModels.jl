@testset "agentCompiled" begin

    @test_nowarn begin
        agent = @agent(3,
        UpdateVariable=
        begin
            d(x) = 1+dW
            #addAgent(x=1.,y=2.,z=3.)
            #removeAgent()
            Uniform(0,1)
            x.new = 2
        end
        )
        agentCompiled = AgentCompiled(agent)
        f = AgentBasedModels.createFunction(
            quote
                d(x) = 1+dW
                #addAgent(x=1.,y=2.,z=3.)
                #removeAgent()
                Uniform(0,1)
                x.new = 2
            end,
            agentCompiled,
            orderInteraction=2
        )
        print(prettify(f))
    end

    # @test_nowarn begin
    #     m = @agent(
    #         1,
            
    #         l::Local,
    #         g::Global,
    #         ga::GlobalArray,
    #         m::Medium,
            
    #         UpdateVariable = d(v) = 34*dt ,
    #         UpdateLocal = l += 1,
    #         UpdateGlobal = begin
    #             g += Normal(1,2) + Normal(1,2) + Uniform(1,2) 
    #             ga[3,2] += 3
    #         end,
    #         UpdateInteraction = l.i += 1,
    #     )
    #     m = compile(m, platform="cpu",integrator="Euler",checkInBounds=true)
    #     print(prettify(m.program_integration_step))
    # end

end