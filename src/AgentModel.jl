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
include("./auxiliar/addIfNot.jl")
include("./auxiliar/checkDeclared.jl")
include("./auxiliar/commonArguments.jl")
include("./auxiliar/findSymbol.jl")
include("./auxiliar/adapt.jl")
include("./auxiliar/splitting.jl")
include("./auxiliar/substitution.jl")
include("./auxiliar/clean.jl")

#Random variables
include("./random/random.jl")
include("./random/randomAdapt.jl")
include("./random/normal.jl")
include("./random/uniform.jl")

#Model functions
include("./model/parameterAdapt.jl")
include("./model/basic/addGlobal.jl")
include("./model/basic/addLocal.jl")
include("./model/basic/addLocalInteraction.jl")
include("./model/basic/addVariable.jl")
include("./model/basic/addInteraction.jl")

#Neighborhoods
include("./model/neighborhoods/neighboursFull.jl")
include("./model/neighborhoods/neighboursByAdjacency.jl")
include("./model/neighborhoods/neighboursByGrid.jl")
include("./model/neighborhoods/neighbours.jl")
include("./model/neighborhoods/makeInLoop.jl")

#Special
include("./model/special/division.jl")
include("./model/special/pseudopodes.jl")
include("./model/special/special.jl")

#Integrators
include("./integrator/euler.jl")
include("./integrator/eulerIto.jl")
include("./integrator/integrators.jl")

#Saving
include("./saving/ram.jl")

#Compile
include("./compile/compile.jl")

end