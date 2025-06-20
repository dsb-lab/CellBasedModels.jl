@testset "CustomStructs" begin

    @testset "ValueUnits" begin
        vu = ValueUnits(42, :m) # Value with units
        @test vu.value == 42
        @test vu.units == :m

        vu = ValueUnits(42, :(m/s^2)) # Value with complex units
        @test vu.value == 42
        @test vu.units == :(m/s^2)
        
        vu = ValueUnits(42) # Value without units
        @test vu.value == 42
        @test vu.units === nothing
    end

    @testset "Parameter" begin
        p = Parameter(:velocity, Float64) # Minimum definition
        @test p.name == :velocity
        @test p.dataType == Float64
        @test p.defaultValue.value === nothing
        @test p.defaultValue.units === nothing
        @test p.description == ""

        p = Parameter(:velocity, Float64, defaultValue=12.0, description="Velocity of the agent")
        @test p.name == :velocity
        @test p.dataType == Float64
        @test p.defaultValue.value == 12.0
        @test p.defaultValue.units === nothing
        @test p.description == "Velocity of the agent"

        p = Parameter(:velocity, Float64, defaultValue=ValueUnits(12.0, :kg), description="Velocity of the agent")
        @test p.name == :velocity
        @test p.dataType == Float64
        @test p.defaultValue.value == 12.0
        @test p.defaultValue.units == :kg
        @test p.description == "Velocity of the agent"

        @test_throws ArgumentError Parameter(:invalid, String, defaultValue=ValueUnits(12.0, :kg), description="Invalid type")
    end

    @testset "Agent" begin
        for agent in [
            Agent(:cell, parameters=(mass=Float64, alive=Bool)),
            Agent(:cell, parameters=OrderedDict(:mass => Float64, :alive => Bool)),
            Agent(:cell, parameters=Dict(:mass => Float64, :alive => Bool)),
            Agent(:cell, 
                            parameters=[
                                Parameter(:mass, Float64),
                                Parameter(:alive, Bool)
                            ])
            ]

            @test agent.name == :cell        
            @test agent.parameters.mass.dataType == Float64
            @test agent.parameters.mass.defaultValue.value === nothing
            @test agent.parameters.mass.defaultValue.units === nothing
            @test agent.parameters.mass.description == ""
            @test agent.parameters.alive.dataType == Bool
            @test agent.parameters.alive.defaultValue.value === nothing
            @test agent.parameters.alive.defaultValue.units === nothing
            @test agent.parameters.alive.description == ""
        end
    end

    @testset "GlobalEnvironment" begin
        for agent in [
            GlobalEnvironment(parameters=(mass=Float64, alive=Bool)),
            GlobalEnvironment(parameters=OrderedDict(:mass => Float64, :alive => Bool)),
            GlobalEnvironment(parameters=Dict(:mass => Float64, :alive => Bool)),
            GlobalEnvironment(parameters=[
                                Parameter(:mass, Float64),
                                Parameter(:alive, Bool)
                            ])
            ]

            @test agent.parameters.mass.dataType == Float64
            @test agent.parameters.mass.defaultValue.value === nothing
            @test agent.parameters.mass.defaultValue.units === nothing
            @test agent.parameters.mass.description == ""
            @test agent.parameters.alive.dataType == Bool
            @test agent.parameters.alive.defaultValue.value === nothing
            @test agent.parameters.alive.defaultValue.units === nothing
            @test agent.parameters.alive.description == ""
        end
    end

    @testset "Medium" begin
        for agent in [
            Medium(:cell, parameters=(mass=Float64, alive=Bool)),
            Medium(:cell, parameters=OrderedDict(:mass => Float64, :alive => Bool)),
            Medium(:cell, parameters=Dict(:mass => Float64, :alive => Bool)),
            Medium(:cell, 
                            parameters=[
                                Parameter(:mass, Float64),
                                Parameter(:alive, Bool)
                            ])
            ]

            @test agent.name == :cell        
            @test agent.parameters.mass.dataType == Float64
            @test agent.parameters.mass.defaultValue.value === nothing
            @test agent.parameters.mass.defaultValue.units === nothing
            @test agent.parameters.mass.description == ""
            @test agent.parameters.alive.dataType == Bool
            @test agent.parameters.alive.defaultValue.value === nothing
            @test agent.parameters.alive.defaultValue.units === nothing
            @test agent.parameters.alive.description == ""
        end
    end

    @testset "Interaction" begin
        for interaction in [
                Interaction(:interaction, :agent1, parameters=(mass=Float64, alive=Bool)), # Using NamedTuple        
                Interaction(:interaction, (:agent1, :agent1), parameters=(mass=Float64, alive=Bool)), # Using NamedTuple
                Interaction(:interaction, :agent1, parameters=OrderedDict(:mass => Float64, :alive => Bool)), # Using OrderedDict
                Interaction(:interaction, (:agent1, :agent1), parameters=OrderedDict(:mass => Float64, :alive => Bool)), # Using OrderedDict
                Interaction(:interaction, :agent1, parameters=Dict(:mass => Float64, :alive => Bool)), # Using Dict
                Interaction(:interaction, (:agent1, :agent1), parameters=Dict(:mass => Float64, :alive => Bool)), # Using Dict
                Interaction(:interaction, :agent1, 
                            parameters=[
                                Parameter(:mass, Float64, defaultValue=nothing),
                                Parameter(:alive, Bool, defaultValue=nothing)
                            ]), # Using Vector{Parameter}
                Interaction(:interaction, (:agent1, :agent1), 
                            parameters=[
                                Parameter(:mass, Float64, defaultValue=nothing),
                                Parameter(:alive, Bool, defaultValue=nothing)
                            ]) # Using Vector{Parameter}
            ]

                @test interaction.name == :interaction
                @test interaction.interactionAgents == (:agent1, :agent1)
                @test interaction.parameters.mass.dataType == Float64
                @test interaction.parameters.mass.defaultValue.value == nothing
                @test interaction.parameters.mass.defaultValue.units === nothing
                @test interaction.parameters.mass.description == ""
                @test interaction.parameters.alive.dataType == Bool
                @test interaction.parameters.alive.defaultValue.value === nothing
                @test interaction.parameters.alive.defaultValue.units === nothing
                @test interaction.parameters.alive.description == ""
        end
    end

end
