function KernelAbstractions.get_backend(field::CSRBlock)
    KernelAbstractions.get_backend(field._map)
end

function KernelAbstractions.get_backend(field::CSRSlack)
    KernelAbstractions.get_backend(field._map)
end

######################################################################################################
# toDevice - Device transfer functions for CSR structures
######################################################################################################

# CSRBlock to CPU
function toDevice(field::CSRBlock{P}, ::Type{CPU}) where {P<:GPU}
    CSRBlock(
        Adapt.adapt(Array, field._map),
        SizedVector{1}(Array(field._N)[1]),
        SizedVector{1}(Array(field._NBlock)[1]),
        SizedVector{1}(Array(field._NCache)[1]),
        field._ActiveSection === nothing ? nothing : Vector{Int}(field._ActiveSection),
        Vector{Bool}(field._FlagsSurvived),
        SizedVector{1}(Array(field._NAdded)[1]),
        SizedVector{1}(Array(field._NOverflow)[1]),
        SizedVector{1}(Array(field._NOverflowBlock)[1]),
    )
end

toDevice(field::CSRBlock{P}, ::Type{CPU}) where {P<:CPU} = field

# CSRSlack to CPU
function toDevice(field::CSRSlack{P, PR, AI, VI, VI2, VB}, ::Type{CPU}) where {P<:GPU, PR, AI, VI, VI2, VB}
    CSRSlack(
        Adapt.adapt(Array, field._map),
        SizedVector{1}(Array(field._N)[1]),
        Vector{Int}(field._offsets),
        field._ActiveSection === nothing ? nothing : Vector{Int}(field._ActiveSection),
        Vector{Bool}(field._FlagsSurvived),
        SizedVector{1}(Array(field._NAdded)[1]),
        SizedVector{1}(Array(field._NOverflow)[1]),
        SizedVector{1}(Array(field._NOverflowBlock)[1]),
    )
end

toDevice(field::CSRSlack{P}, ::Type{CPU}) where {P<:CPU} = field