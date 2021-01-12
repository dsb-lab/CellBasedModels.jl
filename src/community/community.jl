mutable struct Community
    t_::AbstractFloat
    N_::Int
    declaredSymb::Dict{String,Array{Symbol}}
    var::Array{AbstractFloat,2}
    inter::Array{AbstractFloat,2}
    loc::Array{AbstractFloat,2}
    locInter::Array{AbstractFloat,2}
    glob::Array{AbstractFloat,1}
    ids::Array{Int,2}
end

function Community(agentModel::Model; N::Int=1, t::AbstractFloat=0.)

    var = zeros(N,length(agentModel.declaredSymb["var"]))
    inter = zeros(N,length(agentModel.declaredSymb["inter"]))
    loc = zeros(N,length(agentModel.declaredSymb["loc"]))
    locInter = zeros(N,length(agentModel.declaredSymb["loc"]))
    glob = zeros(length(agentModel.declaredSymb["glob"]))
    ids = zeros(Int,N,length(agentModel.declaredIds))

    declaredSymb = agentModel.declaredSymb
    declaredSymb["ids"] = agentModel.declaredIds

    return Community(t,N,declaredSymb,var,inter,loc,locInter,glob,ids)
end