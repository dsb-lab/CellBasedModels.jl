function freeInertialMovement(stats::Array{Float32}, params::Array{Float32}, t::Float32)
    
    return [stats[Int(length(stats)/2):end] params]
end

function dampedInertialMovement(stats::Array{Float32}, params::Array{Float32}, t::Float32)
    mi = 10^-6
    b = 10^-6
    return [stats[Int(length(stats)/2):end] params/mi-b*stats[Int(length(stats)/2):end]/mi]
end