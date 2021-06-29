@testset "save" begin

    m = @agent(cell,
        l::Local,

        UpdateLocal = begin
                l += 1
            end
        )
    model = compile(m,save="RAM",debug=false)
    com = Community(model)
    comt = model.evolve(com,dt=0.1,tMax=10,dtSave=0.2)

    @test length(comt)==51

end