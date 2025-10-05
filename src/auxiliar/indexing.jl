########################################################################################
#
# Abstract types for indexing strategies
#
########################################################################################

"""
    IndexingType

Abstract supertype for indexing strategies used in this module.
"""
abstract type IndexingType end

"""
    LinearIndexing <: IndexingType

Marker type for conventional row-major linear indexing (no Morton/Z-ordering).
"""
abstract type LinearIndexing <: IndexingType end

"""
    MortonIndexing <: IndexingType

Marker type for Morton (Z-order) indexing.
"""
abstract type MortonIndexing <: IndexingType end

########################################################################################
#
# Auxiliary functions for Morton (Z-order) indexing
#
########################################################################################

"""
    _dilate1by1_32(x::UInt32) -> UInt64

Bit-dilation helper for 2D Morton encoding. Spreads each bit of a 32-bit
integer so there is **one zero bit** between consecutive source bits.
The result fits in 64 bits with input bits occupying even positions
(0,2,4,…,62).

# Arguments
- `x::UInt32`: 32-bit input value.

# Returns
- `UInt64`: Dilated bit pattern.

# Notes
- Pure bitwise operations, branch-free; suitable for CPU & GPU.
- Supports all 32 input bits.
"""
@inline function _dilate1by1_32(x::UInt32)::UInt64
    v = UInt64(x)
    v = (v | (v << 16)) & 0x0000FFFF0000FFFF % UInt64
    v = (v | (v << 8))  & 0x00FF00FF00FF00FF % UInt64
    v = (v | (v << 4))  & 0x0F0F0F0F0F0F0F0F % UInt64
    v = (v | (v << 2))  & 0x3333333333333333 % UInt64
    v = (v | (v << 1))  & 0x5555555555555555 % UInt64
    return v
end

"""
    _undilate1by1_32(x::UInt64) -> UInt32

Inverse of [`_dilate1by1_32`] for 2D Morton keys. Compacts bits from even
positions (0,2,4,…,62) of `x` into a 32-bit integer.

# Arguments
- `x::UInt64`: 64-bit value with data in even bit positions.

# Returns
- `UInt32`: Compacted 32-bit value.
"""
@inline function _undilate1by1_32(x::UInt64)::UInt32
    v = x & 0x5555555555555555 % UInt64
    v = (v ⊻ (v >> 1))  & 0x3333333333333333 % UInt64
    v = (v ⊻ (v >> 2))  & 0x0F0F0F0F0F0F0F0F % UInt64
    v = (v ⊻ (v >> 4))  & 0x00FF00FF00FF00FF % UInt64
    v = (v ⊻ (v >> 8))  & 0x0000FFFF0000FFFF % UInt64
    v = (v ⊻ (v >> 16)) & 0x00000000FFFFFFFF % UInt64
    return UInt32(v)
end

"""
    _dilate1by2_64(x::UInt32) -> UInt64

Bit-dilation helper for 3D Morton encoding. Spreads each bit of a 32-bit
integer so there are **two zero bits** between consecutive source bits.
This supports up to 21 input bits which fit in 64-bit output at positions
0,3,6,…,63.

# Arguments
- `x::UInt32`: 32-bit input value (only the lowest 21 bits are represented in the output).

# Returns
- `UInt64`: Dilated bit pattern.

# Notes
- Pure bitwise operations, branch-free; suitable for CPU & GPU.
- If `x ≥ 2^21`, the upper bits are effectively dropped by the bitmasking.
"""
@inline function _dilate1by2_64(x::UInt32)::UInt64
    v = UInt64(x)
    v = (v | (v << 32)) & 0x1F00000000FFFF % UInt64
    v = (v | (v << 16)) & 0x1F0000FF0000FF % UInt64
    v = (v | (v << 8))  & 0x100F00F00F00F00F % UInt64
    v = (v | (v << 4))  & 0x10C30C30C30C30C3 % UInt64
    v = (v | (v << 2))  & 0x1249249249249249 % UInt64
    return v
end

