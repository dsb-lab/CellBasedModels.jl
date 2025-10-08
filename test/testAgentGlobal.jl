@testset verbose=verbose "structs - Global" begin

    @testset "AgentGlobal" begin
        props_nt = (
            temp = Parameter(Float64; dimensions = :K, defaultValue = 37.0, description = "temperature"),
            flag = Bool,
        )

        ag1 = AgentGlobal(properties = props_nt)

        @test typeof(ag1) === AgentGlobal{(:temp, :flag), Tuple{Float64,Bool}}
        @test haskey(ag1._properties, :temp)
        @test ag1.temp isa Parameter
        @test typeof(ag1.temp).parameters[1] === Float64
        @test ag1.temp.dimensions === :K
        @test ag1.temp.defaultValue == 37.0
        @test ag1.temp.description == "temperature"
        @test ag1.temp._scope === nothing

        @test haskey(ag1._properties, :flag)
        @test ag1.flag isa Parameter
        @test typeof(ag1.flag).parameters[1] === Bool
        @test ag1.flag.dimensions === nothing
        @test ag1.flag.defaultValue === nothing
        @test ag1.flag.description == ""
        @test ag1.flag._scope === nothing

        props_dict = Dict{Symbol,Any}(
            :iters => Parameter(Int; defaultValue = 10, description = "iteration count"),
            :dt    => Float64,
        )

        ag2 = AgentGlobal(properties = props_dict)

        @test typeof(ag2) === AgentGlobal{(:iters, :dt), Tuple{Int, Float64}}
        @test ag2.iters isa Parameter
        @test typeof(ag2.iters).parameters[1] === Int
        @test ag2.iters.defaultValue == 10
        @test ag2.iters.description == "iteration count"

        @test ag2.dt isa Parameter
        @test typeof(ag2.dt).parameters[1] === Float64

        bad = (
            good = Parameter(Float64),
            bad  = 12345,  # not a DataType or Parameter → should error
        )
        @test_throws ErrorException AgentGlobal(properties = bad)

    end

    @testset "CommunityGlobal" begin
        # Agent global properties: some are global-scoped, some flagged as updated/DE
        agent_props = (
            # global params
            temperature = Parameter(Float64; defaultValue=37.0, description="temp", _scope=:global, _updated=true),
            pressure    = Parameter(Float64; defaultValue=1.0,  description="press", _scope=:global, _DE=true),
            # non-global param (should NOT be auto-initialized if missing)
            note        = Parameter(Bool;  defaultValue=false, description="note",  _scope=:agent),
        )

        # Build AgentGlobal WITHOUT invoking parameterConvert (positional constructor)
        agent = AgentGlobal(properties = agent_props)

        # Provide only temperature in properties; pressure must be auto-created (zeros)
        env_in = (temperature = [37.0],)
        comm = CommunityGlobal(agent; properties = env_in)

        # Basic shape
        @test comm isa CommunityGlobal
        @test haskey(comm._properties, :temperature)
        @test haskey(comm._propertiesNew, :temperature)   
        @test !haskey(comm._propertiesDt, :temperature)      

        @test haskey(comm._properties, :pressure)
        @test !haskey(comm._propertiesNew, :pressure)        
        @test haskey(comm._propertiesDt, :pressure)       

        @test haskey(comm._properties, :note)                
        @test !haskey(comm._propertiesNew, :note)            
        @test !haskey(comm._propertiesDt, :note)             

        @test length(comm.temperature) == 1
        @test comm.temperature[1] == 37.0
        @test length(comm.pressure) == 1
        @test comm.pressure[1] == 0.0             
        @test length(comm.note) == 1
        @test comm.note[1] == false

        @test_throws BoundsError comm.temperature[2]  
        @test_throws ErrorException comm.foo             
        @test_throws MethodError comm.temperature = 1.  
        @test_nowarn comm.temperature .= true          
        @test_throws InexactError comm.note .= 2          
        @test_throws MethodError comm.note .= "2" 

        # Check getPropertiesAsNamedTuple utility
        props, propsNew, propsDt = CellBasedModels.getPropertiesAsNamedTuple(comm)
        @test keys(props) == (:note, :temperature, :pressure)
        @test keys(propsNew) == (:temperature,)
        @test keys(propsDt) == (:pressure,)

        # Error: non-scalar env property
        @test_throws ErrorException CommunityGlobal(agent; properties=(temperature = [37.0, 38.0],))

        # Error: unknown env property
        @test_throws ErrorException CommunityGlobal(agent; properties=(foo = [1.0],))

    end

end