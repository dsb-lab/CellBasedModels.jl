using Test

@testset verbose=verbose "abstractTypes Integrators" begin

    # helper: make a few Exprs
    ex = quote f_i(u,p,t) end

    @testset "Rule" begin
        r1 = Rule(ex)
        @test r1 isa Rule
        @test r1.rules == (ex,)

        r3 = Rule(ex, ex, ex)
        @test r3 isa Rule
        @test r3.rules[2] === ex

        rkw = Rule(f = (ex, ex))
        @test rkw isa Rule
        @test rkw.rules == (ex, ex)

        @test_throws ErrorException Rule(1)  # non-Expr positional should error (your original API)
    end

    @testset "ODE" begin
        o1 = ODE(ex)
        @test o1 isa ODE
        @test o1.f == (ex,)

        okw = ODE(f = (ex, ex))
        @test okw isa ODE
        @test okw.f[2] === ex
    end

    @testset "DynamicalODE" begin
        d = DynamicalODE(f1 = ex, f2 = (ex, ex))
        @test d isa DynamicalODE
        @test d.f1 == (ex,)
        @test d.f2 == (ex, ex)
    end

    @testset "SplitODE" begin
        s = SplitODE(f1 = (ex, ex), f2 = ex)
        @test s isa SplitODE
        @test s.f1[1] === ex
        @test s.f2 == (ex,)
    end

    @testset "SDE" begin
        s1 = SDE(f = ex, g = (ex, ex))
        @test s1 isa SDE
        @test s1.f1 == (ex,)
        @test s1.f2 == (ex, ex)
    end

    @testset "RODE" begin
        r = RODE(ex, ex)
        @test r isa RODE
        @test r.f == (ex, ex)

        rkw = RODE(f = ex)
        @test rkw isa RODE
    end

    @testset "ADIODE (1/2/3 parts)" begin
        # 1-part + g
        a1 = ADIODE(f1 = ex, g = ex)
        @test typeof(a1) === ADIODE{1, true}
        @test a1.f1 == (ex,)
        @test a1.g  == (ex,)

        # no g provided -> empty g tuple
        a1b = ADIODE(f1 = (ex, ex))
        @test typeof(a1b) === ADIODE{1, false}
        @test a1b.g === nothing

        # 2-parts + g
        a2 = ADIODE(f1 = ex, f2 = (ex, ex), g = (ex, ex))
        @test typeof(a2) === ADIODE{2, true}
        @test a2.f2 == (ex, ex)
        @test a2.g  == (ex, ex)

        # 3-parts, empty g
        a3 = ADIODE(f1 = ex, f2 = ex, f3 = (ex, ex))
        @test typeof(a3) === ADIODE{3, false}
        @test a3.f3 == (ex, ex)
        @test a3.g  === nothing
    end

end
