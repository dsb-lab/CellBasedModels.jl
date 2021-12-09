"""
Remove all points that are not inside a specified volume.

# Arguments
 - **xyz** (Array{Array{Any}}) Array containing all the list of position parameters.
 - **f** (Function) Function that returns true if the position is inside the volume.
 
# Returns
Array{Array{Any}} Extruded points.
"""
function extrude(xyz,f::Function)
    l = f(xyz...)
    xyzAux = []
    for i in xyz
        push!(xyzAux,copy(i[l]))
    end

    return xyzAux
end

"""
Remove all points that are not inside a specified volume.

# Arguments
 - **com** (Community) Community to extrude.
 - **f** (Function) Function that returns true if the position is inside the volume.
 
# Returns
nothing
"""
function extrude!(com::Community,f::Function)

    x = com.loc[:,1:com.dims]
    l = f(x)

    if size(com.var)[2] > 0
        com.var = com.var[l,:]
    end
    if size(com.inter)[2] > 0
        com.inter = com.inter[l,:]
    end
    if size(com.loc)[2] > 0
        com.loc = com.loc[l,:]
    end
    if size(com.locInter)[2] > 0
        com.locInter = com.locInter[l,:]
    end
    if size(com.ids)[2] > 0
        com.ids = com.ids[l,:]
    end
    com.N = sum(l)

    return 
end