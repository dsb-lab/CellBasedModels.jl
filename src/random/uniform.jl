struct UniformRandVar<:RandomVar
    min::AbstractFloat
    max::AbstractFloat
end

function Uniform1CUDA_!(a,min,max,pos)
    index_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
    stride_ = blockDim().x * gridDim().x
    for i in index_:stride_:1
        a[pos] = a[pos]*(max-min)+min;
    end
    
    return nothing
end

function Uniform2CUDA_!(a,min,max,pos,N_)
    index_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
    stride_ = blockDim().x * gridDim().x
    for i in index_:stride_:N_
        a[i,pos] = a[i,pos]*(max-min)+min;
    end
    
    return nothing
end

function Uniform3CUDA_!(a,min,max,pos,N_,nnMax_)
    index_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
    stride_ = blockDim().x * gridDim().x
    for i in index_:stride_:N_
        for j in 1:nnMax_
            a[i,j,pos] = a[i,j,pos]*(max-min)+min;
        end
    end
    
    return nothing
end

function Uniform1_!(a,min,max,pos)

    a[pos] = a[pos]*(max-min)+min;
    
    return nothing
end

function Uniform2_!(a,min,max,pos,N_)

    Threads.@threads for i in 1:N_
        a[i,pos] = a[i,pos]*(max-min)+min;
    end
    
    return nothing
end

function Uniform3_!(a,min,max,pos,N_,nnMax_)

    Threads.@threads for i in 1:N_
        for j in 1:nnMax_
            a[i,j,pos] = a[i,j,pos]*(max-min)+min;
        end
    end
    
    return nothing
end
