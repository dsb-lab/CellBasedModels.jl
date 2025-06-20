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


end
