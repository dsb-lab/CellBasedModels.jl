using Pkg

packages = [
    "IJulia",
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

packages = [
    ("CellBasedModels","develop"),
]

for (package, version) in packages
    Pkg.add(Pkg.PackageSpec(name=package; rev=version))
    eval(string("using ",package))
end