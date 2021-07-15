@testset "Medium" begin

    m = @agent(3,
    
        u::Medium,

        UpdateMedium = ∂t_u = Δ(u)
    )
    s = SimulationFree(m,box=[(:x,0.,1.),(:y,0.,1.),(:z,0.,1.)],
                        medium=[MediumFlat("Periodic","Periodic",0.1),
                                MediumFlat("Periodic","Periodic",0.1),
                                MediumFlat("Periodic","Periodic",0.1)])

    m=compile(m,s,debug=false)

end