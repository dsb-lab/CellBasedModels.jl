push!(LOAD_PATH,"../docs/src/")
push!(LOAD_PATH,"./src")

using Documenter, AgentBasedModels

makedocs(sitename="AgentBasedModel.jl",
pages = [
    "Home" => "index.md",
    "Usage.md",
    "Examples"=>[
        "Examples.md",
        "Examples.md"
    ],
    "API.md",
    "APIdevelopers.md"
],
format = Documenter.HTML(prettyurls = false)
)

deploydocs(
    repo = "github.com/dsb-lab/AgentBasedModels.jl",
)
