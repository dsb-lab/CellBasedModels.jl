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

function platformAdapt(agent::Agent,code::Expr)
    if agent.platform == "cpu"
        code = postwalk(x->@capture(x,@platformAdapt v_(ARGS__)) ? :($v($(ARGS...))) : x, code)
        code = postwalk(x->@capture(x,@platformAdapt1 v_(ARGS__)) ? :($v($(ARGS...))) : x, code)
        code = postwalk(x->@capture(x,@platformAdapt2 v_(ARGS__)) ? :($v($(ARGS...))) : x, code)
        code = postwalk(x->@capture(x,@platformAdapt3 v_(ARGS__)) ? :($v($(ARGS...))) : x, code)
    elseif agent.platform == "gpu"
        code = postwalk(x->@capture(x,@platformAdapt v_(ARGS__)) ? :(kernel_ = @cuda launch = false $v($(ARGS...)); 
                                                                    prop_ = AgentBasedModels.configurator_(kernel_,N); 
                                                                    kernel_($(ARGS...);threads=prop_[1],blocks=prop_[2])) : x, code)
        code = postwalk(x->@capture(x,@platformAdapt1 v_(ARGS__)) ? :(kernel_ = @cuda launch = false $v($(ARGS...)); 
                                                                    prop_ = AgentBasedModels.configurator_(kernel_,Nx_); 
                                                                    kernel_($(ARGS...);threads=prop_[1],blocks=prop_[2])) : x, code)
        code = postwalk(x->@capture(x,@platformAdapt2 v_(ARGS__)) ? :(kernel_ = @cuda launch = false $v($(ARGS...)); 
                                                                    prop_ = AgentBasedModels.configurator2_(kernel_,Nx_,Ny_); 
                                                                    kernel_($(ARGS...);threads=(prop_[1],prop_[2]),blocks=(prop_[3],prop_[4]))) : x, code)
        code = postwalk(x->@capture(x,@platformAdapt3 v_(ARGS__)) ? :(kernel_ = @cuda launch = false $v($(ARGS...)); 
                                                                    prop_ = AgentBasedModels.configurator3_(kernel_,Nx_,Ny_,Nz_); 
                                                                    kernel_($(ARGS...);threads=(prop_[1],prop_[2],prop_[3]),blocks=(prop_[4],prop_[5],prop_[6]))) : x, code)
        code = cudaAdapt_(code)
    end

    return code
end