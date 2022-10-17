FLOAT = Dict([:CPU=>Float64,:GPU=>Float64])
INT = Dict([:CPU=>Int,:GPU=>Int32])
ZEROS =  Dict([:CPU=>zeros,:GPU=>CUDA.zeros])
ARRAY = Dict([:CPU=>Array,:GPU=>CuArray])

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

UPDATES = [
    :UpdateGlobal,
    :UpdateLocal,
    :updateLocalInteraction,
    :UpdateGlobalInteraction,
    :UpdateMedium,
    :UpdateMediumInteraction,
    :UpdateVariable,
]

#Parameters
BASESYMBOLS = Dict(
    :t=>[:Float,:Global,:Base],
    :dt=>[:Float,:Global,:Base],
    :N=>[:Int,:Global,:Base],
    :id=>[:Int,:Local,:Base],
    :nMax=>[:Float,:Global,:Base]
  )

POSITIONSYMBOLS = [(:x,[:Float,:Local,:Position]),
                    (:y,[:Float,:Local,:Position]),
                    (:z,[:Float,:Local,:Position])]

NEIGHBORSYMBOLS = Dict(
  :Full => Dict(),
  :VerletTime => Dict(
      :skin => [:Float,:Global,:Neighbor],
      :dtNeighborRecompute => [:Float,:Global,:Neighbor],
      :nMaxNeighbors => [:Int,:Global,:Neighbor],
      :neighborList_ => [:Int,:VerletList,:Neighbor],
      :neighborN_ => [:Int,:Local,:Neighbor],
      :neighborTimeLastRecompute_ => [:Float,:Global,:Neighbor]
    ),
  :VerletDisplacement => Dict(
      :skin => [:Float,:Global,:Neighbor],
      :nMaxNeighbors => [:Int,:Global,:Neighbor],
      :neighborList_ => [:Int,:VerletList,:Neighbor],
      :neighborN_ => [:Int,:Local,:Neighbor],
      :neighborMaxDistance_ => [:Float,:Global,:Neighbor],
      :neighborFlagRecompute_ => [:Int,:Global,:Neighbor]
    )
)

PLATFORMS = [:CPU,:GPU]

SAVING = [:RAM,:JLD]

INTEGRATOR = [:Euler]

PLATFORM = [:CPU,:GPU]

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

DIFFSYMBOL = :d

INTERACTIONSYMBOLS = [:i,:j]

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