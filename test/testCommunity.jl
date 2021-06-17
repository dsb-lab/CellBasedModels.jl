@testset "community" begin

    @test_nowarn begin
        m = @agent(
            Hola,
            
            id::Identity,
            [v,l,i]::Local,
            g::Global,
            ga::GlobalArray,
            
            Equation = v̇ = 34*dt ,
            UpdateLocal = l += 1,
            UpdateGlobal = begin
                g += Normal(1,2) + Normal(1,2) + Uniform(1,2) 
                ga[3,2] += 3
            end,
            UpdateInteraction = i += 1,
            UpdateLocalInteraction = i += 1
        )                

        m = compile(m)

        com = Community(m)

        println(:id in com.declaredSymbols["Identity"])

        com.id = [2]
        com.l = [2]
        com.v = [2]
        com.g = 2
        com.ga = [2]
        com.i = [2]

    end

end