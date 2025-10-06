@testset "Parameter: constructor & fields" begin
    # 1) DefaultValue numeric gets wrapped into ValueUnits
    p = Parameter(Float64; defaultValue=1.5, description="alpha")
    @test p.dataType === Float64
    @test p.dimensions === nothing
    @test p.defaultValue == 1.5
    @test p.description === "alpha"

    # 2) DefaultValue already ValueUnits stays as-is
    p2 = Parameter(Float64; dimensions=:L, defaultValue=42.0, description="len")
    @test p2.dimensions === :L
    @test p2.defaultValue === 42.0

    # 3) Bool and nothing as defaults
    p3 = Parameter(Bool; defaultValue=true)
    @test p3.dataType === Bool
    @test p3.defaultValue === true

    p4 = Parameter(Int; defaultValue=nothing)
    @test p4.dataType === Int
    @test p4.defaultValue === nothing
end

@testset "parameterConvert: dict → NamedTuple" begin
    # 1) Mixed dict: Parameter + DataType
    params = Dict(
        :velocity => Parameter(Float64; dimensions=:L, defaultValue=10.0, description="vel"),
        :temperature => Float64,
        :flag => Parameter(Bool; defaultValue=true)
    )
    nt = CellBasedModels.parameterConvert(params)
    @test nt isa NamedTuple
    @test haskey(nt, :velocity)
    @test haskey(nt, :temperature)
    @test haskey(nt, :flag)

    @test nt.velocity isa Parameter
    @test nt.temperature isa Parameter
    @test nt.flag isa Parameter

    # Auto-wrapped DataType
    @test nt.temperature.dataType === Float64

    # 2) Error on wrong types
    bad = Dict(:x => 123)  # not Parameter, not DataType
    @test_throws ErrorException CellBasedModels.parameterConvert(bad)

    # 3) Key order preserved as NamedTuple keys (Tuple(keys(dict)) order)
    # (Dicts are unordered; this test ensures function doesn't crash with arbitrary key orders)
    params2 = Dict(:a => Float64, :b => Parameter(Int))
    nt2 = CellBasedModels.parameterConvert(params2)
    @test (:a in keys(nt2)) && (:b in keys(nt2))
end
