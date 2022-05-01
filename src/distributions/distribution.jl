VALIDDISTRIBUTIONS = [i for i in names(Distributions) if uppercasefirst(string(i)) == string(i)]
VALIDDISTRIBUTIONSCUDA = [:Normal,:Uniform,:Exponential]

#Random distribution transformations for cuda capabilities
NormalCUDA(x,μ,σ) = σ*CUDA.sqrt(2.)*SpecialFunctions.erfinv(2*(x-.5))+μ
UniformCUDA(x,l0,l1) = (l1-l0)*x+l0
ExponentialCUDA(x,θ) = -CUDA.log(1-x)*θ