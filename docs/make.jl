push!(LOAD_PATH,"../src/")
push!(LOAD_PATH,"/home/gabriel/Documents/PhD/3 Simulation/embryogenesisJulia/src/Interpreter/")

using Documenter, Interpreter

makedocs(sitename="EmbryogenensisJulia",
pages = [
    "Home" => "index.md",
    "createModels.md",
],
format = Documenter.HTML(prettyurls = false)
)