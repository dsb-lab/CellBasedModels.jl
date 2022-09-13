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
    
    function Base.getindex(a::Community,var::Symbol)

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

    function Base.setindex!(a::Community,v::Array{<:AbstractFloat},var::Symbol)

Sets the values of a declared symbol to the values of the array v. The array has to be the same length as N.

Example
```@julia
 julia> community[:x] = [1.,2.];
 julia> community[:x]
 2-element Array{Float64,1}:
  1.0
  2.0
```

    function Base.setindex!(a::Community,v::Number,var::Symbol)

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
    N::Int
    NMedium
    declaredSymbols::DataFrame

end

function Community(abm::Agent; N::Int=1, NMedium::Array{Int,1}=Array{Int,1}([]))

    if sum(abm.declaredSymbols.type .== :Medium)
        if length(NMedium) != abm.dims
            error("NMedium has to be an array with the same length as AgentCompiled dimensions specifing the number of points in the grid.")
        end
    end

    dims = abm.dims
    N = N
    NMedium = NMedium

    return Community(
        dims,
        t,
        N,
        NMedium,
        simulationBox,
        radiusInteraction,
        declaredSymbols,
        loc,
        locInter,
        ids,
        idsInter,
        glob,
        globInter,
        globArray,
        medium
    )
end

function Base.show(io::IO,com::Community)
    print("PARAMETERS\n")
    for i in keys(com.declaredSymbols_)
        if ! isempty(com.declaredSymbols_[i])
            print(i,"\n\t")
            for j in com.declaredSymbols_[i]
                println(" ",j)
                println(" ",getproperty(com,j))
            end
            print("\n")
        end
    end
end

"""
Structure that basically stores an array of Coomunities at different time points.

# Elements

 - **com** (Array{Community}) Array where the communities are stored

# Constructors

    function CommunityInTime()

Instantiates an empty CommunityInTime folder.

# Base extended methods

    function Base.push!(a::CommunityInTime,c::Community)

Adds one Community element to the CommunityInTime object.

    function Base.length(a::CommunityInTime)

Returns the number of time points of the Community in time.

    function Base.getindex(a::CommunityInTime,var::Int)
    function Base.firstindex(a::CommunityInTime,var::Int)
    function Base.lastindex(a::CommunityInTime,var::Int)

Returns the Community of the corresponding entry.

    function Base.getindex(a::CommunityInTime,var::Symbol)

Returns a 2D array with rows being the agents and the rows the timepoints. If the agent did not existed for certain time point, the extry is filled with a NaN value.
"""
mutable struct CommunityInTime
    com::Array{Community,1}

    function CommunityInTime()
        
        return new(Community[])
    end
end

mutable struct CompiledCommunity
    #Compiled objects
    dt::AbstractFloat
    N::Int
    simulationBox::Array{<:AbstractFloat,2}
    radiusInteraction::Union{Real,Array{<:AbstractFloat,1}}
    NMedium::Array
    dxMedium::Array
    localV::Array
    localVCopy::Array
    localInteractionV::Array
    identityV::Array
    identityVCopy::Array
    globalV::Array
    globalVCopy::Array
    globalInteractionV::Array
    medium::Medium
    neighbors::Neighbors

    function CompiledCommunity(com::Community,agent::AgentCompiled,nMax::Int)

        #Make platform declarations

        dt = com.dt
        N = com.N
        simulationBox = ARRAY[agent.platform](FLOAT[agent.platform](com.simulationBox))
        radiusInteraction = ARRAY[agent.platform](FLOAT[agent.platform](com.radiusInteraction))

        localV = ARRAY[agent.platform](FLOAT[agent.platform].([com.local_;Base.zeros(nMax-N,length(agent.agent.declaredSymbols["Local"]))]))
        localVCopy = ZEROS[agent.platform](FLOAT[agent.platform],size(localV)[1],length(keys(agent.update["Local"])))
        localInteractionV = ARRAY[agent.platform](FLOAT[agent.platform].([com.localInteraction_;Base.zeros(nMax-N,length(agent.agent.declaredSymbols["LocalInteraction"]))]))
        identityV = ARRAY[agent.platform](int_.([com.identity_;Base.zeros(Int,nMax-N,length(agent.agent.declaredSymbols["Identity"]))]))
        identityVCopy = ZEROS[agent.platform](int_,size(identityV)[1],length(keys(agent.update["Identity"])))
        globalV = ARRAY[agent.platform](FLOAT[agent.platform].(com.global_))
        globalVCopy = ZEROS[agent.platform](FLOAT[agent.platform],length(agent.update["Global"]))
        globalInteractionV = ARRAY[agent.platform](FLOAT[agent.platform].(com.globalInteraction_))   

        medium = Medium(com.simulationBox,com.NMedium)
        neighbors = NEIGHBORS[agent.neighbors]

        new(            
            dt,
            N,
            simulationBox,
            radiusInteraction,
            localV,
            localVCopy,
            localInteractionV,
            identityV,
            identityVCopy,
            globalV,
            globalVCopy,
            globalInteractionV,
            medium,
            neighbors
        )

        return
    end
end