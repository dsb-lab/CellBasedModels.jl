module CellStruct

    mutable struct cell
        state::Array{Float32}
        stateChem::Array{Float32}
        parameters::Array{Float32}
        radius::Float32
        timeLastDivision::Float32

        function cell(Dspace::Int,Dstate::Int,Dparameters::Int)
            new(zeros(Dspace*2),zeros(Dstate),zeros(Dparameters),1,0)
        end
    end

end