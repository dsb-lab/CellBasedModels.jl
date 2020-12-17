RESERVEDVAR = [:x1,:x2,:x3,:r];
RESERVEDSYMBOLS = [:t_,:N_,:dt_,:d_,:id_,:Nothing_,:fullConnected_];
RESERVEDCALLS =  ["Uniform","Normal"];

RESERVED = [RESERVEDVAR;RESERVEDSYMBOLS;RESERVEDCALLS];

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
"Array"