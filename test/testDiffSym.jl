using CellBasedModels
using CUDA
using Atomix: @atomic

macro f_sym(g)
    :(2*$(esc(g)))
end

macro f_sym_tuple(x)
    :((2*$(esc(x)), 3*$(esc(x))))
end

function kernel(out)
    x = 2.0; y = 4.0
    @diffsym begin
        
        a = x ^ 2
        b = y ^ 2

        c = a + b

    end derivatives=(dc_dx = (c, x),)

    out[1] = dc_dx

    return
end

@testset verbose = verbose "Auxiliar - DiffSym" begin
    
    # Basic test
    x = 2
    y = 4
    p = (p1=1,)

    @diffsym begin
        
        a = x ^ 2
        b = y ^ 2

        c = a + b

    end derivatives=(dc_dx = (c, x), dc_dy = (c, y))

    @test dc_dx == 2 * x
    @test dc_dy == 2 * y

    # Basic test
    x = 2
    y = 4
    p = (p1=1,)

    @diffsym begin
        
        a = x ^ 2
        b = y ^ 2

        c = a + b

    end derivatives=(dc_dx = (c, x))

    @test dc_dx == 2 * x

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

    # Test with subfields
    x = 2
    y = 2
    p = (p1=1,)
    @diffsym begin
        
        a = x ^ 2
        b = y ^ 2

        c = a * b * p.p1

    end derivatives=(dc_dp1 = (c, p.p1),)

    @test dc_dp1 == x^2 * y ^2

    # Test with external macro
    x = 2
    y = 2
    p = (p1=1,)
    @diffsym begin
            
            a = x ^ 2
            b = y ^ 2

            z = @f_sym(x)

            c = a + b * p.p1

    end derivatives=(dc_dp1 = (c, p.p1), dz_dx = (z, x))
    
    @test dc_dp1 == y^2  # dc/dp.p1 = b = y^2
    @test dz_dx == 2

    # Test with tuple
    x = 2
    y = 2
    p = (p1=1,)
    @diffsym begin
            
            a = x ^ 2
            b = y ^ 2

            z, z2 = @f_sym_tuple(x)

            c = a + b * p.p1

    end derivatives=(dc_dp1 = (c, p.p1), dz_dx = (z, x), dz2_dx = (z2, x))

    # Test with kernel
    if CUDA.has_cuda()

        out = CUDA.zeros(1)
        CUDA.@cuda kernel(out)
        @test Array(out)[1] == 2*x
    
    end

end