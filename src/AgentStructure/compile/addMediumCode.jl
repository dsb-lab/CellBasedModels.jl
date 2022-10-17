"""
    function addMediumCode(p::Agent)

Function that adds the lines of code that map a the position of an agent with a integer position in the grid of the medium.

# Args
 - **p::Agent**: Agent structure containing all the created code when compiling.

# Returns
 - `Expr` with the code of the grid position.
"""
function addMediumCode(p::Agent)

    code = quote end

    if sum(p.declaredSymbols[:,:type] .== :Medium) > 0
        if p.dims == 1
            code = quote
                idMediumX_ = max(1,min(NMedium[1],round(Int,(x-simulationBox[1,1])/dMedium[1])+1))
            end
        elseif p.dims == 2
            code = quote
                idMediumX_ = max(1,min(NMedium[1],round(Int,(x-simulationBox[1,1])/dMedium[1])+1))
                idMediumY_ = max(1,min(NMedium[2],round(Int,(y-simulationBox[2,1])/dMedium[2])+1))
            end
        elseif p.dims == 3
            code = quote
                idMediumX_ = max(1,min(NMedium[1],round(Int,(x-simulationBox[1,1])/dMedium[1])+1))
                idMediumY_ = max(1,min(NMedium[2],round(Int,(y-simulationBox[2,1])/dMedium[2])+1))
                idMediumZ_ = max(1,min(NMedium[3],round(Int,(z-simulationBox[3,1])/dMedium[3])+1))
            end
        end        
    end

    return code
end