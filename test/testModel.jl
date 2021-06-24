@testset "model" begin

    @test_nowarn begin
        m = @agent(
            Hola,
            
            id::Identity,
            l::Local,
            g::Global,
            ga::GlobalArray,
            
            Equation = d_v = 34*dt ,
            UpdateLocal = l += 1,
            UpdateGlobal = begin
                g += Normal(1,2) + Normal(1,2) + Uniform(1,2) 
                ga[3,2] += 3
            end,
            UpdateInteraction = l += 1,
            UpdateLocalInteraction = l += 1
        )
        compile(m, platform="cpu",debug=true)
    end

end