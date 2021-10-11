VALID_TYPES = [
    :Identity,
    :Local,
    :Global,
    :GlobalArray,
    :Medium
]

VALID_UPDATES = [
    :UpdateGlobal,
    :UpdateLocal,
    :UpdateLocalInteraction,
    :UpdateInteraction,
    :UpdateMedium,
    :UpdateMediumInteraction,
    :Equation,
    :EventDivision,
    :EventDeath
]

UPDATINGOPERATORS = [:+= ,:-=,:*=,:/=,:\=,:÷=,:%=,:^=,:&=,:|=,:⊻=,:>>>=,:>>=,:<<=]

RESERVEDSYMBOLS = [:x,:y,:z,:id,:t,:N,:dt,:dW,:nMax,
                    :idMediumX,:idMediumY,:idMediumZ,
                    :ic1_,:ic2_,:nnic2_,:pos_,
                    :localV,:identityV,:globalV,:mediumV,
                    :localVCopy,:identityVCopy,:globalVCopy,:mediumVCopy,
                    :ALGORITHM_,:ARGS_,:AUX1_,:AUX2_,
                    :index_,:stride_,:lockadd_,
                    :∇,:∇x,:∇y,:∇z,:Δ,:Δx,:Δy,:Δz,:δx,:δy,:δz,:xₘ,:yₘ,:zₘ,:∑ₐ,:∑ₙ];

GLOBALARRAYCOPY = "_Copy"

EQUATIONSYMBOL = "d_"

INTERACTIONSYMBOLS = ["_i","_j"]
INTERACTIONSYMBOLSDICT = Dict(["_i"=>"[ic1_,VAR]","_j"=>"[nnic2_,VAR]"])

DIVISIONSYMBOLS = ["_1","_2"]
DIVISIONSYMBOLSDICT = Dict(["_1"=>"[ic1_,VAR]","_1"=>"[nnic2_,VAR]"])

ENDSYMBOLS = ["_i","_j"]

MEDIUMSYMBOL = "∂t_"
MEDIUMSYMBOLS = ["∂t_","∇","∇x","∇y","∇z","Δ","Δx","Δy","Δz","δr"]

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
