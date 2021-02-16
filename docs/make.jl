push!(LOAD_PATH,"../docs/src/")
push!(LOAD_PATH,"./src")

using Documenter, AgentModel

makedocs(sitename="AgentModel.jl",
pages = [
    "Home" => "Intro.md",
    "First steps.md",
    "API.md",
    "APIdevelopers.md"
],
format = Documenter.HTML(prettyurls = false)
)