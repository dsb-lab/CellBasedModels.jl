@testset "CustomStructs" begin

    @testset "ValueUnits" begin
        vu = ValueUnits(42, :m)
        @test vu.value == 42
        @test vu.units == :m

        # Display formatting
        io = IOBuffer()
        show(io, vu)
        str = String(take!(io))
        @test occursin("42m", str)

        vu = ValueUnits(42, :(m/s^2))
        @test vu.value == 42
        @test vu.units == :(m/s^2)
    end

    @testset "Parameter" begin
        # 1. Using only ValueUnits
        p1 = Parameter(:mass, Float64, defaultValue=ValueUnits(3.14, :kg), description="Mass")
        @test p1.defaultValue.value == 3.14
        @test p1.defaultValue.units == :kg

        # 2. Using raw value and letting it wrap
        p2 = Parameter(:velocity, Float64, defaultValue=12.0)
        @test p2.defaultValue.value == 12.0
        @test p2.defaultValue.units === nothing

        # 3. Error if defaultValue doesn't match dataType
        @test_throws InexactError Parameter(:count, Int, defaultValue=3.14)
    end

    @testset "Agent" begin
        # Using a Vector{Parameter}
        p1 = Parameter(:mass, Float64, defaultValue=10.0)
        p2 = Parameter(:alive, Bool, defaultValue=true)
        agent_vec = Agent(:A1, parameters=[p1, p2])
        @test agent_vec.parameters[:mass].defaultValue.value == 10.0
        @test agent_vec.parameters[:alive].defaultValue.value == true

        # Using NamedTuple
        nt = (mass=p1, alive=p2)
        agent_nt = Agent(:A2, parameters=nt)
        @test agent_nt.parameters[:alive] === p2

        # Using OrderedDict
        od = OrderedDict(:mass => p1, :alive => p2)
        agent_od = Agent(:A3, parameters=od)
        @test agent_od.parameters[:mass] === p1

        # Using Dict
        d = Dict(:mass => p1, :alive => p2)
        agent_d = Agent(:A4, parameters=d)
        @test agent_d.parameters[:alive] === p2

        # Show representation
        io = IOBuffer()
        show(io, agent_vec)
        output = String(take!(io))
        @test occursin("mass", output)
        @test occursin("alive", output)
    end

end
