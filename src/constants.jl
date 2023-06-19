DTYPE = Dict(
                :Float => Dict([:CPU=>Float64,:GPU=>Float32]),
                :Int => Dict([:CPU=>Int,:GPU=>Int32])
            )
ZEROS =  Dict([:CPU=>zeros,:GPU=>CUDA.zeros])
ARRAY = Dict([:CPU=>Array,:GPU=>CuArray])

AGENT = 0

#Parameters
BASEPARAMETERS = OrderedDict(
                                                   #dtype    #Shape                     #SaveLevel  #Origin      #Reassign    #Protected #Reset    #Necessaryfor                         #Initialize
#Parameters of time
    :t                            => BaseParameter(:Float,   (:Global,),                1,          :Base,        false,       false,     false,    Symbol[],                                       @eval (com,agent) -> [0.]                                                                      ),
    :dt                           => BaseParameter(:Float,   (:Global,),                1,          :Base,        false,       false,     false,    Symbol[],                                       @eval (com,agent) -> [1.]                                                                      ),
#Parameters of system size
    :N                            => BaseParameter(:Int,     (:Global,),                1,          :Base,        false,       true,      false,    Symbol[],                                       @eval (com,agent) -> [1]                                                                       ),
    :NMedium                      => BaseParameter(:Int,     (:Dims,),                  0,          :Base,        false,       true,      false,    Symbol[:Medium],                                @eval (com,agent) -> zeros(Int64,agent.dims)                                                                       ),
    :nMax_                        => BaseParameter(:Int,     (:Global,),                2,          :Base,        false,       true,      false,    Symbol[],                                       @eval (com,agent) -> copy(com[:N])                                                               ),
#Parameters of id identity
    :id                           => BaseParameter(:Int,     (:Local,),                 1,          :Base,        true,        true,      false,    Symbol[],                                       @eval (com,agent) -> 1:com[:N][1]                                                                ),
    :idMax_                       => BaseParameter(:Int,     (:Atomic,),                2,          :Base,        false,       true,      false,    Symbol[],                                       @eval (com,agent) -> Threads.Atomic{Int64}(com[:N][1])                                             ),
#Parameters of simulation topology
    :simBox                       => BaseParameter(:Float,   (:Dims,2),                 0,          :Base,        false,       false,     false,    Symbol[:Medium,:CellLinked,:CLVD],              @eval (com,agent) -> Float64[0. 1;0 1;0 1][1:agent.dims,:]                                            ),
#Parameters of medium
    :dx                            => BaseParameter(:Float,   (:Global,),                1,          :Base,        false,       false,     false,    Symbol[],                                       @eval (com,agent) -> [0.]                                                                      ),
    :dy                            => BaseParameter(:Float,   (:Global,),                1,          :Base,        false,       false,     false,    Symbol[],                                       @eval (com,agent) -> [0.]                                                                      ),
    :dz                            => BaseParameter(:Float,   (:Global,),                1,          :Base,        false,       false,     false,    Symbol[],                                       @eval (com,agent) -> [0.]                                                                      ),
#Parameters of addition and removal of agents
    :NAdd_                        => BaseParameter(:Int,     (:Atomic,),                2,          :Base,        false,       true,      false,    Symbol[],                                       @eval (com,agent) -> Threads.Atomic{Int64}(0)                                                    ),
    :NRemove_                     => BaseParameter(:Int,     (:Atomic,),                2,          :Base,        false,       true,      false,    Symbol[],                                       @eval (com,agent) -> Threads.Atomic{Int64}(0)                                                    ),
    :NSurvive_                    => BaseParameter(:Int,     (:Atomic,),                2,          :Base,        false,       true,      false,    Symbol[],                                       @eval (com,agent) -> Threads.Atomic{Int64}(0)                                                    ),
    :flagSurvive_                 => BaseParameter(:Int,     (:Local,),                 2,          :Base,        true,        true,      false,    Symbol[],                                       @eval (com,agent) -> if agent.removalOfAgents_; ones(Int64,com[:N][1]); else ones(Int64,0); end                                                       ),
    :holeFromRemoveAt_            => BaseParameter(:Int,     (:Local,),                 2,          :Base,        true,        true,      false,    Symbol[],                                       @eval (com,agent) -> if agent.removalOfAgents_; zeros(Int64,com[:N][1]); else zeros(Int64,0); end                                                       ),
    :repositionAgentInPos_        => BaseParameter(:Int,     (:Local,),                 2,          :Base,        false,       true,      false,    Symbol[],                                       @eval (com,agent) -> if agent.removalOfAgents_; zeros(Int64,com[:N][1]); else zeros(Int64,0); end                                                       ),
)

POSITIONPARAMETERS = [:x,:y,:z]

positionParameters=OrderedDict(
    :x=>Float64,
    :y=>Float64,
    :z=>Float64,
)

positionMediumParameters=OrderedDict(
    :xₘ=>Float64,
    :yₘ=>Float64,
    :zₘ=>Float64,
)

DEFAULTSOLVEROPTIONS = ((:save_everystep,false),(:dense,false))

UPDATINGOPERATORS = [:(=),:+= ,:-=,:*=,:/=,:\=,:÷=,:%=,:^=,:&=,:|=,:⊻=,:>>>=,:>>=,:<<=]

SAVING = Dict{String,SavingFile}()

MAXTHREADS = 256
MAXBLOCKS = 1000