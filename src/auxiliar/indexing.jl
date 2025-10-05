# ===============================
# Morton (Z-order) encoders
# - CPU & GPU friendly (pure bit ops)
# - 0-based coordinates in, 0-based key out
# ===============================

# Spread bits of a 32-bit integer so there is 1 zero bit between them (→ 64-bit)
# Supports full 32 input bits (positions 0,2,4,...,62).
abstract type IndexingType end
abstract type LinearIndexing <: IndexingType end
abstract type MortonIndexing <: IndexingType end

@inline function _dilate1by1_32(x::UInt32)::UInt64
    v = UInt64(x)
    v = (v | (v << 16)) & 0x0000FFFF0000FFFF % UInt64
    v = (v | (v << 8))  & 0x00FF00FF00FF00FF % UInt64
    v = (v | (v << 4))  & 0x0F0F0F0F0F0F0F0F % UInt64
    v = (v | (v << 2))  & 0x3333333333333333 % UInt64
    v = (v | (v << 1))  & 0x5555555555555555 % UInt64
    return v
end

# Spread bits so there are 2 zero bits between them (→ 64-bit)
# Supports up to 21 input bits (positions 0,3,6,...,63).
@inline function _dilate1by2_64(x::UInt32)::UInt64
    v = UInt64(x)
    v = (v | (v << 32)) & 0x1F00000000FFFF % UInt64
    v = (v | (v << 16)) & 0x1F0000FF0000FF % UInt64
    v = (v | (v << 8))  & 0x100F00F00F00F00F % UInt64
    v = (v | (v << 4))  & 0x10C30C30C30C30C3 % UInt64
    v = (v | (v << 2))  & 0x1249249249249249 % UInt64
    return v
end

@inline function _undilate1by1_32(x::UInt64)::UInt32
    v = x & 0x5555555555555555 % UInt64
    v = (v ⊻ (v >> 1))  & 0x3333333333333333 % UInt64
    v = (v ⊻ (v >> 2))  & 0x0F0F0F0F0F0F0F0F % UInt64
    v = (v ⊻ (v >> 4))  & 0x00FF00FF00FF00FF % UInt64
    v = (v ⊻ (v >> 8))  & 0x0000FFFF0000FFFF % UInt64
    v = (v ⊻ (v >> 16)) & 0x00000000FFFFFFFF % UInt64
    return UInt32(v)
end

@inline function _undilate1by2_64(x::UInt64)::UInt32
    v = x & 0x1249249249249249 % UInt64
    v = (v ⊻ (v >> 2))  & 0x10C30C30C30C30C3 % UInt64
    v = (v ⊻ (v >> 4))  & 0x100F00F00F00F00F % UInt64
    v = (v ⊻ (v >> 8))  & 0x1F0000FF0000FF   % UInt64
    v = (v ⊻ (v >> 16)) & 0x1F00000000FFFF   % UInt64
    v = (v ⊻ (v >> 32)) & 0x00000000001FFFFF % UInt64  # 21 bits
    return UInt32(v)
end

# -------- 2D Morton key (0-based) --------
# Inputs: x,y are 0-based grid coordinates (UInt32)
# Output: 64-bit Morton code with x bits in even positions, y in odd positions
@inline function morton_encoded_u64(x::UInt32, y::UInt32)::UInt64
    return _dilate1by1_32(x) | (_dilate1by1_32(y) << 1)
end

# -------- 3D Morton key (0-based) --------
# Inputs: x,y,z are 0-based grid coordinates (UInt32), each must be < 2^21
# Output: 64-bit Morton code with x,y,z interleaved every 3 bits
@inline function morton_encoded_u64(x::UInt32, y::UInt32, z::UInt32)::UInt64
    return _dilate1by2_64(x) | (_dilate1by2_64(y) << 1) | (_dilate1by2_64(z) << 2)
end

@inline function morton_decode2d_u64(k::UInt64)::NTuple{2,UInt32}
    x = _undilate1by1_32(k)
    y = _undilate1by1_32(k >> 1)
    return (x, y)  # 0-based
end

@inline function morton_decode3d_u64(k::UInt64)::NTuple{3,UInt32}
    x = _undilate1by2_64(k)
    y = _undilate1by2_64(k >> 1)
    z = _undilate1by2_64(k >> 2)
    return (x, y, z)  # 0-based
