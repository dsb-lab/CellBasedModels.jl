@testset "model" begin

    @test_nowarn begin
        m = @agent(
            Hola,
            
            [x,y]::Local,
            
            Equation = 
            begin
                ẋ = 34*dt 
                ẏ = r*dt + 4*dW
            end
        )
        compile(m, integrator="Euler", platform="gpu",debug=false)
    end

    @test_nowarn begin
        m = @agent(
            Hola,
            
            [x,y]::Local,
            
            Equation = 
            begin
                ẋ = 34*dt 
                ẏ = r*dt + 4*dW
            end
        )
        compile(m, integrator="Heun", platform="gpu",debug=false)
    end

end