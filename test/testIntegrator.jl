@testset "model" begin

    @test_nowarn begin
        m = @agent(
            Hola,
            
            [x,y]::Variable,
            
            Equation = 
            quote
                ẋ = 34*dt 
                ẏ = r*dt + 4*dW
            end,
        )
        compile(m, platform="gpu",debug=true)
    end

end