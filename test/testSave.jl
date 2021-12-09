@testset "save" begin

    @test_nowarn begin
        m = @agent(0,
            l::Local,
            g::Global,
            ga::GlobalArray
        )
        model = compile(m,save="RAM",debug=false)

        com = Community(model,N=5)
        com.l .= 0.1 .*1:5
        com.id .= 1:5
        com.g = 6
        com.ga = [1 2;3 4]
        
        saveCSV(com,"testCSV")

        com2 = loadCommunityFromCSV(model,"testCSV")
    end

    m = @agent(0,
        l::Local,
        g::Global,
        ga::GlobalArray
    )
    model = compile(m,save="RAM",debug=false)
    com = Community(model,N=5)
    com.l .= 0.1 .*1:5
    com.id .= 1:5
    com.g = 6
    com.ga = [1 2;3 4]
    saveCSV(com,"testCSV")
    com2 = loadCommunityFromCSV(model,"testCSV")
    @test com.declaredSymbols_ == com2.declaredSymbols_
    @test com.local_ == com2.local_
    @test com.identity_ == com2.identity_
    @test com.global_ == com2.global_
    @test com.globalArray_ == com2.globalArray_
    @test com.t == com2.t
    @test com.N == com2.N

    for platform in testplatforms

        m = @agent(0,
            l::GlobalArray,

            UpdateGlobal = begin
                    l[1,1] += 1
                end
            )
        model = compile(m,save="RAM",debug=false,platform=platform)
        # println(model.program)
        com = Community(model)
        com.l = zeros(2,2)
        comt = model.evolve(com,dt=0.1,tMax=10.05,dtSave=0.2)

        @test length(comt)==51
        @test comt[end].l[1,2] == 0. 
        @test comt[1].l[1,1] == 0
    end

    for platform in testplatforms

        m = @agent(0,
            l::GlobalArray,

            UpdateGlobal = begin
                    l[1,1] += 1
                end
            )
        model = compile(m,save="CSV",debug=false,platform=platform)
        # println(model.program)
        com = Community(model)
        com.l = zeros(2,2)
        model.evolve(com, dt=0.1, tMax=10.05, dtSave=0.2, saveFile="testCSV")

        @test_nowarn loadCommunityInTimeFromCSV(model,"testCSV")
    end

    dir = readdir("./")
    for i in dir
        if occursin(".csv",i)
            rm(i)
        end
    end

end