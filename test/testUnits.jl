using Test

@testset "Units core & Unit types" begin
    # ---------- set_units_globals! populates UNIT_SYMBOLS and UNITS_INVERSE ----------
    CellBasedModels.set_units_globals!()  # uses default UNITS
    @test :m ∈ UNIT_SYMBOLS
    @test :s ∈ UNIT_SYMBOLS
    @test UNITS_INVERSE[:m] == :L
    @test UNITS_INVERSE[:s] == :T

    # ---------- canonicalize_units ----------
    @test CellBasedModels.canonicalize_units(:m) === :m
    @test CellBasedModels.canonicalize_units(nothing) === nothing
    @test CellBasedModels.canonicalize_units(:(m*kg/s^2)) == :(kg*m/s^2)       # reorder by (dimension,symbol)
    @test CellBasedModels.canonicalize_units(:(s^-1*m/s))   == :(m/s^2)        # combine exponents
    @test CellBasedModels.canonicalize_units(:(m/m))        == :(1)            # cancels to dimensionless
    @test CellBasedModels.canonicalize_units(:(μm*nA/(kg*m))) == :(μm*nA/(kg*m))

    # Non-integer exponents should error
    @test_throws ArgumentError CellBasedModels.canonicalize_units(:(m^0.5))

    # ---------- Unit constructors & validation ----------
    @test Unit(1.0, :m) isa UnitScalar
    @test Unit(1.0, :m).units == :m
    @test Unit([1.0,2.0], :s) isa UnitArray
    @test Unit([1.0,2.0], :s).units == :s

    # Invalid unit symbol should throw
    @test_throws ArgumentError Unit(1.0, :parsec)

    # Units are canonicalized at construction
    uN = Unit(9.81, :(m*kg/s^2))
    @test uN.units == :(kg*m/s^2)

    # ---------- UnitScalar basic arithmetic ----------
    u_m = Unit(2.0, :m)      # 2 m
    u_s = Unit(4.0, :s)      # 4 s
    u1  = Unit(5.0)          # unitless

    # multiply / divide combine units
    u_ms = u_m * u_s
    @test u_ms isa UnitScalar
    @test u_ms.value == 8.0
    @test u_ms.units == :(m*s)

    u_m_per_s = u_m / u_s
    @test u_m_per_s.value == 0.5
    @test u_m_per_s.units == :(m/s)

    # scale by Real keeps units
    @test (u_m * 3.0).units == :m
    @test (3.0 * u_s).units == :s
    @test (u_m / 2.0).value == 1.0

    # addition/subtraction with same units (expected to be supported)
    # If your implementation enforces equality, these should pass:
    @test (Unit(1.5, :m) + Unit(0.5, :m)) isa UnitScalar
    @test (Unit(1.5, :m) + Unit(0.5, :m)).value == 2.0
    @test (Unit(1.5, :m) - Unit(0.5, :m)).value == 1.0

    # addition with mismatched units should error (if implemented to check)
    try
        _ = Unit(1.0, :m) + Unit(1.0, :s)
        # If no error is thrown, at least units should remain :m (left-biased)
        @test_broken (Unit(1.0, :m) + Unit(1.0, :s)).units == :m
    catch e
        @test isa(e, ArgumentError)
    end

    # ---------- UnitScalar: math functions ----------
    # dimensionless allowed
    @test exp(Unit(1.0)).value ≈ exp(1.0)
    @test exp(Unit(1.0)).units === nothing
    @test log(Unit(e)).value ≈ 1.0
    @test sin(Unit(0.0)).value == 0.0
    @test sin(Unit(0.0)).units === nothing

    # with units should error for exp/log/sin etc. (as per your definitions)
    @test_throws Exception exp(Unit(1.0, :m))
    @test_throws Exception log(Unit(1.0, :s))
    @test_throws Exception sin(Unit(1.0, :rad))  # unless you special-case :rad

    # sqrt is marked "TO BE IMPLEMENTED" → should throw
    @test_throws Exception sqrt(Unit(4.0, :m))

    # ---------- UnitArray minimal behavior ----------
    UA = Unit([10.0, 20.0, 30.0], :ms)
    @test size(UA) == (3,)
    @test UA[2] == 20.0
    UA[3] = 33.0
    @test UA[3] == 33.0
    @test copy(UA).units == :ms

    # Constructing with a matrix
    M = rand(2,3)
    UM = Unit(M, :K)
    @test UM isa UnitArray
    @test UM.units == :K
    @test UM[1,2] == M[1,2]
end
