using CellBasedModels
using CUDA
using ForwardDiff

f_auto(x) = x^2

@testset verbose = verbose "Auxiliar - DiffAuto" begin
    
    x = 2
    y = 4
    p = (p1=1,)

    @diffauto begin
        
        a = x ^ 2
        b = f_auto(y)

        c = a + b

    end derivatives=(dc_dx = (c, x), dc_dy = (c, y))

    @test dc_dx == 2 * x
    @test dc_dy == 2 * y

    @diffauto begin
        
        a = x ^ 2
        b = y ^ 2

        c = a * b * p.p1

    end derivatives=(dc_dp1 = (c, p.p1),)

    @test dc_dp1 == x^2 * y ^2

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