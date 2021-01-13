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