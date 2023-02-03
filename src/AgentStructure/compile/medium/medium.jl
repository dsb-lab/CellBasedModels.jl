mutable struct Medium 

    mediumV::Array
    mediumVCopy::Array
    NMedium::Array
    dMedium::Array

    function Medium(simulationBox,mediumN)
        NMedium = ARRAY[agent.platform](mediumN)
        dMedium = copy(NMedium)
        if p.agent.dims >= 1
            dMedium[1] = (simulationBox[1,2]-simulationBox[1,1])/NMedium[1]
        end
        if p.agent.dims >= 2
            dMedium[2] = (simulationBox[2,2]-simulationBox[2,1])/NMedium[2]
        end
        if p.agent.dims >= 3
            dMedium[3] = (simulationBox[3,2]-simulationBox[3,1])/NMedium[3]
        end     
        mediumV = copy(com.medium)

        if "UpdateMedium" in keys(p.agent.declaredUpdates)
            mediumVCopy = copy(mediumV)
        else
            mediumVCopy = []
        end

        new(mediumV,mediumVCopy,NMedium,dMedium)
    end
    
end