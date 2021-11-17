"""
    function cudaAdapt_(code)

Function that adapts vector declarations and math functions to CUDA.
"""
function cudaAdapt_(code::Expr)

    #Subs all math
    l = [i for i in names(Base.Math) if isdefined(CUDA,i) && i != :(^)]
    for i in l
        code = subs_(code,i,Meta.parse(string("CUDA.","$i")))
    end
    #Subs power
    code = postwalk(x->@capture(x, a_^b_) && typeof(b) != Int ? :(Float32($a)^$b) : x, code)

    #Subs vectors
    for i in [:zeros,:ones]
        code = subs_(code,i,Meta.parse(string("CUDA.","$i")))
    end
    code = subs_(code,:Array,Meta.parse(string("CUDA.CuArray")))
    code = subs_(code,:Int,Meta.parse(string("Int32")))
    code = subs_(code,:Float64,Meta.parse(string("Float32")))

    return code
end