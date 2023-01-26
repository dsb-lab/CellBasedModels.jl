DTYPE = Dict(
                :Float => Dict([:CPU=>Float64,:GPU=>Float32]),
                :Int => Dict([:CPU=>Int,:GPU=>Int32])
            )
ZEROS =  Dict([:CPU=>zeros,:GPU=>CUDA.zeros])
ARRAY = Dict([:CPU=>Array,:GPU=>CuArray])

#Parameters
BASEPARAMETERS = OrderedDict(
                                                   #dtype    #Shape                     #Origin      #Reassign    #Protected #Reset    #Necessaryfor                         #Initialize
#Parameters of time
    :t                            => BaseParameter(:Float,   (:Global,),                :Base,        false,       false,     false,    Symbol[],                             @eval (com,agent) -> [1.]                                                                      ),
    :dt                           => BaseParameter(:Float,   (:Global,),                :Base,        false,       false,     false,    Symbol[],                             @eval (com,agent) -> [1.]                                                                      ),
#Parameters of system size
    :N                            => BaseParameter(:Int,     (:Global,),                :Base,        false,       true,      false,    Symbol[],                             @eval (com,agent) -> [1]                                                                       ),
    :NMedium                      => BaseParameter(:Int,     (:Dims,),                  :Base,        false,       true,      false,    Symbol[:Medium],                      @eval (com,agent) -> zeros(Int64,agent.dims)                                                                       ),
    :nMax_                        => BaseParameter(:Int,     (:Global,),                :Base,        false,       true,      false,    Symbol[],                             @eval (com,agent) -> copy(com[:N])                                                               ),
#Parameters of id identity
    :id                           => BaseParameter(:Int,     (:Local,),                 :Base,        true,        true,      false,    Symbol[],                             @eval (com,agent) -> 1:com[:N][1]                                                                ),
    :idMax_                       => BaseParameter(:Int,     (:Atomic,),                :Base,        false,       true,      false,    Symbol[],                             @eval (com,agent) -> Threads.Atomic{Int64}(com[:N][1])                                             ),
#Parameters of simulation topology
    :simBox                       => BaseParameter(:Float,   (:Dims,2),                 :Base,        false,       false,     false,    Symbol[:Medium,:CellLinked],          @eval (com,agent) -> Float64[0. 1;0 1;0 1][1:agent.dims,:]                                            ),
#Parameters of addition and removal of agents
    :NAdd_                        => BaseParameter(:Int,     (:Atomic,),                :Base,        false,       true,      false,    Symbol[],                             @eval (com,agent) -> Threads.Atomic{Int64}(0)                                                    ),
    :NRemove_                     => BaseParameter(:Int,     (:Atomic,),                :Base,        false,       true,      false,    Symbol[],                             @eval (com,agent) -> Threads.Atomic{Int64}(0)                                                    ),
    :NSurvive_                    => BaseParameter(:Int,     (:Atomic,),                :Base,        false,       true,      false,    Symbol[],                             @eval (com,agent) -> Threads.Atomic{Int64}(0)                                                    ),
    :flagSurvive_                 => BaseParameter(:Int,     (:Local,),                 :Base,        true,        true,      false,    Symbol[],                             @eval (com,agent) -> if agent.removalOfAgents_; zeros(Int64,com[:N][1]); else zeros(Int64,0); end                                                       ),
    :holeFromRemoveAt_            => BaseParameter(:Int,     (:Local,),                 :Base,        true,        true,      false,    Symbol[],                             @eval (com,agent) -> if agent.removalOfAgents_; zeros(Int64,com[:N][1]); else zeros(Int64,0); end                                                       ),
    :repositionAgentInPos_        => BaseParameter(:Int,     (:Local,),                 :Base,        false,       true,      false,    Symbol[],                             @eval (com,agent) -> if agent.removalOfAgents_; zeros(Int64,com[:N][1]); else zeros(Int64,0); end                                                       ),
#Parameters of neighborhoods
    :skin                         => BaseParameter(:Float,   (:Global,),                :Neighbor,    false,       false,     false,    Symbol[:VerletTime,:VerletDisplacement],  @eval (com,agent) -> Float64[0.]                                                                 ),
    :dtNeighborRecompute          => BaseParameter(:Float,   (:Global,),                :Neighbor,    false,       false,     false,    Symbol[:VerletTime],                  @eval (com,agent) -> Float64[0.]                                                                 ),
    :nMaxNeighbors                => BaseParameter(:Int,     (:Global,),                :Neighbor,    false,       false,     false,    Symbol[:VerletTime,:VerletDisplacement],  @eval (com,agent) -> Int[0]                                                                    ),
    :cellEdge                     => BaseParameter(:Float,   (:Dims,),                  :Neighbor,    false,       false,     false,    Symbol[:CellLinked],                  @eval (com,agent) -> Float64[1.,1.,1.][1:agent.dims]                                                                 ),
    :flagRecomputeNeighbors_      => BaseParameter(:Int,     (:Global,),                :Neighbor,    false,       true,      false,    Symbol[],                             @eval (com,agent) -> [1]                                                                       ),
    :flagNeighbors_               => BaseParameter(:Int,     (:Local,),                 :Base,        true,        true,      false,    Symbol[],                             @eval (com,agent) -> zeros(Int64,com[:N][1])                                                       ),
    :neighborN_                   => BaseParameter(:Int,     (:Local,),                 :Neighbor,    true ,       true,      false,    Symbol[],                             @eval (com,agent) -> if agent.neighbors in [:VerletDisplacement,:VerletTime]; zeros(Int64,com[:N][1]) else zeros(Int64,0); end                                                      ),
    :neighborList_                => BaseParameter(:Int,     (:Local,:Neighbors),       :Neighbor,    true ,       true,      false,    Symbol[],                             @eval (com,agent) -> if agent.neighbors in [:VerletDisplacement,:VerletTime]; zeros(Int64,com[:N][1],com[:nMaxNeighbors][1]) else zeros(Int64,0,0); end                                  ),
    :neighborTimeLastRecompute_   => BaseParameter(:Float,   (:Global,),                :Neighbor,    false,       true,      false,    Symbol[],                             @eval (com,agent) -> Float64[0]                                                                ),
    :posOld_                      => BaseParameter(:Float,   (:Local,:Dims),            :Neighbor,    true,        true,      false,    Symbol[],                             @eval (com,agent) -> if agent.neighbors == :VerletDisplacement; zeros(Float64,com[:N][1],agent.dims) else zeros(Float64,0,agent.dims); end                                          ),
    :accumulatedDistance_         => BaseParameter(:Float,   (:Local,),                 :Neighbor,    true,        true,      false,    Symbol[],                             @eval (com,agent) -> if agent.neighbors == :VerletDisplacement; zeros(Int64,com[:N][1]); else zeros(Int64,0); end                                                      ),
    :nCells_                      => BaseParameter(:Int,     (:Dims,),                  :Neighbor,    false,       true,      false,    Symbol[],                             @eval (com,agent) -> if agent.dims == 0 || !(agent.neighbors in [:CellLinked]); Int64[0]; else ceil.(Int64,(com[:simBox][:,2].-com[:simBox][:,1])./com[:cellEdge][1] .+2); end        ),
    :cellAssignedToAgent_         => BaseParameter(:Int,     (:Local,),                 :Neighbor,    false,       true,      false,    Symbol[],                             @eval (com,agent) -> zeros(Int64,com[:N][1])                                           ),
    :cellNumAgents_               => BaseParameter(:Int,     (:Cells,),                 :Neighbor,    false,       true,      false,    Symbol[],                             @eval (com,agent) -> zeros(Int64,prod(com[:nCells_]))                                           ),
    :cellCumSum_                  => BaseParameter(:Int,     (:Cells,),                 :Neighbor,    false,       true,      false,    Symbol[],                             @eval (com,agent) -> zeros(Int64,prod(com[:nCells_]))                                           ),
#Parameters of position
    :x                            => BaseParameter(:Float,   (:Local,),                 :User,        true,        false,     false,    Symbol[],                             @eval (com,agent) -> if agent.dims < 1; Float64[]; else zeros(Float64,com[:N][1]) end                                                   ),
    :y                            => BaseParameter(:Float,   (:Local,),                 :User,        true,        false,     false,    Symbol[],                             @eval (com,agent) -> if agent.dims < 2; Float64[]; else zeros(Float64,com[:N][1]) end                                                   ),
    :z                            => BaseParameter(:Float,   (:Local,),                 :User,        true,        false,     false,    Symbol[],                             @eval (com,agent) -> if agent.dims < 3; Float64[]; else zeros(Float64,com[:N][1]) end                                                   ),  
    :xNew_                        => BaseParameter(:Float,   (:Local,),                 :User,        true,        true,      false,    Symbol[],                             @eval (com,agent) -> if agent.posUpdated_[1]; zeros(Float64,com[:N][1]) else Float64[] end                                                   ),
    :yNew_                        => BaseParameter(:Float,   (:Local,),                 :User,        true,        true,      false,    Symbol[],                             @eval (com,agent) -> if agent.posUpdated_[2]; zeros(Float64,com[:N][1]) else Float64[] end                                                   ),
    :zNew_                        => BaseParameter(:Float,   (:Local,),                 :User,        true,        true,      false,    Symbol[],                             @eval (com,agent) -> if agent.posUpdated_[3]; zeros(Float64,com[:N][1]) else Float64[] end                                                   ),  
#Parameters of user declared
    :liNM_                        => BaseParameter(:Int,     (:Local,:User),            :User,        true,        true,      false,    Symbol[],                             @eval (com,agent) -> zeros(Int64,com[:N][1],length(getSymbolsThat(agent.declaredSymbols,:basePar,:liNM_)))         ),
    :liM_                         => BaseParameter(:Int,     (:Local,:User),            :User,        true,        true,      false,    Symbol[],                             @eval (com,agent) -> zeros(Int64,com[:N][1],length(getSymbolsThat(agent.declaredSymbols,:basePar,:liM_)))          ),
    :liMNew_                      => BaseParameter(:Int,     (:Local,:User),            :User,        true,        true,      false,    Symbol[],                             @eval (com,agent) -> zeros(Int64,com[:N][1],length(getSymbolsThat(agent.declaredSymbols,:basePar,:liM_)))          ),
    :lii_                         => BaseParameter(:Int,     (:Local,:User),            :User,        true,        true,      true,     Symbol[],                             @eval (com,agent) -> zeros(Int64,com[:N][1],length(getSymbolsThat(agent.declaredSymbols,:basePar,:lii_)))          ),
    :lfNM_                        => BaseParameter(:Float,   (:Local,:User),            :User,        true,        true,      false,    Symbol[],                             @eval (com,agent) -> zeros(Float64,com[:N][1],length(getSymbolsThat(agent.declaredSymbols,:basePar,:lfNM_)))     ),
    :lfM_                         => BaseParameter(:Float,   (:Local,:User),            :User,        true,        true,      false,    Symbol[],                             @eval (com,agent) -> zeros(Float64,com[:N][1],length(getSymbolsThat(agent.declaredSymbols,:basePar,:lfM_)))      ),
    :lfMNew_                      => BaseParameter(:Float,   (:Local,:User),            :User,        true,        true,      false,    Symbol[],                             @eval (com,agent) -> zeros(Float64,com[:N][1],length(getSymbolsThat(agent.declaredSymbols,:basePar,:lfM_)))      ),
    :lfi_                         => BaseParameter(:Float,   (:Local,:User),            :User,        true,        true,      true,     Symbol[],                             @eval (com,agent) -> zeros(Float64,com[:N][1],length(getSymbolsThat(agent.declaredSymbols,:basePar,:lfi_)))      ),
    :gfNM_                        => BaseParameter(:Float,   (:Globals,),               :User,        false,       true,      false,    Symbol[],                             @eval (com,agent) -> zeros(Float64,length(getSymbolsThat(agent.declaredSymbols,:basePar,:gfNM_)))              ),
    :gfM_                         => BaseParameter(:Float,   (:Globals,),               :User,        false,       true,      false,    Symbol[],                             @eval (com,agent) -> zeros(Float64,length(getSymbolsThat(agent.declaredSymbols,:basePar,:gfM_)))               ),
    :gfMNew_                      => BaseParameter(:Float,   (:Globals,),               :User,        false,       true,      false,    Symbol[],                             @eval (com,agent) -> zeros(Float64,length(getSymbolsThat(agent.declaredSymbols,:basePar,:gfM_)))               ),
    :gfi_                         => BaseParameter(:Float,   (:Globals,),               :User,        false,       true,      true,     Symbol[],                             @eval (com,agent) -> zeros(Float64,length(getSymbolsThat(agent.declaredSymbols,:basePar,:gfi_)))               ),
    :giNM_                        => BaseParameter(:Int,     (:Globals,),               :User,        false,       true,      false,    Symbol[],                             @eval (com,agent) -> zeros(Int64,length(getSymbolsThat(agent.declaredSymbols,:basePar,:giNM_)))                  ),
    :giM_                         => BaseParameter(:Int,     (:Globals,),               :User,        false,       true,      false,    Symbol[],                             @eval (com,agent) -> zeros(Int64,length(getSymbolsThat(agent.declaredSymbols,:basePar,:giM_)))                   ),
    :giMNew_                      => BaseParameter(:Int,     (:Globals,),               :User,        false,       true,      false,    Symbol[],                             @eval (com,agent) -> zeros(Int64,length(getSymbolsThat(agent.declaredSymbols,:basePar,:giM_)))                   ),
    :gii_                         => BaseParameter(:Int,     (:Globals,),               :User,        false,       true,      true,     Symbol[],                             @eval (com,agent) -> zeros(Int64,length(getSymbolsThat(agent.declaredSymbols,:basePar,:gii_)))                   ),
    :mediumNM_                    => BaseParameter(:Float,   (:Medium,),                :User,        false,       true,      false,    Symbol[],                             @eval (com,agent) -> zeros(Float64,com[:NMedium]...)                                                             ),
    :mediumM_                     => BaseParameter(:Float,   (:Medium,),                :User,        false,       true,      false,    Symbol[],                             @eval (com,agent) -> zeros(Float64,com[:NMedium]...)                                                             ),
    :mediumMNew_                  => BaseParameter(:Float,   (:Medium,),                :User,        false,       true,      false,    Symbol[],                             @eval (com,agent) -> zeros(Float64,com[:NMedium]...)                                                             )
)

