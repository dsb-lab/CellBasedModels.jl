@testset "Medium" begin

    m = @agent(1,
    
        u::Medium,

        UpdateMedium = ∂t_u = Δ(f(u))
    )
    println(m.declaredSymbols["Medium"])
    m=compile(m,debug=false)

end