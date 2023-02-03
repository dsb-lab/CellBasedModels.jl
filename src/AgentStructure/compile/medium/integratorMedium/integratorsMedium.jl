addIntegratorMedium_! = 
Dict{String,Function}(
    "FTCS"=>addIntegratorMediumFTCS_!,
    "Lax"=>addIntegratorMediumLax_!,
    "ImplicitEuler"=>addIntegratorMediumImplicitEuler_!,
)

δMedium_(i1,i2) = if i1==i2 1. else 0. end