"""
    _undilate1by2_64(x::UInt64) -> UInt32

Inverse of [`_dilate1by2_64`] for 3D Morton keys. Compacts bits from positions
0,3,6,…,63 of `x` into a 21-bit `UInt32`.

# Arguments
- `x::UInt64`: 64-bit value with data in every 3rd bit starting at 0.

# Returns
- `UInt32`: Compacted value (lower 21 bits significant).
"""
@inline function _undilate1by2_64(x::UInt64)::UInt32
    v = x & 0x1249249249249249 % UInt64
    v = (v ⊻ (v >> 2))  & 0x10C30C30C30C30C3 % UInt64
    v = (v ⊻ (v >> 4))  & 0x100F00F00F00F00F % UInt64
    v = (v ⊻ (v >> 8))  & 0x1F0000FF0000FF   % UInt64
    v = (v ⊻ (v >> 16)) & 0x1F00000000FFFF   % UInt64
    v = (v ⊻ (v >> 32)) & 0x00000000001FFFFF % UInt64  # 21 bits
    return UInt32(v)
end

"""
    cartesianToMortonU64(x::UInt32, y::UInt32) -> UInt64

Encodes 2D 0-based coordinates `(x, y)` into a 64-bit Morton (Z-order) key.
`x` bits go to even positions and `y` bits to odd positions.

# Arguments
- `x::UInt32`: 0-based x coordinate.
- `y::UInt32`: 0-based y coordinate.

# Returns
- `UInt64`: Morton key.

# See also
- [`mortonU64ToCartesian2D`] for the inverse.
"""
@inline function cartesianToMortonU64(x::UInt32, y::UInt32)::UInt64
    return _dilate1by1_32(x) | (_dilate1by1_32(y) << 1)
end

"""
    cartesianToMortonU64(x::UInt32, y::UInt32, z::UInt32) -> UInt64

Encodes 3D 0-based coordinates `(x, y, z)` into a 64-bit Morton (Z-order)
key with bits interleaved every 3 positions.

# Arguments
- `x::UInt32`: 0-based x (must be `< 2^21` for full correctness).
- `y::UInt32`: 0-based y (must be `< 2^21` for full correctness).
- `z::UInt32`: 0-based z (must be `< 2^21` for full correctness).

# Returns
- `UInt64`: Morton key.

# See also
- [`mortonU64ToCartesian3D`] for the inverse.
"""
@inline function cartesianToMortonU64(x::UInt32, y::UInt32, z::UInt32)::UInt64
    return _dilate1by2_64(x) | (_dilate1by2_64(y) << 1) | (_dilate1by2_64(z) << 2)
end

"""
    mortonU64ToCartesian2D(k::UInt64) -> NTuple{2,UInt32}

Decodes a 64-bit 2D Morton key into its 0-based `(x, y)` coordinates.

# Arguments
- `k::UInt64`: Morton key produced by [`cartesianToMortonU64(x,y)`] (2-arg).

# Returns
- `(x::UInt32, y::UInt32)`: 0-based coordinates.
"""
@inline function mortonU64ToCartesian2D(k::UInt64)::NTuple{2,UInt32}
    x = _undilate1by1_32(k)
    y = _undilate1by1_32(k >> 1)
    return (x, y)  # 0-based
end

"""
    mortonU64ToCartesian3D(k::UInt64) -> NTuple{3,UInt32}

Decodes a 64-bit 3D Morton key into its 0-based `(x, y, z)` coordinates.

# Arguments
- `k::UInt64`: Morton key produced by [`cartesianToMortonU64(x,y,z)`] (3-arg).

# Returns
- `(x::UInt32, y::UInt32, z::UInt32)`: 0-based coordinates.
"""
@inline function mortonU64ToCartesian3D(k::UInt64)::NTuple{3,UInt32}
    x = _undilate1by2_64(k)
    y = _undilate1by2_64(k >> 1)
    z = _undilate1by2_64(k >> 2)
    return (x, y, z)  # 0-based
end

