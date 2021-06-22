"""
Basic structure keeping the parameters of all the agents in the current simulation of a model.

# Elements

 - **t**::AbstractFloat Time of the community
 - **N**::Int Number of particles in the community
 - **declaredSymb**::Dict{String,Array{Symbol}} Dictionary storing the names of all the parameters declared in model according to the respective fields where they have been declared.
 - **var**::Array{AbstractFloat,2} 2D Array with all the agents in rows and all the corresponding values of the variables in columns.
 - **inter**::Array{AbstractFloat,2} 2D Array with all the agents in rows and all the corresponding values of the interaction parameters in columns.
 - **loc**::Array{AbstractFloat,2} 2D Array with all the agents in rows and all the corresponding values of the local parameters in columns.
 - **locInter**::Array{AbstractFloat,2} 2D Array with all the agents in rows and all the corresponding values of the local interaction parameters in columns.
 - **glob**::Array{AbstractFloat,1} 1D Array with all the corresponding values of the global parameters in rows.
 - **globArray**::Array{Array{AbstractFloat},1} 1D Array with all the corresponding global arrays in rows.
 - **ids**::Array{Int,2} 2D Array with all the agents in rows and all the corresponding values of the identities in columns

# Constructors

    function Community(abm::Model; N::Int=1, t::AbstractFloat=0.)

### Arguments
 - **abm** (Model) Agent Model structure

### Additional keyword arguments
 - **N** (Int) Number of Agent with wich start the model. N=1 by default.
 - **t** (AbstractFloat) Time of the community at creation. t=1. by default

### Example
```@julia
 julia> model = Model();
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
 2-element Array{AbstractFloat,1}:
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
    t::AbstractFloat
    N::Int
    declaredSymbols_::Dict{String,Array{Symbol}}
    local_::Array{Float64,2}
    identity_::Array{Int,2}
    global_::Array{Float64,1}
    globalArray_::Array{Array{Float64},1}
end

function Community(abm::Model; N::Int=1, t::AbstractFloat=0.)

    loc = zeros(Float64,N,length(abm.agent.declaredSymbols["Local"]))
    ids = ones(Int,N,length(abm.agent.declaredSymbols["Identity"]))
    ids[:,1] .= 1:N
    glob = zeros(Float64,length(abm.agent.declaredSymbols["Global"]))
    globArray = []
    for i in abm.agent.declaredSymbols["GlobalArray"]
        push!(globArray,[])
    end

    declaredSymbols = abm.agent.declaredSymbols

    return Community(t,N,declaredSymbols,loc,ids,glob,globArray)
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