end

# ===============================
# 1-based "linear index" wrappers (optional)
# These mirror LinearIndices but along the Morton curve.
# Safe to call on GPU if you pass plain integers (avoid CartesianIndex on device).
# ===============================

@inline function positionToCartesian2D(x, y, simBox::AbstractMatrix{<:Real}, edgeSize::AbstractVector{<:Real}, cellShape::Tuple{Int,Int})::Tuple{Int,Int}
    idx = clamp(floor((x - simBox[:, 1]) / edgeSize) + 1, 1, cellShape[1])
    idy = clamp(floor((y - simBox[:, 1]) / edgeSize) + 1, 1, cellShape[2])
    return (Int(idx), Int(idy))
end

@inline function positionToCartesian3D(x, y, z, simBox::AbstractMatrix{<:Real}, edgeSize::AbstractVector{<:Real}, cellShape::Tuple{Int,Int,Int})::NTuple{3,Int}
    idx = clamp(floor((x - simBox[:, 1]) / edgeSize) + 1, 1, cellShape[1])
    idy = clamp(floor((y - simBox[:, 1]) / edgeSize) + 1, 1, cellShape[2])
    idz = clamp(floor((z - simBox[:, 1]) / edgeSize) + 1, 1, cellShape[3])
    return (Int(idx), Int(idy), Int(idz))
end

@inline function cartesianToLinear2D(dims::Int, shape::Tuple{Int,Int})::Int
    return dims[1] + (dims[2]-1)*shape[1]
end

@inline function cartesianToLinear3D(dims::Int, shape::Tuple{Int,Int,Int})::Int
    return dims[1] + (dims[2]-1)*shape[1] + (dims[3]-1)*shape[1]*shape[2]
end

@inline function linearToCartesian2D(idx::Int, shape::Tuple{Int,Int})::Tuple{Int,Int}
    y = (idx - 1) ÷ shape[1] + 1
    x = idx - (y - 1)*shape[1]
    return (x, y)
end

@inline function linearToCartesian3D(idx::Int, shape::Tuple{Int,Int,Int})::NTuple{3,Int}
    z = (idx - 1) ÷ (shape[1]*shape[2]) + 1
    y = ((idx - 1) ÷ shape[1]) % shape[2] + 1
    x = idx - (y - 1)*shape[1] - (z - 1)*shape[1]*shape[2]
    return (x, y, z)
end

# 2D: (ix,iy) are 1-based; returns 1-based Morton "linear" rank
@inline function cartesianToMorton2D(ix::Int, iy::Int)::Int
    k = morton_encoded_u64(UInt32(ix-1), UInt32(iy-1))
    return Int(k) + 1
end

# 3D: (ix,iy,iz) are 1-based; returns 1-based Morton "linear" rank
@inline function cartesianToMorton3D(ix::Int, iy::Int, iz::Int)::Int
    # NOTE: ensure each coord ≤ 2^21 (≈ 2,097,152) if you need full correctness
    k = morton_encoded_u64(UInt32(ix-1), UInt32(iy-1), UInt32(iz-1))
    return Int(k) + 1
end

@inline function mortonToCartesian2D(idx::Int)::Tuple{Int,Int}
    k = UInt64(idx - 1)            # 0-based key
    x0, y0 = morton_decode2d_u64(k)
    return (Int(x0) + 1, Int(y0) + 1)
end

@inline function mortonToCartesian3D(idx::Int)::NTuple{3,Int}
    k = UInt64(idx - 1)            # 0-based key
    x0, y0, z0 = morton_decode3d_u64(k)
    return (Int(x0) + 1, Int(y0) + 1, Int(z0) + 1)
end

# 2D: Cartesian neighbors (1-based coords), includes center; OOB -> (-1,-1)
@inline function cartesianNeighbors2D(ix::Int, iy::Int, shape::Tuple{Int,Int})::NTuple{9,Tuple{Int,Int}}
    offsets = ((-1,-1),(0,-1),(1,-1),
               (-1, 0),(0, 0),(1, 0),
               (-1, 1),(0, 1),(1, 1))
    return ntuple(i -> begin
        dx, dy = offsets[i]
        x = ix + dx; y = iy + dy
        (1 ≤ x ≤ shape[1] && 1 ≤ y ≤ shape[2]) ? (x, y) : (-1, -1)
    end, 9)
