macro cross(v1x, v1y, v2x, v2y)
    :($(esc(v1x))*$(esc(v2y)) - $(esc(v1y))*$(esc(v2x)))
end

macro cross(v1x, v1y, v1z, v2x, v2y, v2z)
    :((
        $(esc(v1y))*$(esc(v2z)) - $(esc(v1z))*$(esc(v2y)),
        $(esc(v1z))*$(esc(v2x)) - $(esc(v1x))*$(esc(v2z)),
        $(esc(v1x))*$(esc(v2y)) - $(esc(v1y))*$(esc(v2x))
    ))
end

macro dot(v1x, v1y, v2x, v2y)
    :($(esc(v1x))*$(esc(v2x)) + $(esc(v1y))*$(esc(v2y)))
end

macro dot(v1x, v1y, v1z, v2x, v2y, v2z)
    :($(esc(v1x))*$(esc(v2x)) + $(esc(v1y))*$(esc(v2y)) + $(esc(v1z))*$(esc(v2z)))
end

macro norm(v1x, v1y)
    :(sqrt($(esc(v1x))^2 + $(esc(v1y))^2))
end

macro norm(v1x, v1y, v1z)
    :(sqrt($(esc(v1x))^2 + $(esc(v1y))^2 + $(esc(v1z))^2))
end

macro normSquared(v1x, v1y)
    :($(esc(v1x))^2 + $(esc(v1y))^2)
end

macro normSquared(v1x, v1y, v1z)
    :($(esc(v1x))^2 + $(esc(v1y))^2 + $(esc(v1z))^2)
end

macro normalize(v1x, v1y)
    :((
        $(esc(v1x)) / sqrt($(esc(v1x))^2 + $(esc(v1y))^2),
        $(esc(v1y)) / sqrt($(esc(v1x))^2 + $(esc(v1y))^2)
    ))
end

macro normalize(v1x, v1y, v1z)
    :((
        $(esc(v1x)) / sqrt($(esc(v1x))^2 + $(esc(v1y))^2 + $(esc(v1z))^2),
        $(esc(v1y)) / sqrt($(esc(v1x))^2 + $(esc(v1y))^2 + $(esc(v1z))^2),
        $(esc(v1z)) / sqrt($(esc(v1x))^2 + $(esc(v1y))^2 + $(esc(v1z))^2),
    ))
end