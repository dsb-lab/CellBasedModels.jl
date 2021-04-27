module AgentBasedModels

using Random
using Distributions
using CUDA
using DataFrames
using CSV
#using WriteVTK

export Community, Model, CommunityInTime
export addGlobal!, addLocal!, addVariable!, addLocalInteraction!, addInteraction!, addIdentifier!
export addDivision!, addPseudopode!
export compile!
export plotCommunitySpheres

export save, save!, loadCommunity, loadTimeSeries
export latticeCompactHexagonal, latticeCubic, extrude
export extrude!
export fillVolumeSpheres

export platformAdapt, commonArguments, vectParams, subs, splitEqs, splits

#Reserved variables of the model
include("./constants/constants.jl")
include("./constants/abstractStructures.jl")

#Structure
include("./model/model.jl")
include("./community/community.jl")
include("./community/baseModuleExtensions.jl")
include("./community/save.jl")
include("./community/load.jl")

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
include("./random/randomAdapt.jl")

#Model functions
include("./model/parameterAdapt.jl")
include("./model/basic/addGlobal.jl")
include("./model/basic/addLocal.jl")
include("./model/basic/addLocalInteraction.jl")
include("./model/basic/addVariable.jl")
include("./model/basic/addInteraction.jl")
include("./model/basic/addIdentifier.jl")

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
include("./integrator/heun.jl")
include("./integrator/integrators.jl")

#Saving
include("./saving/saveRAM.jl")
include("./saving/saveCSV.jl")
include("./saving/saveVTK.jl")

#Compile
include("./compile/compile.jl")

#Predefined models
include("./predefinedModels/basic.jl")

#Adds to the community
include("./community/latices/latticeCompactHexagonal.jl")
include("./community/latices/latticeCubic.jl")
include("./community/extrude.jl")
include("./community/initialisers.jl")

end