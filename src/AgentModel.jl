module AgentModel

using CUDA
using DataFrames
using Random

export Community, Model

#Reserved variables of the model
include("./constants/constants.jl")
include("./constants/abstractStructures.jl")

#Structure
include("./model/model.jl")
include("./community/community.jl")
include("./community/baseModuleExtensions.jl")

#Auxiliar variables
include("./auxiliar/checkDeclared.jl")
include("./auxiliar/commonArguments.jl")
include("./auxiliar/findSymbol.jl")
include("./auxiliar/platformAdapt.jl")
include("./auxiliar/splitting.jl")
include("./auxiliar/substitution.jl")
include("./auxiliar/vectorize.jl")
include("./auxiliar/clean.jl")

#Random variables
include("./random/random.jl")
include("./random/randomAdapt.jl")
include("./random/normal.jl")
include("./random/uniform.jl")

#Model functions
include("./model/parameterAdapt.jl")
include("./model/addGlobal.jl")
include("./model/addLocal.jl")
include("./model/addLocalInteraction.jl")
include("./model/addVariable.jl")
include("./model/addInteraction.jl")

#Neighborhoods
include("./neighborhoods/neighboursFull.jl")
include("./neighborhoods/neighboursByAdjacency.jl")
include("./neighborhoods/neighboursByGrid.jl")
include("./neighborhoods/neighbours.jl")

#Special
include("./special/division.jl")

#Integrators
include("./integrator/euler.jl")
include("./integrator/eulerIto.jl")
include("./integrator/integrators.jl")

#Saving
include("./saving/ram.jl")

#Compile
include("./compile/compile.jl")

end