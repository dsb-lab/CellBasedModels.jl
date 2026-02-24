module Algebra

export @dot, @cross, @norm, @normSquared, @normalize

macro cross(v1x, v1y, v2x, v2y)
    return v1x*v2y - v1y*v2x
end

macro cross(v1x, v1y, v1z, v2x, v2y, v2z)
    return (
        v1y*v2z - v1z*v2y,
        v1z*v2x - v1x*v2z,
        v1x*v2y - v1y*v2x
    )
end

macro dot(v1x, v1y, v2x, v2y)
    return v1x*v2x + v1y*v2y
end

macro dot(v1x, v1y, v1z, v2x, v2y, v2z)
    return v1x*v2x + v1y*v2y + v1z*v2z
end

macro norm(v1x, v1y)

    return sqrt(v1x^2 + v1y^2)

end

macro norm(v1x, v1y, v1z)

    return sqrt(v1x^2 + v1y^2 + v1z^2)

end

macro normSquared(v1x, v1y)

    return v1x^2 + v1y^2

end

macro normSquared(v1x, v1y, v1z)

    return v1x^2 + v1y^2 + v1z^2

end

macro normalize(v1x, v1y)

    return (
        v1x / sqrt(v1x^2 + v1y^2),
        v1y / sqrt(v1x^2 + v1y^2)
    )

end

macro normalize(v1x, v1y, v1z)

    return (
        v1x / sqrt(v1x^2 + v1y^2 + v1z^2),
        v1y / sqrt(v1x^2 + v1y^2 + v1z^2),
        v1z / sqrt(v1x^2 + v1y^2 + v1z^2),
    )

end

end