"""
Basic structure keeping the parameters of all the agents in the current simulation of a model.


"""
mutable struct Community

    dims::Int
    platform::Tuple{Symbol,Symbol}
    declaredSymbols::OrderedDict{Symbol,Any}
    values::Dict{Symbol,Any}

    function Community(abm::Agent; N::Int=1, NMedium::Array{Int,1}=Array{Int,1}([]))

        if any([:Medium in prop for (i,prop) in pairs(abm.declaredSymbols)])
            if length(NMedium) != abm.dims
                error("NMedium has to be an array with the same length as AgentCompiled dimensions specifing the number of points in the grid.")
            end
        end
    
        dims = abm.dims
        platform = (abm.platform,:CPU)
        declaredSymbols = copy(abm.declaredSymbols)
        values = Dict{Symbol,Any}()
        for (sym,prop) in pairs(declaredSymbols)
            dtype = Float64
            if :Float in prop
                dtype = FLOAT[abm.platform]
            elseif :Int in prop
                dtype = INT[abm.platform]
            end
    
            if :Local in prop
                values[sym] = zeros(dtype,N)
            elseif :Global in prop
                values[sym] = zeros(dtype,1)
            elseif :Medium in prop
                values[sym] = zeros(dtype,NMedium...)
            elseif :VerletList in prop
                values[sym] = zeros(dtype,N,0)
            elseif :SimulationBox in prop
                values[sym] = zeros(dtype,dims,2)
            elseif :Dims in prop
                values[sym] = zeros(dtype,dims)
            elseif :Cells in prop
                values[sym] = zeros(dtype,0)
            elseif :Atomic in prop
                values[sym] = Threads.Atomic{dtype}(0)
            else
                error("Parameter type $(prop[2]) from symbol $sym is not defined.")
            end
        
        end
        values[:N] .= N
        values[:nMax_] .= N
        values[:id] .= 1:N
    
        return new(dims,platform,declaredSymbols,values)
    end    

end

function Base.show(io::IO,com::Community)
    print("PARAMETERS\n\t")
    for (sym,prop) in pairs(com.declaredSymbols)
        print(sym," ",prop,"\n\t")
    end
end

function Base.getproperty(com::Community,var::Symbol)
    
    if var in fieldnames(Community)
        return getfield(com,var)
    else
        if var in keys(com.values)
            return com.values[var]
        else
            error("Parameter ", var, " not found in the community.")
        end
    end

end

function Base.getindex(com::Community,var::Symbol)
    
    if var in fieldnames(Community)
        return getfield(com,var)
    else
        if var in keys(com.values)
            return com.values[var]
        else
            error("Parameter ", var, " not found in the community.")
        end
    end

end

function Base.setproperty!(com::Community,var::Symbol,v::Array{<:Number})

    if !(var in keys(com.declaredSymbols))
        error(var," is not in community.")
    elseif size(com[var]) == size(v)
        com.values[var] .= v
    else
        error("Dimensions and type must match. ",var," is ",size(com.values[var])," and tried to assign a vector of size ",size(v))
    end

end

function Base.setproperty!(com::Community,var::Symbol,v::Number)
    
    if !(var in keys(com.declaredSymbols))
        error(var," is not in community.")
    elseif :Global in com.declaredSymbols[var]
        com.values[var] .= v
    else
        error("Only Global parameters can be assigned with a number.")
    end

end

function Base.setindex!(com::Community,v::Array{<:Number},var::Symbol)
    
    if !(var in keys(com.declaredSymbols))
        error(var," is not in community.")
    elseif size(com[var]) == size(v)
        com.values[var] .= v
    else
        error("Dimensions and type must match. ",var," is ",size(com.var)," and tried to assign a vector of size ",size(v))
    end

end

function Base.setindex!(com::Community,v::Number,var::Symbol)
    
    if !(var in keys(com.declaredSymbols))
        error(var," is not in community.")
    elseif :Global in com.declaredSymbols[var]
        com.values[var] .= v
    else
        error("Only Global parameters can be assigned with a number.")
    end

end

function loadToPlatform!(com::Community;addAgents::Int=0)

    #Initialize initialized parameters that need to be initialized
    for (sym,prop) in pairs(com.declaredSymbols)
        if length(prop) == 4 #Initialization
            com.values[sym] = prop[4](com)
        end
    end

    # Transform to the correct platform
    for (sym,prop) in pairs(com.declaredSymbols)
        dtype = Float64
        if :Float in prop
            dtype = FLOAT[com.platform[2]]
        elseif :Int in prop
            dtype = INT[com.platform[2]]
        end

        if :Local in prop
            com.values[sym] = ARRAY[com.platform[1]]([com.values[sym]; zeros(dtype,addAgents)])
        elseif :VerletList in prop
            com.values[sym] = ARRAY[com.platform[1]](zeros(dtype,com.nMax_[1],com.nMaxNeighbors[1]))
        elseif :SimulationBox in prop
            com.values[sym] = ARRAY[com.platform[1]](com.values[sym])
        elseif :Global in prop
            com.values[sym] = ARRAY[com.platform[1]](com.values[sym])
        elseif :Medium in prop
            com.values[sym] = ARRAY[com.platform[1]](com.values[sym])
        elseif :Dims in prop
            com.values[sym] = ARRAY[com.platform[1]](com.values[sym])
        elseif :Cells in prop
            com.values[sym] = ARRAY[com.platform[1]](com.values[sym])
        elseif :Atomic in prop
            if com.platform[1] == :CPU
                com.values[sym] = com.values[sym]
            else
                error("Atomic GPU not implemented yet")
            end
        else
            error("Parameter type ",prop[2], " is not defined.")
        end

        if :Update in prop #Initialize update paremters
            sym2 = Meta.parse(string(sym)[1:end-4])

            com.values[sym] = com.values[sym2]
        end
    end            

    com.platform = (com.platform[1],com.platform[1])
    #Add limit of agents
    com.nMax_ .= com.N .+ addAgents

    return 
end

"""
Structure that basically stores an array of Coomunities at different time points.

# Elements

 - **com** (Array{Community}) Array where the communities are stored

# Constructors

    function CommunityInTime()

Instantiates an empty CommunityInTime folder.

# Base extended methods

    function Base.push!(com::CommunityInTime,c::Community)

Adds one Community element to the CommunityInTime object.

    function Base.length(com::CommunityInTime)

Returns the number of time points of the Community in time.

    function Base.getindex(com::CommunityInTime,var::Int)
    function Base.firstindex(com::CommunityInTime,var::Int)
    function Base.lastindex(com::CommunityInTime,var::Int)

Returns the Community of the corresponding entry.

    function Base.getindex(com::CommunityInTime,var::Symbol)

Returns a 2D array with rows being the agents and the rows the timepoints. If the agent did not existed for certain time point, the extry is filled with a NaN value.
"""
mutable struct CommunityInTime
    com::Array{Community,1}

    function CommunityInTime()
        
        return new(Community[])
    end
end

function Base.push!(comT::CommunityInTime,c::Community)
    
    push!(comtT.com,c)
    
    return
end

function Base.length(comT::CommunityInTime)
    
    return length(comtT.com)
end

function Base.getindex(comT::CommunityInTime,var::Int)
    
    return comtT.com[var]

end

Base.first(comT::CommunityInTime) = 1
Base.lastindex(comT::CommunityInTime) = length(comT)