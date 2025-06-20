"""
Units and constants used in the simulation [framework](https://en.wikipedia.org/wiki/SI_base_unit).
"""
UNITS = Dict(
    :L => Dict(
        :km => 1000.0,
        :m => 1.0,
        :cm => 0.01,
        :mm => 0.001,
        :μm => 1e-6,
        :nm => 1e-9,
        :pm => 1e-12,
        :fm => 1e-15,        
    ),
    :T => Dict(
        :year => 31557600.0,  # 365.25 days
        :month => 2592000.0,  # 30 days
        :day => 86400.0,
        :h => 3600.0,
        :min => 60.0,
        :s => 1.0,
        :ms => 0.001,
        :μs => 1e-6,
        :ns => 1e-9,
        :ps => 1e-12,
        :fs => 1e-15,
    ),
    :M => Dict(
        :kg => 1000.0,
        :g => 1.0,
        :mg => 0.001,
        :μg => 1e-6,
        :ng => 1e-9,
        :pg => 1e-12,
        :fg => 1e-15,
    ),
    :Θ => Dict(
        :K => 1.0,  # Kelvin is the base unit        
    ),
    :I => Dict(
        :kcd => 1000.0,  # Kilocandela
        :cd => 1.0,  # Candela is the base unit
        :mcd => 0.001,  # Millicandela
        :μcd => 1e-6,  # Microcandela
        :ncd => 1e-9,  # Nanocandela
        :pcd => 1e-12,  # Picocandela
        :fcd => 1e-15,  # Femtocandela
    ),
    :N => Dict(
        :mol => 1.0,  # Mole is the base unit
        :mmol => 0.001,  # Millimole
        :μmol => 1e-6,  # Micromole
        :nmol => 1e-9,  # Nanomole
        :pmol => 1e-12,  # Picomole
        :fmol => 1e-15,  # Femtomole
    ),
    :J => Dict(
        :A => 1.0,  # Ampere is the base unit
        :mA => 0.001,
        :μA => 1e-6,
        :nA => 1e-9,
        :pA => 1e-12,
        :fA => 1e-15,
    ),
)

DIMENSION_OPERATORS = [:*,:/,:^]

# DTYPE = Dict(
#                 :Float => Dict([:CPU=>Float64,:GPU=>Float32]),
#                 :Int => Dict([:CPU=>Int,:GPU=>Int32])
#             )
# ZEROS =  Dict([:CPU=>zeros,:GPU=>CUDA.zeros])
# ARRAY = Dict([:CPU=>Array,:GPU=>CuArray])

# #Parameters
# BASEPARAMETERS = OrderedDict(
#                                                    #dtype    #Shape                     #SaveLevel  #Origin      #Reassign    #Protected #Reset    #Necessaryfor                         #Initialize
# #Parameters of time
#     # :t                            => BaseParameter(:Float,   (:Global,),                1,          :Base,        false,       false,     false,    Symbol[],                                       @eval (com,agent) -> [0.]                                                                      ),
#     # :dt                           => BaseParameter(:Float,   (:Global,),                1,          :Base,        false,       false,     false,    Symbol[],                                       @eval (com,agent) -> [1.]                                                                      ),
# #Parameters of system size
#     # :N                            => BaseParameter(:Int,     (:Global,),                1,          :Base,        false,       true,      false,    Symbol[],                                       @eval (com,agent) -> [1]                                                                       ),
#     # :NMedium                      => BaseParameter(:Int,     (:Dims,),                  0,          :Base,        false,       true,      false,    Symbol[:Medium],                                @eval (com,agent) -> zeros(Int64,agent.dims)                                                                       ),
#     # :nMax_                        => BaseParameter(:Int,     (:Global,),                2,          :Base,        false,       true,      false,    Symbol[],                                       @eval (com,agent) -> copy(com[:N])                                                               ),
# #Parameters of id identity
#     # :id                           => BaseParameter(:Int,     (:Local,),                 1,          :Base,        true,        true,      false,    Symbol[],                                       @eval (com,agent) -> 1:com[:N][1]                                                                ),
#     # :idMax_                       => BaseParameter(:Int,     (:Atomic,),                2,          :Base,        false,       true,      false,    Symbol[],                                       @eval (com,agent) -> Threads.Atomic{Int64}(com[:N][1])                                             ),
# #Parameters of simulation topology
#     # :simBox                       => BaseParameter(:Float,   (:Dims,2),                 0,          :Base,        false,       false,     false,    Symbol[:Medium,:CellLinked,:CLVD],              @eval (com,agent) -> Float64[0. 1;0 1;0 1][1:agent.dims,:]                                            ),
# #Parameters of medium
#     # :dx                            => BaseParameter(:Float,   (:Global,),                1,          :Base,        false,       false,     false,    Symbol[],                                       @eval (com,agent) -> [0.]                                                                      ),
#     # :dy                            => BaseParameter(:Float,   (:Global,),                1,          :Base,        false,       false,     false,    Symbol[],                                       @eval (com,agent) -> [0.]                                                                      ),
#     # :dz                            => BaseParameter(:Float,   (:Global,),                1,          :Base,        false,       false,     false,    Symbol[],                                       @eval (com,agent) -> [0.]                                                                      ),
# #Parameters of addition and removal of agents
#     # :NAdd_                        => BaseParameter(:Int,     (:Atomic,),                2,          :Base,        false,       true,      false,    Symbol[],                                       @eval (com,agent) -> Threads.Atomic{Int64}(0)                                                    ),
#     # :NRemove_                     => BaseParameter(:Int,     (:Atomic,),                2,          :Base,        false,       true,      false,    Symbol[],                                       @eval (com,agent) -> Threads.Atomic{Int64}(0)                                                    ),
#     # :NSurvive_                    => BaseParameter(:Int,     (:Atomic,),                2,          :Base,        false,       true,      false,    Symbol[],                                       @eval (com,agent) -> Threads.Atomic{Int64}(0)                                                    ),
#     # :flagSurvive_                 => BaseParameter(:Int,     (:Local,),                 2,          :Base,        true,        true,      false,    Symbol[],                                       @eval (com,agent) -> if agent.removalOfAgents_; ones(Int64,com[:N][1]); else ones(Int64,0); end                                                       ),
#     # :holeFromRemoveAt_            => BaseParameter(:Int,     (:Local,),                 2,          :Base,        true,        true,      false,    Symbol[],                                       @eval (com,agent) -> if agent.removalOfAgents_; zeros(Int64,com[:N][1]); else zeros(Int64,0); end                                                       ),
#     # :repositionAgentInPos_        => BaseParameter(:Int,     (:Local,),                 2,          :Base,        false,       true,      false,    Symbol[],                                       @eval (com,agent) -> if agent.removalOfAgents_; zeros(Int64,com[:N][1]); else zeros(Int64,0); end                                                       ),
# )

# POSITIONPARAMETERS = [:x,:y,:z]

# # positionParameters=OrderedDict(
# #     :x=>Float64,
# #     :y=>Float64,
# #     :z=>Float64,
# # )

# # positionMediumParameters=OrderedDict(
# #     :xₘ=>Float64,
# #     :yₘ=>Float64,
# #     :zₘ=>Float64,
# # )

# DEFAULTSOLVEROPTIONS = ((:save_everystep,false),(:dense,false))

# UPDATINGOPERATORS = [:(=),:+= ,:-=,:*=,:/=,:\=,:÷=,:%=,:^=,:&=,:|=,:⊻=,:>>>=,:>>=,:<<=]

# SAVING = Dict{String,SavingFile}()

# MAXTHREADS = 256
# MAXBLOCKS = 1000