end

# 3D: Cartesian neighbors (1-based coords), includes center; OOB -> (-1,-1,-1)
@inline function cartesianNeighbors3D(ix::Int, iy::Int, iz::Int, shape::Tuple{Int,Int,Int})::NTuple{27,NTuple{3,Int}}
    return ntuple(k -> begin
        kk = k - 1
        dx = (kk % 3) - 1
        dy = ((kk ÷ 3) % 3) - 1
        dz = ((kk ÷ 9) % 3) - 1
        x = ix + dx; y = iy + dy; z = iz + dz
        (1 ≤ x ≤ shape[1] && 1 ≤ y ≤ shape[2] && 1 ≤ z ≤ shape[3]) ? (x, y, z) : (-1, -1, -1)
    end, 27)
end

@inline function linearNeighbors2D(idx::Int, shape::Tuple{Int,Int})::NTuple{9,Int}
    x, y = mortonToCartesian2D(idx)  # 1-based cartesian coords
    # fixed 3x3 order: (-1,-1) .. (1,1)
    offsets = ((-1,-1),(0,-1),(1,-1),
               (-1, 0),(0, 0),(1, 0),
               (-1, 1),(0, 1),(1, 1))
    return ntuple(i -> begin
        dx, dy = offsets[i]
        xi = x + dx; yi = y + dy
        (1 ≤ xi ≤ shape[1] && 1 ≤ yi ≤ shape[2]) ? cartesianToLinear2D(xi, yi) : -1
    end, 9)
end

# 3D: Morton neighbors (1-based Morton ranks), includes center
@inline function linearNeighbors3D(idx::Int, shape::Tuple{Int,Int,Int})::NTuple{27,Int}
    x, y, z = mortonToCartesian3D(idx)
    # fixed 3x3x3 order: z-major, then y, then x
    return ntuple(k -> begin
        # map k ∈ 1..27 to (dx,dy,dz) ∈ {-1,0,1}^3
        kk = k - 1
        dx = (kk % 3) - 1
        dy = ((kk ÷ 3) % 3) - 1
        dz = ((kk ÷ 9) % 3) - 1
        xi = x + dx; yi = y + dy; zi = z + dz
        (1 ≤ xi ≤ shape[1] && 1 ≤ yi ≤ shape[2] && 1 ≤ zi ≤ shape[3]) ?
            cartesianToLinear3D(xi, yi, zi) : -1
    end, 27)
end

# 2D: Morton neighbors (1-based Morton ranks), includes center at position 5
@inline function mortonNeighbors2D(idx::Int, shape::Tuple{Int,Int})::NTuple{9,Int}
    x, y = mortonToCartesian2D(idx)  # 1-based cartesian coords
    # fixed 3x3 order: (-1,-1) .. (1,1)
    offsets = ((-1,-1),(0,-1),(1,-1),
               (-1, 0),(0, 0),(1, 0),
               (-1, 1),(0, 1),(1, 1))
    return ntuple(i -> begin
        dx, dy = offsets[i]
        xi = x + dx; yi = y + dy
        (1 ≤ xi ≤ shape[1] && 1 ≤ yi ≤ shape[2]) ? cartesianToMorton2D(xi, yi) : -1
    end, 9)
end

# 3D: Morton neighbors (1-based Morton ranks), includes center
@inline function mortonNeighbors3D(idx::Int, shape::Tuple{Int,Int,Int})::NTuple{27,Int}
    x, y, z = mortonToCartesian3D(idx)
    # fixed 3x3x3 order: z-major, then y, then x
    return ntuple(k -> begin
        # map k ∈ 1..27 to (dx,dy,dz) ∈ {-1,0,1}^3
        kk = k - 1
        dx = (kk % 3) - 1
        dy = ((kk ÷ 3) % 3) - 1
        dz = ((kk ÷ 9) % 3) - 1
        xi = x + dx; yi = y + dy; zi = z + dz
        (1 ≤ xi ≤ shape[1] && 1 ≤ yi ≤ shape[2] && 1 ≤ zi ≤ shape[3]) ?
            cartesianToMorton3D(xi, yi, zi) : -1
    end, 27)
end