########################################################################################
#
# Indexing Functions
#
########################################################################################

"""
    positionToCartesian2D(pos::Tuple{<:Real, <:Real}, simBox::AbstractMatrix{<:Real}, edgeSize::Tuple{<:Real, <:Real}, cellShape::Tuple{Int,Int}) -> (ix::Int, iy::Int)

Maps a continuous 2D position `(x, y)` into 1-based integer cell indices
within a simulation box.

# Arguments
- `pos`::Tuple{<:Real, <:Real}: Coordinates `(x, y)``.
- `simBox::AbstractMatrix{<:Real}`: Box bounds, where `simBox[:, 1]` is the lower bound per axis and `simBox[:, 2]` is the upper bound.
- `edgeSize::Tuple{<:Real, <:Real}`: Cell edge sizes per axis.
- `cellShape::Tuple{Int,Int}`: Number of cells `(nx, ny)`.

# Returns
- `(ix::Int, iy::Int)`: 1-based clamped cell indices.

# Notes
- Uses `floor((coord - lower)/edge) + 1`, then clamps to `1:n`.
"""
@inline function positionToCartesian2D(pos::Tuple{<:Real, <:Real}, simBox::AbstractMatrix{<:Real}, edgeSize::Tuple{<:Real, <:Real}, cellShape::Tuple{Int,Int})::Tuple{Int,Int}
    idx = clamp(floor((pos[1] - simBox[1, 1]) / edgeSize[1]) + 1, 1, cellShape[1])
    idy = clamp(floor((pos[2] - simBox[2, 1]) / edgeSize[2]) + 1, 1, cellShape[2])
    return (Int(idx), Int(idy))
end

"""
    positionToCartesian3D(pos::Tuple{<:Real, <:Real, <:Real}, simBox::AbstractMatrix{<:Real}, edgeSize::Tuple{<:Real, <:Real, <:Real}, cellShape::Tuple{Int,Int,Int}) -> NTuple{3,Int}

Maps a continuous 3D position `(x, y, z)` into 1-based integer cell indices
within a 3D simulation box.

# Arguments
- `pos`::Tuple{<:Real, <:Real, <:Real}: Coordinates `(x, y, z)`.
- `simBox::AbstractMatrix{<:Real}`: Box bounds, where `simBox[:, 1]` is the lower bound per axis and `simBox[:, 2]` is the upper bound.
- `edgeSize::Tuple{<:Real, <:Real, <:Real}`: Cell edge sizes per axis.
- `cellShape::Tuple{Int,Int,Int}`: Number of cells `(nx, ny, nz)`.

# Returns
- `(ix::Int, iy::Int, iz::Int)`: 1-based clamped cell indices.
"""
@inline function positionToCartesian3D(pos::Tuple{<:Real, <:Real, <:Real}, simBox::AbstractMatrix{<:Real}, edgeSize::Tuple{<:Real, <:Real, <:Real}, cellShape::Tuple{Int,Int,Int})::NTuple{3,Int}
    idx = clamp(floor((pos[1] - simBox[1, 1]) / edgeSize[1]) + 1, 1, cellShape[1])
    idy = clamp(floor((pos[2] - simBox[2, 1]) / edgeSize[2]) + 1, 1, cellShape[2])
    idz = clamp(floor((pos[3] - simBox[3, 1]) / edgeSize[3]) + 1, 1, cellShape[3])
    return (Int(idx), Int(idy), Int(idz))
end

"""
    cartesianToLinear2D(pos::Tuple{Int,Int}, shape::Tuple{Int,Int}) -> Int

Converts cartesian indices to a 1-based linear index assuming
row-major layout.

# Arguments
- `pos::Tuple{Int,Int}`: Cartesian coordinates `(ix, iy)`.
- `shape::Tuple{Int,Int}`: Array shape `(nx, ny)`.

# Returns
- `Int`: Linear index `ix + (iy-1)*nx`.
"""
@inline function cartesianToLinear2D(pos::Tuple{Int,Int}, shape::Tuple{Int,Int})::Int
    return pos[1] + (pos[2]-1)*shape[1]
