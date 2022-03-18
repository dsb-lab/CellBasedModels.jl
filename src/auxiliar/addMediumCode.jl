function addMediumCode(p::Program_)

    code = quote end

    if !(isempty(p.agent.declaredSymbols["Medium"]))
        if p.agent.dims == 1
            code = quote
                idMediumX_ = max(1,min(Nx_,round(Int,(x-simulationBox[1,1])/dxₘ_)+1))
            end
        elseif p.agent.dims == 2
            code = quote
                idMediumX_ = max(1,min(Nx_,round(Int,(x-simulationBox[1,1])/dxₘ_)+1))
                idMediumY_ = max(1,min(Ny_,round(Int,(y-simulationBox[2,1])/dyₘ_)+1))
            end
        elseif p.agent.dims == 3
            code = quote
                idMediumX_ = max(1,min(Nx_,round(Int,(x-simulationBox[1,1])/dxₘ_)+1))
                idMediumY_ = max(1,min(Ny_,round(Int,(y-simulationBox[2,1])/dyₘ_)+1))
                idMediumZ_ = max(1,min(Nz_,round(Int,(z-simulationBox[3,1])/dzₘ_)+1))
            end
        end        
    end

    return code
end