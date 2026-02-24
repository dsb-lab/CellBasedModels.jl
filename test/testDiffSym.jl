using CellBasedModels
using CUDA

f_sym(x) = 2*x

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

    @diffsym begin
        
        a = x ^ 2
        b = y ^ 2

        c = a * b * p.p1

    end derivatives=(dc_dp1 = (c, p.p1),)

    @test dc_dp1 == x^2 * y ^2

    @test_throws LoadError @eval begin
        @diffsym begin
            
            a = x ^ 2
            b = y ^ 2

            f_sym(x)

            c = a + b * p.p1

        end derivatives=(dc_dp1 = (c, p.p1),)
    end

    if CUDA.has_cuda()

        out = CUDA.zeros(1)
        CUDA.@cuda kernel(out)
        @test Array(out)[1] == 2*x
    
    end

end