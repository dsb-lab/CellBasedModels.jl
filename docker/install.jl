using Pkg

packages = [
    "IJulia",
    "CellBasedModels",
    "CSV",
    "DataFrames",
    "Plots",
    "Makie",
    "CairoMakie",
    "GLMakie",
    "CUDA",
    "Distributions",
    "DifferentialEquations",
]

for package in packages
    Pkg.add(package)
    eval(string("using ",package))
end