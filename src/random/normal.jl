struct NormalRandVar<:RandomVar
    μ::AbstractFloat
    σ::AbstractFloat
end

function Normal1CUDA_!(a,μ,σ,pos)
    index_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
    stride_ = blockDim().x * gridDim().x
    for i in index_:stride_:1
        x = 1.99999*a[pos]-0.999995
        p = 0
        w = -log((1.0 - x)*(1.0 + x))
 
        if(w < 0.5)
            w = w - 2.5;
            p = 2.81022636e-08;
            p = 3.43273939e-07 + p * w;
            p = -3.5233877e-06 + p * w;
            p = -4.39150654e-06 + p * w;
            p = 0.00021858087 + p * w;
            p = -0.00125372503 + p * w;
            p = -0.00417768164 + p * w;
            p = 0.246640727 + p * w;
            p = 1.50140941 + p * w;
        else
            w = sqrt(w) - 3.0;
            p = -0.000200214257;
            p = 0.000100950558 + p * w;
            p = 0.00134934322 + p * w;
            p = -0.00367342844 + p * w;
            p = 0.00573950773 + p * w;
            p = -0.0076224613 + p * w;
            p = 0.00943887047 + p * w;
            p = 1.00167406 + p * w;
            p = 2.83297682 + p * w;
        end
        
        a[pos] = p * x * σ * 1.395 + μ;
    end
    
    return nothing
end

function Normal2CUDA_!(a,μ,σ,pos,N_)
    index_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
    stride_ = blockDim().x * gridDim().x
    for i in index_:stride_:N_
        x = 1.99999*a[i,pos]-0.999995
        p = 0
        w = -log((1.0 - x)*(1.0 + x))
 
        if(w < 0.5)
            w = w - 2.5;
            p = 2.81022636e-08;
            p = 3.43273939e-07 + p * w;
            p = -3.5233877e-06 + p * w;
            p = -4.39150654e-06 + p * w;
            p = 0.00021858087 + p * w;
            p = -0.00125372503 + p * w;
            p = -0.00417768164 + p * w;
            p = 0.246640727 + p * w;
            p = 1.50140941 + p * w;
        else
            w = sqrt(w) - 3.0;
            p = -0.000200214257;
            p = 0.000100950558 + p * w;
            p = 0.00134934322 + p * w;
            p = -0.00367342844 + p * w;
            p = 0.00573950773 + p * w;
            p = -0.0076224613 + p * w;
            p = 0.00943887047 + p * w;
            p = 1.00167406 + p * w;
            p = 2.83297682 + p * w;
        end
        
        a[i,pos] = p * x * σ * 1.395 + μ;
    end
    
    return nothing
end

function Normal3CUDA_!(a,μ,σ,pos,N_,nnMax_)
    index_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
    stride_ = blockDim().x * gridDim().x
    for i in index_:stride_:N_
        for j in 1:nnMax_
            x = 1.99999*a[i,j,pos]-0.999995
            p = 0
            w = -log((1.0 - x)*(1.0 + x))

            if(w < 0.5)
                w = w - 2.5;
                p = 2.81022636e-08;
                p = 3.43273939e-07 + p * w;
                p = -3.5233877e-06 + p * w;
                p = -4.39150654e-06 + p * w;
                p = 0.00021858087 + p * w;
                p = -0.00125372503 + p * w;
                p = -0.00417768164 + p * w;
                p = 0.246640727 + p * w;
                p = 1.50140941 + p * w;
            else
                w = sqrt(w) - 3.0;
                p = -0.000200214257;
                p = 0.000100950558 + p * w;
                p = 0.00134934322 + p * w;
                p = -0.00367342844 + p * w;
                p = 0.00573950773 + p * w;
                p = -0.0076224613 + p * w;
                p = 0.00943887047 + p * w;
                p = 1.00167406 + p * w;
                p = 2.83297682 + p * w;
            end
        
            a[i,j,pos] = p * x * σ * 1.395 + μ;
            
        end
    end
    
    return nothing
end

function Normal1_!(a,μ,σ,pos)

    x = 1.99999*a[pos]-0.999995
    p = 0
    w = -log((1.0 - x)*(1.0 + x))
 
    if(w < 0.5)
        w = w - 2.5;
        p = 2.81022636e-08;
        p = 3.43273939e-07 + p * w;
        p = -3.5233877e-06 + p * w;
        p = -4.39150654e-06 + p * w;
        p = 0.00021858087 + p * w;
        p = -0.00125372503 + p * w;
        p = -0.00417768164 + p * w;
        p = 0.246640727 + p * w;
        p = 1.50140941 + p * w;
    else
        w = sqrt(w) - 3.0;
        p = -0.000200214257;
        p = 0.000100950558 + p * w;
        p = 0.00134934322 + p * w;
        p = -0.00367342844 + p * w;
        p = 0.00573950773 + p * w;
        p = -0.0076224613 + p * w;
        p = 0.00943887047 + p * w;
        p = 1.00167406 + p * w;
        p = 2.83297682 + p * w;
    end
        
    a[pos] = p * x * σ * 1.395 + μ;
    
    return nothing
end

function Normal2_!(a,μ,σ,pos,N_)

    Threads.@threads for i in 1:N_
        x = 1.99999*a[i,pos]-0.999995
        p = 0
        w = -log((1.0 - x)*(1.0 + x))
 
        if(w < 0.5)
            w = w - 2.5;
            p = 2.81022636e-08;
            p = 3.43273939e-07 + p * w;
            p = -3.5233877e-06 + p * w;
            p = -4.39150654e-06 + p * w;
            p = 0.00021858087 + p * w;
            p = -0.00125372503 + p * w;
            p = -0.00417768164 + p * w;
            p = 0.246640727 + p * w;
            p = 1.50140941 + p * w;
        else
            w = sqrt(w) - 3.0;
            p = -0.000200214257;
            p = 0.000100950558 + p * w;
            p = 0.00134934322 + p * w;
            p = -0.00367342844 + p * w;
            p = 0.00573950773 + p * w;
            p = -0.0076224613 + p * w;
            p = 0.00943887047 + p * w;
            p = 1.00167406 + p * w;
            p = 2.83297682 + p * w;
        end
        
        a[i,pos] = p * x * σ * 1.395 + μ;
    end
    
    return nothing
end

function Normal3_!(a,μ,σ,pos,N_,nnMax_)

    Threads.@threads for i in 1:N_
        for j in 1:nnMax_
            x = 1.99999*a[i,j,pos]-0.999995
            p = 0
            w = -log((1.0 - x)*(1.0 + x))

            if(w < 0.5)
                w = w - 2.5;
                p = 2.81022636e-08;
                p = 3.43273939e-07 + p * w;
                p = -3.5233877e-06 + p * w;
                p = -4.39150654e-06 + p * w;
                p = 0.00021858087 + p * w;
                p = -0.00125372503 + p * w;
                p = -0.00417768164 + p * w;
                p = 0.246640727 + p * w;
                p = 1.50140941 + p * w;
            else
                w = sqrt(w) - 3.0;
                p = -0.000200214257;
                p = 0.000100950558 + p * w;
                p = 0.00134934322 + p * w;
                p = -0.00367342844 + p * w;
                p = 0.00573950773 + p * w;
                p = -0.0076224613 + p * w;
                p = 0.00943887047 + p * w;
                p = 1.00167406 + p * w;
                p = 2.83297682 + p * w;
            end
        
            a[i,j,pos] = p * x * σ * 1.395 + μ;
            
        end
    end
    
    return nothing
end
