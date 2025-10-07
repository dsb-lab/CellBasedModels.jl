randcoords(shape::Tuple{Int,Int}) = (rand(1:shape[1]), rand(1:shape[2]))
randcoords(shape::Tuple{Int,Int,Int}) = (rand(1:shape[1]), rand(1:shape[2]), rand(1:shape[3]))

@testset verbose=verbose "Indexing" begin

    # ----------------------------
    # 2D basic identities (0-based)
    # ----------------------------
    @testset "2D: encode/decode (0-based)" begin
        for _ in 1:1_000
            x = rand(UInt32); y = rand(UInt32)
            k = CellBasedModels.cartesianToMortonU64(x, y)
            x2, y2 = CellBasedModels.mortonU64ToCartesian2D(k)
            @test x2 == x
            @test y2 == y
        end
    end

    # ----------------------------
    # 3D basic identities (0-based, ≤21 bits)
    # ----------------------------
    @testset "3D: encode/decode (0-based, 21-bit coordinates)" begin
        max21 = UInt32(2^21 - 1)
        for _ in 1:1_000
            x = rand(0:max21) |> UInt32
            y = rand(0:max21) |> UInt32
            z = rand(0:max21) |> UInt32
            k = CellBasedModels.cartesianToMortonU64(x, y, z)
            x2, y2, z2 = CellBasedModels.mortonU64ToCartesian3D(k)
            @test x2 == x
            @test y2 == y
            @test z2 == z
        end
    end

    # ----------------------------
    # 2D position → cartesian (1-based)
    # ----------------------------
    @testset "2D: position → cartesian" begin
        # ---------------- 2D ----------------
        # simBox is a 2×2 matrix; first column = lower bounds, second = upper bounds
        simBox2 = [
                0.0 10.0;
                0.0 20.0
            ]
        edge2   = (1.0, 2.0)          # cell sizes per axis
        shape2  = (10, 10)            # nx = (10-0)/1 = 10; ny = (20-0)/2 = 10

        @test CellBasedModels.positionToCartesian2D((0.0, 0.0), simBox2, edge2, shape2) == (1, 1)          # lower corner
        @test CellBasedModels.positionToCartesian2D((0.99, 1.99), simBox2, edge2, shape2) == (1, 1)        # still first cell
        @test CellBasedModels.positionToCartesian2D((1.0, 2.0), simBox2, edge2, shape2) == (2, 2)          # exact cell boundary
        @test CellBasedModels.positionToCartesian2D((9.999, 19.999), simBox2, edge2, shape2) == (10, 10)   # just inside upper
        @test CellBasedModels.positionToCartesian2D((10.0, 20.0), simBox2, edge2, shape2) == (10, 10)      # exactly at upper → clamps
        @test CellBasedModels.positionToCartesian2D((-1.0, -5.0), simBox2, edge2, shape2) == (1, 1)        # clamp low
        @test CellBasedModels.positionToCartesian2D((999.0, 999.0), simBox2, edge2, shape2) == (10, 10)    # clamp high

        # Random sample checks (stability across range)
        for _ in 1:200
            x = rand() * 10.0
            y = rand() * 20.0
            ix, iy = CellBasedModels.positionToCartesian2D((x, y), simBox2, edge2, shape2)
            @test 1 ≤ ix ≤ shape2[1]
            @test 1 ≤ iy ≤ shape2[2]
        end
    end

    @testset "3D: position → cartesian" begin
        # ---------------- 3D ----------------
        # simBox is a 3×2 matrix; first column = lower bounds, second = upper bounds
        simBox3 = [0.0  8.0;
                1.0 11.0;
                2.0 14.0]
        edge3   = (2.0, 2.0, 3.0)     # cell sizes per axis
        shape3  = (4, 5, 4)           # nx=(8-0)/2=4; ny=(11-1)/2=5; nz=(14-2)/3=4

        @test CellBasedModels.positionToCartesian3D((0.0, 1.0, 2.0), simBox3, edge3, shape3) == (1, 1, 1)           # lower corner
        @test CellBasedModels.positionToCartesian3D((1.999, 2.999, 4.999), simBox3, edge3, shape3) == (1, 1, 1)     # just inside first cell
        @test CellBasedModels.positionToCartesian3D((2.0, 3.0, 5.0), simBox3, edge3, shape3) == (2, 2, 2)           # exact boundaries
        @test CellBasedModels.positionToCartesian3D((7.999, 10.999, 13.999), simBox3, edge3, shape3) == (4, 5, 4)   # just inside upper
        @test CellBasedModels.positionToCartesian3D((8.0, 11.0, 14.0), simBox3, edge3, shape3) == (4, 5, 4)         # exactly at upper → clamps
        @test CellBasedModels.positionToCartesian3D((-9.0, -9.0, -9.0), simBox3, edge3, shape3) == (1, 1, 1)        # clamp low
        @test CellBasedModels.positionToCartesian3D((99.0, 99.0, 99.0), simBox3, edge3, shape3) == (4, 5, 4)        # clamp high

        # Random sample checks (stability across range)
        for _ in 1:200
            x = rand() * 8.0
            y = 1.0 + rand() * 10.0
            z = 2.0 + rand() * 12.0
            ix, iy, iz = CellBasedModels.positionToCartesian3D((x, y, z), simBox3, edge3, shape3)
            @test 1 ≤ ix ≤ shape3[1]
            @test 1 ≤ iy ≤ shape3[2]
            @test 1 ≤ iz ≤ shape3[3]
        end
    end


    # ----------------------------
    # 1-based cartesian ↔ Morton rank
    # ----------------------------
    @testset "2D: 1-based cartesian ↔ Morton rank" begin
        for ix in 1:32, iy in 1:31
            m = CellBasedModels.cartesianToMorton2D((ix, iy))
            ix2, iy2 = CellBasedModels.mortonToCartesian2D(m)
            @test (ix2, iy2) == (ix, iy)
        end

        # First 3×3 block Z-order sanity
        @test CellBasedModels.cartesianToMorton2D((1,1)) == 1
        @test CellBasedModels.cartesianToMorton2D((2,1)) == 2
        @test CellBasedModels.cartesianToMorton2D((3,1)) == 5
        @test CellBasedModels.cartesianToMorton2D((1,2)) == 3
        @test CellBasedModels.cartesianToMorton2D((2,2)) == 4
        @test CellBasedModels.cartesianToMorton2D((3,2)) == 7
        @test CellBasedModels.cartesianToMorton2D((1,3)) == 9
        @test CellBasedModels.cartesianToMorton2D((2,3)) == 10
        @test CellBasedModels.cartesianToMorton2D((3,3)) == 13
    end

    @testset "3D: 1-based cartesian ↔ Morton rank" begin
        shape = (32, 17, 13)
        for ix in 1:shape[1], iy in 1:shape[2], iz in 1:shape[3]
            m = CellBasedModels.cartesianToMorton3D((ix, iy, iz))
            ix2, iy2, iz2 = CellBasedModels.mortonToCartesian3D(m)
            @test (ix2, iy2, iz2) == (ix, iy, iz)
        end

    end

    # ----------------------------
    # Cartesian ↔ Linear (1-based)
    # ----------------------------
    @testset "2D: cartesian ↔ linear" begin
        shape = (53, 47)
        for ix in 1:shape[1], iy in 1:shape[2]
            li = CellBasedModels.cartesianToLinear2D((ix, iy), shape)  # expects tuple-like dims
            ix2, iy2 = CellBasedModels.linearToCartesian2D(li, shape)
            @test (ix2, iy2) == (ix, iy)
        end
    end

    @testset "3D: cartesian ↔ linear" begin
        shape = (23, 19, 11)
        for ix in 1:shape[1], iy in 1:shape[2], iz in 1:shape[3]
            li = CellBasedModels.cartesianToLinear3D((ix, iy, iz), shape)  # expects tuple-like dims
            ix2, iy2, iz2 = CellBasedModels.linearToCartesian3D(li, shape)
            @test (ix2, iy2, iz2) == (ix, iy, iz)
        end
    end

    # ----------------------------
    # Neighbor consistency
    # ----------------------------
    @testset "2D: neighbors consistency" begin
        shape = (64, 65)

        for _ in 1:1_000
            ix, iy = randcoords(shape)

            # Cartesian neighbors (ground truth)
            neigh_c = CellBasedModels.cartesianNeighbors2D((ix, iy), shape)
            @test neigh_c[5] == (ix, iy)

            # Morton neighbors vs Cartesian→Morton mapping
            m0 = CellBasedModels.cartesianToMorton2D((ix, iy))
            neigh_m = CellBasedModels.mortonNeighbors2D(m0, shape)
            mapped_m = ntuple(i -> begin
                x, y = neigh_c[i]
                (x < 1 || y < 1 || x > shape[1] || y > shape[2]) ? -1 :
                    CellBasedModels.cartesianToMorton2D((x, y))
            end, 9)
            @test neigh_m == mapped_m

            # Linear neighbors vs Cartesian→Linear mapping
            neigh_l = CellBasedModels.linearNeighbors2D(m0, shape)
            mapped_l = ntuple(i -> begin
                x, y = neigh_c[i]
                (x < 1 || y < 1 || x > shape[1] || y > shape[2]) ? -1 :
                    CellBasedModels.cartesianToLinear2D((x,y), shape)
            end, 9)
            @test neigh_l == mapped_l
        end

        # Corner OOB count sanity
        let ix=1, iy=1
            n = CellBasedModels.cartesianNeighbors2D((ix, iy), shape)
            @test count(==( (-1,-1) ), n) == 5
        end
    end

    @testset "3D: neighbors consistency" begin
        shape = (20, 21, 22)

        for _ in 1:500
            ix, iy, iz = randcoords(shape)

            neigh_c = CellBasedModels.cartesianNeighbors3D((ix, iy, iz), shape)
            @test neigh_c[14] == (ix, iy, iz)  # center in z-major order

            m0 = CellBasedModels.cartesianToMorton3D((ix, iy, iz))

            neigh_m = CellBasedModels.mortonNeighbors3D(m0, shape)
            mapped_m = ntuple(i -> begin
                x,y,z = neigh_c[i]
                (x < 1 || y < 1 || z < 1 || x > shape[1] || y > shape[2] || z > shape[3]) ? -1 :
                    CellBasedModels.cartesianToMorton3D((x, y, z))
            end, 27)
            @test neigh_m == mapped_m

            neigh_l = CellBasedModels.linearNeighbors3D(m0, shape)
            mapped_l = ntuple(i -> begin
                x,y,z = neigh_c[i]
                (x < 1 || y < 1 || z < 1 || x > shape[1] || y > shape[2] || z > shape[3]) ? -1 :
                    CellBasedModels.cartesianToLinear3D((x,y,z), shape)
            end, 27)
            @test neigh_l == mapped_l
        end

        # Corner OOB count sanity (3D corner has 19 OOB of 27)
        let ix=1, iy=1, iz=1
            n = CellBasedModels.cartesianNeighbors3D((ix, iy, iz), shape)
            @test count(==( (-1,-1,-1) ), n) == 19
        end
    end

end