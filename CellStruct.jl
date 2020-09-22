module CellStruct

    mutable struct cell
        pos::Array{Float32}
        state::Array{Float32}
        parameters::Array{Float32}
        radius::Float32
        timeLastDivision::Float32

        function cell(Dspace::Int,Dstate::Int,Dparameters::Int)
            new(zeros(Dspace),zeros(Dstate),zeros(Dparameters),1,0)
        end
    end

end