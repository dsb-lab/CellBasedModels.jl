module CBMDistributions

    """
        NormalCUDA(x,μ,σ)

    Normal distribution adapted to CUDA.
    """
    normal(μ,σ) = σ*randn()+μ

    """
        UniformCUDA(x,l0,l1)

    Uniform distribution adapted to CUDA.
    """
    uniform(l0,l1) = (l1-l0)*rand()+l0

    """
        ExponentialCUDA(x,θ)

    Exponential distribution adapted to CUDA.
    """
    exponential(θ) = -log(1-rand())*θ

end