POSITIONPARAMETERS = [:x,:y,:z]

BASESYMBOLS = OrderedDict(
#Symbols interaction
    :InteractionIndex1            => BaseSymbol(:i,            :End),
    :InteractionIndex2            => BaseSymbol(:j,            :End),
#Symbols new
    :UpdateSymbol                 => BaseSymbol(:new,          :End),
#Symbols addCellBASE
    :AddCell                      => BaseSymbol(:addCell,      :End),
#Symbols macrofunctions
    :AddAgentMacro                => BaseSymbol(:addAgent,     :Macro),
    :RemoveAgentMacro             => BaseSymbol(:removeAgent,  :Macro)
)     

NEIGHBORSYMBOLS = [:Full, :VerletTime, :VerletDisplacement, :CellLinked]

UPDATES = [
  :UpdateGlobal, 
  :UpdateLocal, 
  :UpdateInteraction, 
  :UpdateMedium, 
  :UpdateMediumInteraction, 
  :UpdateVariable
]

PLATFORMS = [:CPU,:GPU]

SAVING = [:RAM,:JLD]

INTEGRATOR = [:Euler]

PLATFORM = [:CPU,:GPU]

UPDATINGOPERATORS = [:(=),:+= ,:-=,:*=,:/=,:\=,:÷=,:%=,:^=,:&=,:|=,:⊻=,:>>>=,:>>=,:<<=]