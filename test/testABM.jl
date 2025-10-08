@testset verbose=verbose "ABM - CommunityABM" begin

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
            ),

            rules = (
                rule_env = quote

                    communityNew.environment.temperature[1] += 0.1
                
                end,
            ),
        )

        @test model.environment.temperature._updated == true

        @test typeof(model) === ABM{3, (:environment,), Tuple{AgentGlobal{(:temperature, :pressure, :note), Tuple{Float64, Float64, Bool}},}}
        @test haskey(model._agents, :environment)
        @test typeof(model._agents.environment) === AgentGlobal{(:temperature, :pressure, :note), Tuple{Float64, Float64, Bool}}

        community = CommunityABM(
            model;            
            environment = 
                CommunityGlobal(
                    model.environment;
                )
        )

        CellBasedModels.CustomFunctions.rule_env(community)
        model._functions.rule_env(community)

        @test community.environment.temperature[1] == 0.0
        @test community._parametersNew.environment.temperature[1] == 0.2

        update!(community)

        @test community.environment.temperature[1] == 0.2
        @test community._parametersNew.environment.temperature[1] == 0.2

    end

end