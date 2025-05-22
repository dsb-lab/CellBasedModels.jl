module CBMDistributions

    """
        normal(μ,σ)

    Normal distribution radom generation. `μ` mean, `σ` std.
    """
    normal(μ,σ) = σ*randn()+μ

    """
        uniform(l0,l1)

    Uniform distribution radom generation. `l0` min, `l1` max.
    """
    uniform(l0,l1) = (l1-l0)*rand()+l0

    """
        exponential(θ)

    Exponential distribution radom generation. `θ` mean.
    """
    exponential(θ) = -log(1-rand())*θ

    """
        rand_pm()

    Randomly returns `1` or `-1` with equal probability (50%).  
    Useful for symmetric binary decision
    """
    rand_pm() = ifelse(rand() < 0.5, -1, 1)


end