end

"""
    cartesianToLinear3D(pos::Tuple{Int,Int,Int}, shape::Tuple{Int,Int,Int}) -> Int

Converts 1-based Cartesian indices to a 1-based linear index with row-major
layout in 3D.

# Arguments
- `pos::Tuple{Int,Int,Int}`: Cartesian coordinates `(ix, iy, iz)`.
- `shape::Tuple{Int,Int,Int}`: Array shape `(nx, ny, nz)`.

# Returns
- `Int`: Linear index `ix + (iy-1)*nx + (iz-1)*nx*ny`.
"""
@inline function cartesianToLinear3D(pos::Tuple{Int,Int,Int}, shape::Tuple{Int,Int,Int})::Int
    return pos[1] + (pos[2]-1)*shape[1] + (pos[3]-1)*shape[1]*shape[2]
end

"""
    linearToCartesian2D(idx::Int, shape::Tuple{Int,Int}) -> (ix::Int, iy::Int)

Inverse of [`cartesianToLinear2D`]. Converts a 1-based linear index back
to 1-based Cartesian `(ix, iy)`.

# Arguments
- `idx::Int`: 1-based linear index.
- `shape::Tuple{Int,Int}`: Array shape `(nx, ny)`.

# Returns
- `(ix::Int, iy::Int)`: 1-based Cartesian indices.
"""
@inline function linearToCartesian2D(idx::Int, shape::Tuple{Int,Int})::Tuple{Int,Int}
    y = (idx - 1) ÷ shape[1] + 1
    x = idx - (y - 1)*shape[1]
    return (x, y)
end

"""
    linearToCartesian3D(idx::Int, shape::Tuple{Int,Int,Int}) -> (ix::Int, iy::Int, iz::Int)

Inverse of [`cartesianToLinear3D`]. Converts a 1-based linear index back
to 1-based Cartesian `(ix, iy, iz)`.

# Arguments
- `idx::Int`: 1-based linear index.
- `shape::Tuple{Int,Int,Int}`: Array shape `(nx, ny, nz)`.

# Returns
- `(ix::Int, iy::Int, iz::Int)`: 1-based Cartesian indices.
"""
@inline function linearToCartesian3D(idx::Int, shape::Tuple{Int,Int,Int})::NTuple{3,Int}
    z = (idx - 1) ÷ (shape[1]*shape[2]) + 1
    y = ((idx - 1) ÷ shape[1]) % shape[2] + 1
    x = idx - (y - 1)*shape[1] - (z - 1)*shape[1]*shape[2]
    return (x, y, z)
end

"""
    cartesianToMorton2D(pos::Tuple{Int,Int}) -> Int

Maps 1-based Cartesian `(ix, iy)` to a **1-based** Morton rank.

# Arguments
- `pos::Tuple{Int,Int}`: cartesian coordinates.

# Returns
- `Int`: 1-based Morton rank (`morton(key) + 1`).

# Notes
- Internally converts to 0-based, encodes, then adds 1.
"""
@inline function cartesianToMorton2D(pos::Tuple{Int,Int})::Int
    k = cartesianToMortonU64(UInt32(pos[1]-1), UInt32(pos[2]-1))
    return Int(k) + 1
end

"""
    cartesianToMorton3D(pos::Tuple{Int,Int,Int}) -> Int

Maps 1-based Cartesian `(ix, iy, iz)` to a **1-based** Morton rank.

# Arguments
- `pos::Tuple{Int,Int,Int}`: 1-based coordinates (each should be `≤ 2^21` for full correctness).

# Returns
- `Int`: 1-based Morton rank.

# Notes
- Internally converts to 0-based, encodes, then adds 1.
"""
@inline function cartesianToMorton3D(pos::Tuple{Int,Int,Int})::Int
    # NOTE: ensure each coord ≤ 2^21 (≈ 2,097,152) if you need full correctness
    k = cartesianToMortonU64(UInt32(pos[1]-1), UInt32(pos[2]-1), UInt32(pos[3]-1))
    return Int(k) + 1
