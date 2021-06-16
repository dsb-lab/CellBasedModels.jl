@testset "model" begin

    @test_nowarn begin
        m = @agent(
            Hola,
            
            id::Identity,
            l::Local,
            v::Variable,
            g::Global,
            ga::GlobalArray,
            i::Interaction,
            
            Equation = dv = 34*dt ,
            UpdateLocal = l += 1,
            UpdateGlobal = quote
                g += Normal(1,2) + Normal(1,2) + Uniform(1,2) 
                ga[3,2] += 3
            end,
            UpdateInteraction = i += 1,
            UpdateLocalInteraction = i += 1
        )
        compile(m, platform="gpu",debug=true)
    end

end