@testset verbose=verbose "ABM - CommunityABM" begin

    # Test macros @new and @dt, and functions codeNew and codeDt
    @test CellBasedModels.codeNew(:t) == :_t_new
    @test CellBasedModels.codeNew(:(Scope1.t)) == :(Scope1._t_new)
    @test CellBasedModels.codeNew(:(Scope1.scope2.t)) == :(Scope1.scope2._t_new)
    @test CellBasedModels.codeNew(:(Scope1.scope2.scope3.t)) == :(Scope1.scope2.scope3._t_new)

    @test CellBasedModels.codeDt(:t) == :_t_dt
    @test CellBasedModels.codeDt(:(Scope1.t)) == :(Scope1._t_dt)
    @test CellBasedModels.codeDt(:(Scope1.scope2.t)) == :(Scope1.scope2._t_dt)
    @test CellBasedModels.codeDt(:(Scope1.scope2.scope3.t)) == :(Scope1.scope2.scope3._t_dt)

    @testset "struct - Global" begin

        # Build AgentGlobal WITHOUT invoking parameterConvert (positional constructor)
        environment = AgentGlobal(
                    properties=
                        (
                            temperature = Parameter(Float64; defaultValue=37.0, description="temp", _scope=:global, _updated=true),
                            pressure    = Parameter(Float64; defaultValue=1.0,  description="press", _scope=:global, _DE=true),
                            note        = Parameter(Bool;  defaultValue=false, description="note",  _scope=:agent),
                        )
                )

        model = ABM(
            3;
            
            agents = (
                environment = environment,
            )
        )

        @test typeof(model) === ABM{3, (:environment,), Tuple{AgentGlobal{(:temperature, :pressure, :note), Tuple{Float64, Float64, Bool}},}}
        @test haskey(model._agents, :environment)
        @test typeof(model._agents.environment) === AgentGlobal{(:temperature, :pressure, :note), Tuple{Float64, Float64, Bool}}

        @test_nowarn community = CommunityABM(
            model;            
            environment = 
                CommunityGlobal(
                    model.environment;
                )
        )

        

    end

end