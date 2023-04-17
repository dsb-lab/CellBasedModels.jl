push!(LOAD_PATH,"../docs/src/")
push!(LOAD_PATH,"./src")

using Documenter, CellBasedModels

makedocs(sitename="CellBasedModels.jl",
pages = [
    "Home" => "index.md",
    "Usage" => [
        "Usage_intro.md",
        "Usage_Agent.md",
        "Usage_Community.md",
        "Usage_Fitting.md",
    ],
    "Examples" => [
        "Patterning.md",
        "Development.md",
        "Aggregation.md",
        "Bacteries.md",
        "Chemotaxis.md"
    ], 
    "Models.md",
    "API.md",
    "APIdevelopers.md"
],
format = Documenter.HTML(prettyurls = false)
)

deploydocs(
    repo = "github.com/dsb-lab/CellBasedModels.jl",
)
