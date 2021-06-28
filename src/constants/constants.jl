VALID_TYPES = [
    :Identity,
    :Local,
    :Global,
    :GlobalArray
]

VALID_UPDATES = [
    :UpdateGlobal,
    :UpdateLocal,
    :UpdateLocalInteraction,
    :UpdateInteraction,
    :Equation,
    :EventDivision,
    :EventDeath
]

UPDATINGOPERATORS = [:+= ,:-=,:*=,:/=,:\=,:÷=,:%=,:^=,:&=,:|=,:⊻=,:>>>=,:>>=,:<<=]

RESERVEDSYMBOLS = [:t,:N,:dt,:dW,:nMax,
                    :ic1_,:ic2_,:nnic2_,:pos_,
                    :localV,:identityV,:globalV,
                    :ALGORITHM_,:ARGS_,:AUX1_,:AUX2_,
                    :index_,:stride_,:lockadd_];

EQUATIONSYMBOL = "d_"

INTERACTIONSYMBOLS = ["_i","_j"]
INTERACTIONSYMBOLSDICT = Dict(["_i"=>"[ic1_,VAR]","_j"=>"[nnic2_,VAR]"])

DIVISIONSYMBOLS = ["_1","_2"]
DIVISIONSYMBOLSDICT = Dict(["_1"=>"[ic1_,VAR]","_1"=>"[nnic2_,VAR]"])

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
