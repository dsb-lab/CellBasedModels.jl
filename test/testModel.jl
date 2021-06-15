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
                g += 1
                ga[3,2] += 3
            end,
            UpdateInteraction = i += 1,
            UpdateLocalInteraction = i += 1
        )
        compile(m, platform="cpu",debug=false)
    end

    @test_throws ErrorException begin
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
            UpdateGlobal = l += 1,
            UpdateInteraction = i += 1,
            UpdateLocalInteraction = i += 1
        )
        compile(m, platform="cpu",debug=false)
    end

end