push!(LOAD_PATH,"../docs/src/")
push!(LOAD_PATH,"./src")

using Documenter, AgentBasedModels

makedocs(sitename="AgentBasedModel.jl",
pages = [
    "Home" => "index.md",
    "Usage" => [
        "Usage_intro.md",
        "Usage_Agent.md",
        "Usage_Community.md",
        "Usage_Fitting.md",
    ],
    "ImplementedModels.md",
    # "Examples" => [
    #     "ExampleDevelopment.md"
    # ], 
    # "ImplementedModels.md",
    "API.md",
    "APIdevelopers.md"
],
format = Documenter.HTML(prettyurls = false)
)

deploydocs(
    repo = "github.com/dsb-lab/AgentBasedModels.jl",
)