end

"""
    mortonToCartesian2D(idx::Int) -> (ix::Int, iy::Int)

Inverse of [`cartesianToMorton2D`]. Converts a **1-based** Morton rank
to 1-based Cartesian indices.

# Arguments
- `idx::Int`: 1-based Morton rank.

# Returns
- `(ix::Int, iy::Int)`: 1-based Cartesian indices.
"""
@inline function mortonToCartesian2D(idx::Int)::Tuple{Int,Int}
    k = UInt64(idx - 1)            # 0-based key
    x0, y0 = mortonU64ToCartesian2D(k)
    return (Int(x0) + 1, Int(y0) + 1)
end

"""
    mortonToCartesian3D(idx::Int) -> (ix::Int, iy::Int, iz::Int)

Inverse of [`cartesianToMorton3D`]. Converts a **1-based** Morton rank
to 1-based Cartesian indices.

# Arguments
- `idx::Int`: 1-based Morton rank.

# Returns
- `(ix::Int, iy::Int, iz::Int)`: 1-based Cartesian indices.
"""
@inline function mortonToCartesian3D(idx::Int)::NTuple{3,Int}
    k = UInt64(idx - 1)            # 0-based key
    x0, y0, z0 = mortonU64ToCartesian3D(k)
    return (Int(x0) + 1, Int(y0) + 1, Int(z0) + 1)
end

"""
    cartesianNeighbors2D(pos::Tuple{Int,Int}, shape::Tuple{Int,Int}) -> NTuple{9,Tuple{Int,Int}}

Returns 3×3 Cartesian neighbors around `(ix, iy)` (1-based), including
the center. Out-of-bounds neighbors are reported as `(-1, -1)`.

# Arguments
- `pos::Tuple{Int,Int}`: Center coordinates.
- `shape::Tuple{Int,Int}`: Bounds `(nx, ny)`.

# Returns
- 9-tuple of `(x, y)` pairs in fixed order:
  `(-1,-1),(0,-1),(1,-1), (-1,0),(0,0),(1,0), (-1,1),(0,1),(1,1)` offsets added to `(ix,iy)`.
"""
@inline function cartesianNeighbors2D(pos::Tuple{Int,Int}, shape::Tuple{Int,Int})::NTuple{9,Tuple{Int,Int}}
    offsets = ((-1,-1),(0,-1),(1,-1),
               (-1, 0),(0, 0),(1, 0),
               (-1, 1),(0, 1),(1, 1))
    return ntuple(i -> begin
        dx, dy = offsets[i]
        x = pos[1] + dx; y = pos[2] + dy
        (1 ≤ x ≤ shape[1] && 1 ≤ y ≤ shape[2]) ? (x, y) : (-1, -1)
    end, 9)
end

"""
    cartesianNeighbors3D(pos::Tuple{Int,Int,Int}, shape::Tuple{Int,Int,Int}) -> NTuple{27,NTuple{3,Int}}

Returns 3×3×3 Cartesian neighbors around `(ix, iy, iz)` (1-based),
including the center. Out-of-bounds neighbors are reported as `(-1, -1, -1)`.

# Arguments
- `pos::Tuple{Int,Int,Int}`: Center coordinates (1-based).
- `shape::Tuple{Int,Int,Int}`: Bounds `(nx, ny, nz)`.

# Returns
- 27-tuple of `(x, y, z)` triples in z-major order.
"""
@inline function cartesianNeighbors3D(pos::Tuple{Int,Int,Int}, shape::Tuple{Int,Int,Int})::NTuple{27,NTuple{3,Int}}
    return ntuple(k -> begin
        kk = k - 1
        dx = (kk % 3) - 1
        dy = ((kk ÷ 3) % 3) - 1
        dz = ((kk ÷ 9) % 3) - 1
        x = pos[1] + dx; y = pos[2] + dy; z = pos[3] + dz
        (1 ≤ x ≤ shape[1] && 1 ≤ y ≤ shape[2] && 1 ≤ z ≤ shape[3]) ? (x, y, z) : (-1, -1, -1)
    end, 27)
