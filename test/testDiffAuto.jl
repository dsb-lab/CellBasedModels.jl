using CellBasedModels
using CUDA
using ForwardDiff

f_auto(x) = x^2

@testset verbose = verbose "Auxiliar - DiffAuto" begin
    
    # Test base
    x = 2
    y = 4
    p = (p1=1,)

    @diffauto begin
        
        a = x ^ 2
        b = f_auto(y)

        c = a + b

    end derivatives=(dc_dx = (c, x), dc_dy = (c, y))

    # Test with subfields
    @test dc_dx == 2 * x
    @test dc_dy == 2 * y

    # Test with control flow
    x = 2
    y = 4
    p = (p1=1,)

    @diffsym begin
        
        a = x ^ 2
        b = if y > 3
                y ^ 2
            else
                y
            end

        c = a + b

    end derivatives=(dc_dx = (c, x), dc_dy = (c, y))

    @test dc_dx == 2 * x
    @test dc_dy == 2 * y

    x = 2
    y = 2
    p = (p1=1,)

    @diffsym begin
        
        a = x ^ 2
        b = if y > 3
                y ^ 2
            else
                y
            end

        c = a + b

    end derivatives=(dc_dx = (c, x), dc_dy = (c, y))

    @test dc_dx == 2 * x
    @test dc_dy == 1

    @diffauto begin
        
        a = x ^ 2
        b = y ^ 2

        c = a * b * p.p1

    end derivatives=(dc_dp1 = (c, p.p1),)

    @test dc_dp1 == x^2 * y ^2

    # Test with external function
    @test dc_dx == 2 * x
    @test dc_dy == 2 * y

    @diffauto begin
        
        a = x ^ 2
        b = y ^ 2

        f_auto(b)

        c = a * b * p.p1

    end derivatives=(dc_dp1 = (c, p.p1),)

    @test dc_dp1 == x^2 * y ^2

    # Test consistency with ForwardDiff
    x = 2
    y = 4
    p = (p1=1,)

    results = @consistency_diffauto begin
        
        a = x ^ 2
        b = f_auto(y)
        da_dx = 2*x

        c = a + b

        dc_dx = 2*x
        dc_dy = 2*y

    end derivatives=(dc_dx = (c, x), dc_dy = (c, y), da_dx = (a,x)) silent=true

    @test all(r -> r.difference < 1e-10, results)

end