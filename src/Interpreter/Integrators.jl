abstract type IntegratorMethod end

struct rungeKutta4 <: IntegratorMethod
    order
    rungeKutta4() = new(4)
end

#It has to be redone better than this
function rungeKutta4_step(state::Array{Number}, extParams::Array{Number}, t::Number, dt::Number, forceFunction)
    
    k1 = forceFunction(state, extParams, t)
    k2 = forceFunction(state+dt*k1/2, extParams, t+dt/2)
    k3 = forceFunction(state+dt*k2/2, extParams, t+dt/2)
    k4 = forceFunction(state+dt*k3, extParams, t+dt)

    return state+dt*(k1+2*k2+2*k3+k4)/6
end