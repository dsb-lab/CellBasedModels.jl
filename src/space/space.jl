abstract type Space end

struct Free <:Space

end

struct Line <:Space
    var<:Boundary
end

struct Square <:Space
    var1<:Boundary
    var2<:Boundary
end

struct Cube <:Space
    var1<:Boundary
    var2<:Boundary
    var3<:Boundary
end