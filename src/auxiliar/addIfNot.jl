"""
Add an element if it is not present in an Array

# Arguments
 - **container** (Array) Container where to introduce the elements
 - **object** (Any or Array{Any}) Array of elements

# Returns

nothing
"""
function addIfNot!(container,object)

    if !(object in container)
        push!(container, object)
    end

    return
end

function addIfNot!(container,object::Array)

    for i in object
        addIfNot!(container, i)
    end

    return
end