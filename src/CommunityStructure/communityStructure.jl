"""
Basic structure keeping the parameters of all the agents in the current simulation of a model.

# Elements

 - **t**::AbstractFloat Time of the community
 - **N**::Int Number of particles in the community
 - **declaredSymb**::Dict{String,Array{Symbol}} Dictionary storing the names of all the parameters declared in model according to the respective fields where they have been declared.
 - **var**::Array{<:AbstractFloat,2} 2D Array with all the agents in rows and all the corresponding values of the variables in columns.
 - **inter**::Array{<:AbstractFloat,2} 2D Array with all the agents in rows and all the corresponding values of the interaction parameters in columns.
 - **loc**::Array{<:AbstractFloat,2} 2D Array with all the agents in rows and all the corresponding values of the local parameters in columns.
 - **locInter**::Array{<:AbstractFloat,2} 2D Array with all the agents in rows and all the corresponding values of the local interaction parameters in columns.
 - **glob**::Array{<:AbstractFloat,1} 1D Array with all the corresponding values of the global parameters in rows.
 - **globInter**::Array{<:AbstractFloat,1} 1D Array with all the corresponding values of the global interaction parameters in rows.
 - **globArray**::Array{Array{AbstractFloat},1} 1D Array with all the corresponding global arrays in rows.
 - **ids**::Array{Int,2} 2D Array with all the agents in rows and all the corresponding values of the identities in columns

# Constructors

    function Community(abm::AgentCompiled; N::Int=1, t::AbstractFloat=0.)

### Arguments
 - **abm** (AgentCompiled) AgentCompiled structure

### Additional keyword arguments
 - **N::Int** Number of Agent with wich start the model. N=1 by default.
 - **t::AbstractFloat** Time of the community at creation. t=1. by default
 - **NMedium::Array{Int,1}** Size of the medium grid. (Default [])

### Example
```@julia
 julia> model = AgentCompiled();
 julia> addLocal!(model,:x);
 julia> community = Community(model, N=2, t=0.5)
 Community(0.5, 2, Dict{String,Array{Symbol,N} where N}("glob" => [],"ids" => [],"locInter" => [],"loc" => [:x],"inter" => [],"var" => []), Array{AbstractFloat}(undef,2,0), Array{AbstractFloat}(undef,2,0), AbstractFloat[0.0; 0.0], AbstractFloat[0.0; 0.0], AbstractFloat[], Array{Int64}(undef,2,0))
 julia> community.N
 2
 julia> community.t
 0.5
 julia> community.declaredSymb
 Dict{String,Array{Symbol,N} where N} with 6 entries:
   "glob"     => Symbol[]
   "ids"      => Symbol[]
   "locInter" => Symbol[]
   "loc"      => [:x]
   "inter"    => Symbol[]
   "var"      => Symbol[]
``` 

# Base extended methods

In addition for directly accessing the elements of the structure, the following methods from the Base Package has been extended to access the elements of the Community.
    
    function Base.getindex(com::Community,var::Symbol)

Returns an array with all the values of the declared symbol for all the agents.

Example
```julia
 julia> model.N
 2
 julia> community.declaredSymbols["loc"]
 1-element Array{Symbol,1}:
 :x
 julia> community[:x]
 2-element Array{<:AbstractFloat,1}:
  0.0
  0.0
```

    function Base.setindex!(com::Community,v::Array{<:AbstractFloat},var::Symbol)

Sets the values of a declared symbol to the values of the array v. The array has to be the same length as N.

Example
```@julia
 julia> community[:x] = [1.,2.];
 julia> community[:x]
 2-element Array{Float64,1}:
  1.0
  2.0
```

    function Base.setindex!(com::Community,v::Number,var::Symbol)

Sets the values of a declared symbol to the given value v.

Example
```@julia
julia> community[:x] = 2.;
julia> community[:x]
2-element Array{Float64,1}:
 2.0
 2.0
```
"""
mutable struct Community

    dims::Int
    platform::Tuple{Symbol,Symbol}
    nMax::Int
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
        nMax = N
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
            else
                error("Parameter type $(prop[2]) from symbol $sym is not defined.")
            end
        
        end
        values[:N] .= N
    
        return new(dims,platform,nMax,declaredSymbols,values)
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
            com.values[sym] = ARRAY[com.platform[1]](zeros(dtype,com.nMax[1],com.nMaxNeighbors[1]))
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
        else
            error("Parameter type ",prop[2], " is not defined.")
        end
    end            

    com.platform = (com.platform[1],com.platform[1])

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