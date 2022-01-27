FLOAT = Float64
INT = Int
FLOATCUDA = Float32
INTCUDA = Int32

VALID_TYPES = [
    :Identity,
    :IdentityInteraction,
    :Local,
    :LocalInteraction,
    :Global,
    :GlobalArray,
    :Medium,
    :BaseModel
]

UPDATINGTYPES = ["Local","Identity","Global","GlobalArray","Medium"]

VALID_UPDATES = [
    :UpdateGlobal,
    :UpdateLocal,
    :UpdateLocalInteraction,
    :UpdateInteraction,
    :UpdateMedium,
    :UpdateMediumInteraction,
    :UpdateVariable,
]

MACROFUNCTIONS = [:addAgent,:removeAgent]

POSITIONSYMBOLS = [:x,:y,:z]

BASICARGS=[:t,:N,:dt,:simulationBox]

PREDECLAREDPARAMETERS = Dict("Local"=>[:x,:y,:z],"Identity"=>:id,"Integration"=>[:dt,:dW],"Community"=>[:N],"Evolve"=>[:nMax])

UPDATINGOPERATORS = [:(=),:+= ,:-=,:*=,:/=,:\=,:÷=,:%=,:^=,:&=,:|=,:⊻=,:>>>=,:>>=,:<<=]

RESERVEDSYMBOLS = [:x,:y,:z,:id,:t,:N,:dt,:dW,:nMax,
                    :idMediumX,:idMediumY,:idMediumZ,
                    :ic1_,:ic2_,:nnic2_,:pos_,
                    :localV,:identityV,:globalV,:mediumV,
                    :localVCopy,:identityVCopy,:globalVCopy,:mediumVCopy,
                    :simulationBox,:radiusInteraction,:n_,
                    :ALGORITHM_,:ARGS_,:AUX1_,:AUX2_,
                    :limNMax_,
                    :index_,:stride_,:lockadd_,
                    :Nx_,:Ny_,:Nz_,
                    :∇,:∇x,:∇y,:∇z,:Δ,:Δx,:Δy,:Δz,:δx,:δy,:δz,:xₘ,:yₘ,:zₘ,
                    :newmannX,:dirichletX,:periodicX,:newmannY,:dirichletY,:periodicY,:newmannZ,:dirichletZ,:periodicZ];

GLOBALARRAYCOPY = "_Copy"

UPDATEOPERATORS = [:(=),:(+=),:(-=),:(*=),:(/=),:(\=),:(÷=),:(%=),:(^=),:(&=),:(|=),:(⊻=),:(>>>=),:(>>=),:(<<=)]

DIFFSYMBOL = :d

INTERACTIONSYMBOLS = [:i,:j]
INTERACTIONSYMBOLSDICT = Dict([:i=>"[ic1_,VAR]",:j=>"[nnic2_,VAR]"])

DIFFMEDIUMSYMBOL = :∂t
MEDIUMSYMBOLS = [:∂t,:∇,:∇x,:∇y,:∇z,:Δ,:Δx,:Δy,:Δz,:δr]
MEDIUMBOUNDARYSYMBOLS = [1=>{:newmannXmin,:newmannXmax,:dirichletXmin,:dirichletXmax,:periodicX},
                        2=>{:newmannYmin,:newmannYmax,:dirichletYmin,:dirichletYmax,:periodicY},
                        3=>{:newmannZmin,:newmannZmax,:dirichletZmin,:dirichletZmax,:periodicZ}]
MEDIUMITERATIONSYMBOLS = [:ic1_,:ic2_,:ic3_]
MEDIUMSUMATIONSYMBOLS = [:Nx_,:Ny_,:Nz_]

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
