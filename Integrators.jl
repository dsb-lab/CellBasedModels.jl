push!(LOAD_PATH,"./")
import CellStruct

function rungeKutta4(state::Array{Float32}, extParams::Array{Float32}, t::Float32, dt::Float32, forceFunction)
    
    k1 = forceFunction(state, extParams, t)
    k2 = forceFunction(state+dt*k1/2, extParams, t+dt/2)
    k3 = forceFunction(state+dt*k2/2, extParams, t+dt/2)
    k2 = forceFunction(state+dt*k3, extParams, t+dt)

    return state+dt*(k1+2*k2+2*k3+k4)/6
end