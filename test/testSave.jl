@testset "save" begin

    for platform in testplatforms

        m = @agent(cell,
            l::GlobalArray,

            UpdateGlobal = begin
                    l[1,1] += 1
                end
            )
        model = compile(m,save="RAM",debug=false,platform=platform)
        #println(model.program)
        com = Community(model)
        com.l = zeros(2,2)
        comt = model.evolve(com,dt=0.1,tMax=10,dtSave=0.2)

        @test length(comt)==51
        @test comt[end].l[1,2] == 0. 
        @test comt[end].l[1,1] == 99 

    end

end