"""
    function cudaAdapt_(code::Expr)

Function that adapts vector declarations and math functions to be executed in CUDA kernels.

# Args
 - **code::Expr**: Code to be adapted to cuda.

# Returns
 - `Expr` with adapted code.
"""
function cudaAdapt_(code::Expr)

    #Subs all math
    l = [i for i in names(Base.Math) if isdefined(CUDA,i) && i != :(^)]
    for i in l
        code = postwalk(x->@capture(x,g_) && g == i ? Meta.parse(string("CUDA.","$i")) : x, code)
    end
    #Subs power
    code = postwalk(x->@capture(x, a_^b_) && typeof(b) != Int ? :(Float32($a)^$b) : x, code)

    #Subs vectors
    for i in [:zeros,:ones]
        code = postwalk(x->@capture(x,g_) && g == i ? Meta.parse(string("CUDA.","$i")) : x, code)
    end
    code = postwalk(x->@capture(x,g_) && g == :Array ? :(CUDA.CuArray) : x, code)
    code = postwalk(x->@capture(x,g_) && g == INT ? :($INTCUDA) : x, code)
    code = postwalk(x->@capture(x,g_) && g == FLOAT ? :($FLOATCUDA) : x, code)

    return code
end