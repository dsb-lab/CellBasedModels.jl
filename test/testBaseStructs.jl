@testset "BaseStructs" begin

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
        @test p.units === nothing
        @test p.defaultValue.value === nothing
        @test p.defaultValue.units === nothing
        @test p.description == ""

        p = Parameter(:velocity, Float64, units=:(L/T)) # Minimum definition
        @test p.name == :velocity
        @test p.dataType == Float64
        @test p.units == :(L/T)
        @test p.defaultValue.value === nothing
        @test p.defaultValue.units === nothing
        @test p.description == ""

        p = Parameter(:velocity, Float64, defaultValue=12.0, description="Velocity of the agent")
        @test p.name == :velocity
        @test p.dataType == Float64
        @test p.defaultValue.value == 12.0
        @test p.defaultValue.units === nothing
        @test p.description == "Velocity of the agent"

        p = Parameter(:velocity, Float64, units=:(L/T), defaultValue=ValueUnits(12.0, :(m/s)), description="Velocity of the agent")
        @test p.name == :velocity
        @test p.dataType == Float64
        @test p.units == :(L/T)
        @test p.defaultValue.value == 12.0
        @test p.defaultValue.units == :(m/s)
        @test p.description == "Velocity of the agent"

        @test_throws ArgumentError Parameter(:invalid, String, defaultValue=ValueUnits(12.0, :kg), description="Invalid type")
    end

    @testset "Agent" begin
        for agent in [
            Agent(3, name=:cell, parameters=(mass=Float64, alive=Bool)),
            Agent(3, name=:cell, parameters=OrderedDict(:mass => Float64, :alive => Bool)),
            Agent(3, name=:cell, parameters=Dict(:mass => Float64, :alive => Bool)),
            Agent(3, name=:cell, 
                            parameters=[
                                Parameter(:mass, Float64),
                                Parameter(:alive, Bool)
                            ])
            ]

            @test agent.name == :cell        
            @test agent.dims == 3
            @test agent.parameters.x.dataType == Float64
            @test agent.parameters.x.defaultValue.value === nothing
            @test agent.parameters.x.defaultValue.units === nothing
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

    @testset "Model" begin
        for Model in [
            Model(parameters=(mass=Float64, alive=Bool)),
            Model(parameters=OrderedDict(:mass => Float64, :alive => Bool)),
            Model(parameters=Dict(:mass => Float64, :alive => Bool)),
            Model(parameters=[
                                Parameter(:mass, Float64),
                                Parameter(:alive, Bool)
                            ])
            ]

            @test Model.parameters.mass.dataType == Float64
            @test Model.parameters.mass.defaultValue.value === nothing
            @test Model.parameters.mass.defaultValue.units === nothing
            @test Model.parameters.mass.description == ""
            @test Model.parameters.alive.dataType == Bool
            @test Model.parameters.alive.defaultValue.value === nothing
            @test Model.parameters.alive.defaultValue.units === nothing
            @test Model.parameters.alive.description == ""
        end
    end

    @testset "Medium" begin
        for medium in [
            Medium(3, name=:medium, parameters=(mass=Float64, alive=Bool)),
            Medium(3, name=:medium, parameters=OrderedDict(:mass => Float64, :alive => Bool)),
            Medium(3, name=:medium, parameters=Dict(:mass => Float64, :alive => Bool)),
            Medium(3, name=:medium, 
                            parameters=[
                                Parameter(:mass, Float64),
                                Parameter(:alive, Bool)
                            ])
            ]

            @test medium.name == :medium        
            @test medium.parameters.mass.dataType == Float64
            @test medium.parameters.mass.defaultValue.value === nothing
            @test medium.parameters.mass.defaultValue.units === nothing
            @test medium.parameters.mass.description == ""
            @test medium.parameters.alive.dataType == Bool
            @test medium.parameters.alive.defaultValue.value === nothing
            @test medium.parameters.alive.defaultValue.units === nothing
            @test medium.parameters.alive.description == ""
        end
    end

    @testset "Interaction" begin
        for interaction in [
                Interaction(:agent1, parameters=(mass=Float64, alive=Bool)), # Using NamedTuple        
                Interaction((:agent1, :agent1), parameters=(mass=Float64, alive=Bool)), # Using NamedTuple
                Interaction(:agent1, parameters=OrderedDict(:mass => Float64, :alive => Bool)), # Using OrderedDict
                Interaction((:agent1, :agent1), parameters=OrderedDict(:mass => Float64, :alive => Bool)), # Using OrderedDict
                Interaction(:agent1, parameters=Dict(:mass => Float64, :alive => Bool)), # Using Dict
                Interaction((:agent1, :agent1), parameters=Dict(:mass => Float64, :alive => Bool)), # Using Dict
                Interaction(:agent1, 
                            parameters=[
                                Parameter(:mass, Float64, defaultValue=nothing),
                                Parameter(:alive, Bool, defaultValue=nothing)
                            ]), # Using Vector{Parameter}
                Interaction((:agent1, :agent1), 
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
