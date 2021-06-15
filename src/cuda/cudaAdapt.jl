"""
    function cudaAdapt_(code)

Function that adapts vector declarations and math functions to CUDA.
"""
function cudaAdapt_(code::Expr)


    #Subs all math
    code = subs_(code,:(^),Meta.parse(string("CUDA.","pow"))) #Exception
    l = [i for i in names(Base.Math) if isdefined(CUDA,i) && i != :(^)]
    for i in l
        code = subs_(code,i,Meta.parse(string("CUDA.","$i")))
    end
    #Subs vectors
    for i in [:zeros,:ones]
        code = subs_(code,i,Meta.parse(string("CUDA.","$i")))
    end
    code = subs_(code,:Array,Meta.parse(string("CUDA.CuArray")))
    code = subs_(code,:Int,Meta.parse(string("Int32")))

    return code
end