end

"""
    linearNeighbors2D(idx::Int, shape::Tuple{Int,Int}) -> NTuple{9,Int}

Returns neighbors of a **1-based Morton rank** as **1-based linear indices**
in a 2D grid. Includes the center; out-of-bounds as `-1`.

# Arguments
- `idx::Int`: 1-based Morton rank of the center.
- `shape::Tuple{Int,Int}`: Bounds `(nx, ny)`.

# Returns
- 9-tuple of linear indices in fixed 3×3 order (see [`cartesianNeighbors2D`]).
"""
@inline function linearNeighbors2D(idx::Int, shape::Tuple{Int,Int})::NTuple{9,Int}
    x, y = mortonToCartesian2D(idx)  # 1-based cartesian coords
    # fixed 3x3 order: (-1,-1) .. (1,1)
    offsets = ((-1,-1),(0,-1),(1,-1),
               (-1, 0),(0, 0),(1, 0),
               (-1, 1),(0, 1),(1, 1))
    return ntuple(i -> begin
        dx, dy = offsets[i]
        xi = x + dx; yi = y + dy
        (1 ≤ xi ≤ shape[1] && 1 ≤ yi ≤ shape[2]) ? cartesianToLinear2D((xi, yi), shape) : -1
    end, 9)
end

"""
    linearNeighbors3D(idx::Int, shape::Tuple{Int,Int,Int}) -> NTuple{27,Int}

Returns neighbors of a **1-based Morton rank** as **1-based linear indices**
in a 3D grid. Includes the center; out-of-bounds as `-1`.

# Arguments
- `idx::Int`: 1-based Morton rank of the center.
- `shape::Tuple{Int,Int,Int}`: Bounds `(nx, ny, nz)`.

# Returns
- 27-tuple of linear indices in fixed z-major, then y, then x order.
"""
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
            cartesianToLinear3D((xi, yi, zi), shape) : -1
    end, 27)
end

"""
    mortonNeighbors2D(idx::Int, shape::Tuple{Int,Int}) -> NTuple{9,Int}

Returns neighbors of a **1-based Morton rank** as **1-based Morton ranks**
for a 2D grid. Includes the center; out-of-bounds as `-1`.

# Arguments
- `idx::Int`: 1-based Morton rank of the center.
- `shape::Tuple{Int,Int}`: Bounds `(nx, ny)`.

# Returns
- 9-tuple of Morton ranks in fixed 3×3 order (center at position 5).
"""
@inline function mortonNeighbors2D(idx::Int, shape::Tuple{Int,Int})::NTuple{9,Int}
    x, y = mortonToCartesian2D(idx)  # 1-based cartesian coords
    # fixed 3x3 order: (-1,-1) .. (1,1)
    offsets = ((-1,-1),(0,-1),(1,-1),
               (-1, 0),(0, 0),(1, 0),
               (-1, 1),(0, 1),(1, 1))
    return ntuple(i -> begin
        dx, dy = offsets[i]
        xi = x + dx; yi = y + dy
        (1 ≤ xi ≤ shape[1] && 1 ≤ yi ≤ shape[2]) ? cartesianToMorton2D((xi, yi)) : -1
    end, 9)
end

"""
    mortonNeighbors3D(idx::Int, shape::Tuple{Int,Int,Int}) -> NTuple{27,Int}

Returns neighbors of a **1-based Morton rank** as **1-based Morton ranks**
for a 3D grid. Includes the center; out-of-bounds as `-1`.

# Arguments
- `idx::Int`: 1-based Morton rank of the center.
- `shape::Tuple{Int,Int,Int}`: Bounds `(nx, ny, nz)`.

# Returns
- 27-tuple of Morton ranks in z-major order (then y, then x).
"""
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
            cartesianToMorton3D((xi, yi, zi)) : -1
    end, 27)
end
