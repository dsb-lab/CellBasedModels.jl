FLOAT = Dict(["cpu"=>Float64,"gpu"=>Float64])
INT = Dict(["cpu"=>Int,"gpu"=>Int32])
ZEROS =  Dict(["cpu"=>zeros,"gpu"=>CUDA.zeros])
ARRAY = Dict(["cpu"=>Array,"gpu"=>CuArray])

#Types accepted by agent
VALIDTYPES = [
    :LocalInt,
    :LocalIntInteraction,
    :LocalFloat,
    :LocalFloatInteraction,
    :GlobalFloat,
    :GlobalInt,
    :GlobalFloatInteraction,
    :GlobalIntInteraction,
    :Medium,
    :BaseModel,
    :NeighborsAlgorithm,
    :IntegrationAlgorithm,
    :ComputingPlatform,
    :SavingPlatform,
]

UPDATINGTYPES = [
    :LocalInt,
    :LocalFloat,
    :GlobalFloat,
    :GlobalInt,
]

VALIDUPDATES = [
    :UpdateGlobal,
    :UpdateLocal,
    :UpdateInteraction,
    :UpdateGlobalInteraction,
    :UpdateMedium,
    :UpdateMediumInteraction,
    :UpdateVariable,
]

#Parameters
BASESYMBOLS = DataFrame(
  name = [:t,:dt,:N,:id,:simulationBox,:interactionRadius],
  type = [:GlobalFloat,:GlobalFloat,:GlobalInt,:LocalInt,:SimulationVolume,:SimulationVolume],
  use = [:General,:General,:General,:General,:SimulationVolume,:SimulationVolume]
)

POSITIONSYMBOLS = DataFrame(
    name = [:x,:y,:z],
    type = [:LocalFloat,:LocalFloat,:LocalFloat],
    use = [:Position,:Position,:Position]
  )

PLATFORMS = [:CPU,:GPU]

SAVING = [:RAM,:JLD]

MACROFUNCTIONS = [:addAgent,:removeAgent]

UPDATINGOPERATORS = [:(=),:+= ,:-=,:*=,:/=,:\=,:÷=,:%=,:^=,:&=,:|=,:⊻=,:>>>=,:>>=,:<<=]

RESERVEDSYMBOLS = [:x,:y,:z,:id,:t,:N,:dt,:dW,:nMax,
                    :idMediumX,:idMediumY,:idMediumZ,
                    :ic1_,:ic2_,:nnic2_,:pos_,
                    :localV,:identityV,:globalV,:globalInteractionV,:mediumV,:localInteractionV,
                    :localVCopy,:identityVCopy,:globalVCopy,:mediumVCopy,
                    :simulationBox,:radiusInteraction,:n_,
                    :ALGORITHM_,:ARGS_,:AUX1_,:AUX2_,
                    :BOUNDARY1MIN_,:BOUNDARY1MAX_,:BOUNDARY2MIN_,:BOUNDARY2MAX_,:BOUNDARY3MIN_,:BOUNDARY3MAX_,:INNERMEDIUM_,
                    :limNMax_,
                    :index_,:stride_,:lockadd_,
                    :Nx_,:Ny_,:Nz_,
                    :∇,:∇x,:∇y,:∇z,:Δ,:Δx,:Δy,:Δz,:δx,:δy,:δz,:xₘ,:yₘ,:zₘ,
                    :newmannX,:dirichletX,:periodicX,:newmannY,:dirichletY,:periodicY,:newmannZ,:dirichletZ,:periodicZ,
                    :predV,:learningRateIntegrator,:relativeErrorIntegrator,:maxLearningStepsIntegrator,
                    :K1_,:K2_,:K3_,:K4_];

BASEARGS = [:(t),:(dt),:(N),:(NMax)]
VARARGS = [:(localV),:(identityV),:(globalV),:(globalInteractionV),:(localInteractionV)]
VARARGSCOPY = [:(localVCopy),:(identityVCopy),:(globalVCopy)]
MEDIUMARGS = [:NMedium,:dMedium,:(mediumV)]
MEDIUMARGSCOPY = [:(mediumVCopy)]
ARGS = [BASEARGS; VARARGS; VARARGSCOPY; MEDIUMARGS; MEDIUMARGS; MEDIUMARGSCOPY]

COMARGS = [:(com.t),:(com.dt),:(com.N),:(com.NMax),:(com.localV),:(com.identityV),:(com.globalV),
        :(com.globalInteractionV),:(com.localInteractionV),
        :(com.localVCopy),:(com.identityVCopy),:(com.globalVCopy),:(com.medium.NMedium),:(com.medium.dMedium),:(com.medium.mediumV),:(com.medium.mediumVCopy)]

DIFFSYMBOL = :d
DIFFSYMBOL2 = :d2

INTERACTIONSYMBOLS = [:i,:j]
INTERACTIONSYMBOLSDICT = Dict([:i=>"[ic1_,VAR]",:j=>"[nnic2_,VAR]"])

DIFFMEDIUMSYMBOL = :∂t
DIFFMEDIUM = [:dxₘ_,:dyₘ_,:dzₘ_]
MEDIUMSYMBOLS = [:∂t,:∇,:∇x,:∇y,:∇z,:Δ,:Δx,:Δy,:Δz,:δr]
MEDIUMBOUNDARYSYMBOLS = Dict([
                        1=>Dict([
                                    "min"=>[:newmannXmin,:dirichletXmin,:periodicX],
                                    "max"=>[:newmannXmax,:dirichletXmax,:periodicX]
                                ])
                        2=>Dict([
                                    "min"=>[:newmannYmin,:dirichletYmin,:periodicY],
                                    "max"=>[:newmannYmax,:dirichletYmax,:periodicY]
                                ])
                        3=>Dict([
                                    "min"=>[:newmannZmin,:dirichletZmin,:periodicZ],
                                    "max"=>[:newmannZmax,:dirichletZmax,:periodicZ]
                                ])
                        ])
MEDIUMITERATIONSYMBOLS = [:ic1_,:ic2_,:ic3_]
MEDIUMSUMATIONSYMBOLS = [:Nx_,:Ny_,:Nz_]
MEDIUMINDEXSYMBOLS = [:indexX_,:indexY_,:indexZ_]
MEDIUMSTRIDESYMBOLS = [:strideX_,:strideY_,:strideZ_]
MEDIUMAUXILIAR = [Dict([
                    "min"=>:BOUNDARY1MIN_,
                    "max"=>:BOUNDARY1MAX_
                    ]),
                  Dict([
                    "min"=>:BOUNDARY2MIN_,
                    "max"=>:BOUNDARY2MAX_
                    ]),
                  Dict([
                    "min"=>:BOUNDARY3MIN_,
                    "max"=>:BOUNDARY3MAX_
                    ]),
                  :INNERMEDIUM_
                  ]

#Adaptation functions
GPUINFUNCTION = 
"index_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
stride_ = blockDim().x * gridDim().x
"
CPUINFUNCTION =
"Threads.@threads"

GPUOUTFUNCTION = 
"CUDA.@cuda threads=threads_ blocks=nBlocks_ "
CPUOUTFUNCTION = 
""

GPUARRAY = 
"CUDA."
CPUARRAY = 
""

GPUARRAYEMPTY = 
"CUDA.CuArray{Float32}"
CPUARRAYEMPTY = 
"Array{Float64}"

GPUARRAYEMPTYINT = 
"CUDA.CuArray{Int32}"
CPUARRAYEMPTYINT = 
"Array{Int64}"
