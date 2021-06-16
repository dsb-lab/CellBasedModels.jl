VALIDDISTRIBUTIONS = [i for i in names(Distributions) if uppercasefirst(string(i)) == string(i)]
VALIDDISTRIBUTIONSCUDA = [:Normal,:Uniform]

Normal_(x,μ,σ) = σ*x+μ
Uniform_(x,l0,l1) = (l1-l0)*x+l0