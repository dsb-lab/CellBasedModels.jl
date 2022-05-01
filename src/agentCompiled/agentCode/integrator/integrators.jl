addIntegrator_! = 
Dict{String,Function}(
    "Euler"=>addIntegratorEuler_!,
    "Heun"=>addIntegratorHeun_!,
    "RungeKutta4"=>addIntegratorRungeKutta4_!,
    "ImplicitEuler"=>addIntegratorImplicitEuler_!,
    "VerletVelocity"=>addIntegratorVerletVelocity_!,
)

"""
    function updateVariables_!(abm::Agent,p::Program)

Adds to p.update those variables that should be updated.
"""
function updateVariables_!(abm::Agent,p::Program_)

    #Check updated
    up = symbols_(abm,abm.declaredUpdates["UpdateVariable"])
    up = up[(up[:,"assigned"].==true),:]

    var = [Meta.parse(string(i,"̇")) for i in abm.declaredSymbols["Local"]]
    for (i,j) in zip(var,abm.declaredSymbols["Local"])
        if i in up.Symbol
            push!(p.update,j)
        end
    end

    return
end