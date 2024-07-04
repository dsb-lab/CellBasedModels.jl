# PhysiCell Version 1.2.2

#Relations between volumes from original parameters
f_v(vF,vNS,vCS) = vNS + vCS + vF                       #(intext)
f_vC(vF,vNS,vCS) = vCS/(1-(vNS+vCS)/(vNS + vCS + vF))  #(4)
f_vN(vF,vNS,vCS) = vNS/(1-(vNS+vCS)/(vNS + vCS + vF))  #(5)
f_vF(vF,vNS,vCS) = vNS + vCS                           #(6)
f_vCStarget(fCN,vNStarget) = fCN*vNStarget             #(7)
f_vFtarget(fF,vF,vNS,vCS) = fF*(vNS + vCS + vF)        #(8)
f_fNC(fCN) = 1/fCN                                     #(intext)

###########################################################################
# Volume Models
###########################################################################
volumeModel = ABM(3,
    agent = Dict(
        :fCN => Float64,    #Target cytoplasmatic to nuclear ratio        
        :fF => Float64,     #Target cytoplasmatic to nuclear ratio        
        :rF => Float64,     #Groth Rate Fluid Volume
        :rN => Float64,     #Groth Rate Nuclear Volume
        :rC => Float64,     #Groth Rate Cytoplasmatic Volume
        :vF => Float64,     #Fluid Volume
        :vNS => Float64,    #Nuclear Solid Volume
        :vCS => Float64,    #Citoplasmatic Solid Volume
    ),
    agentODE = quote
        #Volume growth
        dt(vF) = rF*(vFtarget-vF)                      #(1)
        dt(vNS) = rN*(vNStarget-vNS)                   #(2)
        dt(vCS) = rC*(vCStarget-vCS)                   #(3)
    end,

    compile=false
)

###########################################################################
# Cell Cycle Models
###########################################################################
cellCycleAdvancedModel = ABM(3,

    model = Dict(
        :rD => Float64,      #Rate death
    ),
    
    agent = Dict(
        :tPhaseK1 => Float64, #Time phase K1 
        :tPhaseK2 => Float64, #Time phase K2 
        :tPhaseQ => Float64,  #Time phase Q 
        :cycle => Int64,      #Cycle state (0 Q phase, 1 K1 Phase, 2 K2 phase, -1 Dead)
        :tPhase => Float64,   #Phase elapsed time
        :divide => Bool,      #Divide cell
    ),
    
    agentRule = quote
        #Update phase time
        tPhase += dt
        #Cell cycle
        rnₐ = CBMDistributions.uniform(0,1)
        if cycle == 0 && dt/tPhaseQ > rnₐ
            cycle = 1
            tPhase = 0.
            vNSTarget *= 2
        elseif cycle == 1 && dt/tPhaseK1 > rnₐ
            cycle = 2
            tPhase = 0.
            vNSTarget /= 2
            divide = true
        elseif cycle == 2 && dt/tPhaseK2 > rnₐ
            cycle = 0
            tPhase = 0.
        end
    end,

    compile=false
)

cellCycleAdvancedModelVariant1 = ABM(3,

    model = Dict(
        :rD => Float64,      #Rate death
    ),
    
    agent = Dict(
        :tPhaseK1 => Float64, #Time phase K1 
        :tPhaseK2 => Float64, #Time phase K2 
        :tPhaseQ => Float64,  #Time phase Q 
        :cycle => Int64,      #Cycle state (0 Q phase, 1 K1 Phase, 2 K2 phase, -1 Dead)
        :tPhase => Float64,   #Phase elapsed time
        :divide => Bool,      #Divide cell
    ),
    
    agentRule = quote
        #Update phase time
        tPhase += dt
        #Cell cycle
        rnₐ = CBMDistributions.uniform(0,1)
        if cycle == 0 && tPhaseQ < tPhase
            cycle = 1
            tPhase = 0.
            vNSTarget *= 2
        elseif cycle == 1 && tPhaseK1 < tPhase
            cycle = 2
            tPhase = 0.
            vNSTarget /= 2
            divide = true
        elseif cycle == 2 && tPhaseK2 < tPhase
            cycle = 0
            tPhase = 0.
        end
    end,

    compile=false
)

cellCycleAdvancedModelVariant2 = ABM(3,

    model = Dict(
        :rD => Float64,      #Rate death
    ),
    
    agent = Dict(
        :tPhaseK1 => Float64, #Time phase K1 
        :tPhaseK2 => Float64, #Time phase K2 
        :tPhaseQ => Float64,  #Time phase Q 
        :cycle => Int64,      #Cycle state (0 Q phase, 1 K1 Phase, 2 K2 phase, -1 Dead)
        :tPhase => Float64,   #Phase elapsed time
        :divide => Bool,      #Divide cell
    ),
    
    agentRule = quote
        #Update phase time
        tPhase += dt
        #Cell cycle
        rnₐ = CBMDistributions.uniform(0,1)
        if cycle == 0 && dt/tPhaseQ > rnₐ
            cycle = 1
            tPhase = 0.
            vNSTarget *= 2
        elseif cycle == 1 && tPhaseK1 < tPhase
            cycle = 2
            tPhase = 0.
            vNSTarget /= 2
            divide = true
        elseif cycle == 2 && tPhaseK2 < tPhase
            cycle = 0
            tPhase = 0.
        end
    end,

    compile=false
)

cellCycleBasicModel = ABM(3,

    model = Dict(
        :rD => Float64,      #Rate death
    ),
    
    agent = Dict(
        :tPhaseK => Float64, #Time phase K 
        :tPhaseQ => Float64, #Time phase Q 
        :cycle => Int64,     #Cycle state (0 Q phase, 1 K phase, -1 Dead)
        :tPhase => Float64,  #Phase elapsed time
        :divide => Bool,     #Divide cell
    ),
    
    agentRule = quote
        #Update phase time
        tPhase += dt
        #Cell cycle
        rnₐ = CBMDistributions.uniform(0,1)
        if cycle == 0 && dt/tPhaseQ > rnₐ
            cycle = 1
            tPhase = 0.
            vNSTarget *= 2
        elseif cycle == 1 && dt/tPhaseK > rnₐ
            cycle = 0
            tPhase = 0.
            vNSTarget /= 2
            divide = true
        end
    end,

    compile=false
)

cellCycleBasicModelVariant1 = ABM(3,

    model = Dict(
        :rD => Float64,      #Rate death
    ),
    
    agent = Dict(
        :tPhaseK => Float64, #Time phase K 
        :tPhaseQ => Float64, #Time phase Q 
        :cycle => Int64,     #Cycle state (0 Q phase, 1 K phase, -1 Dead)
        :tPhase => Float64,  #Phase elapsed time
        :divide => Bool,     #Divide cell
    ),
    
    agentRule = quote
        #Update phase time
        tPhase += dt
        #Cell cycle
        rnₐ = CBMDistributions.uniform(0,1)
        if cycle == 0 && tPhaseQ < tPhase
            cycle = 1
            tPhase = 0.
            vNSTarget *= 2
        elseif cycle == 1 && tPhaseK < tPhase
            cycle = 0
            tPhase = 0.
            vNSTarget /= 2
            divide = true
        end
    end,

    compile=false
)

cellCycleBasicModelVariant2 = ABM(3,

    model = Dict(
        :rD => Float64,      #Rate death
    ),
    
    agent = Dict(
        :tPhaseK => Float64, #Time phase K 
        :tPhaseQ => Float64, #Time phase Q 
        :cycle => Int64,     #Cycle state (0 Q phase, 1 K phase, -1 Dead)
        :tPhase => Float64,  #Phase elapsed time
        :divide => Bool,     #Divide cell
    ),
    
    agentRule = quote
        #Update phase time
        tPhase += dt
        #Cell cycle
        rnₐ = CBMDistributions.uniform(0,1)
        if cycle == 0 && dt/tPhaseQ > rnₐ
            cycle = 1
            tPhase = 0.
            vNSTarget *= 2
        elseif cycle == 1 && tPhaseK < tPhase
            cycle = 0
            tPhase = 0.
            vNSTarget /= 2
            divide = true
        end
    end,

    compile=false
)

cellCycleLiveCellsModel = ABM(3,

    model = Dict(
        :rD => Float64,      #Rate death
        :rb => Float64,      #Rate death
    ),
    
    agent = Dict(
        :cycle => Int64,     #Cycle state (0 Q phase, 1 K phase, -1 Dead)
        :tPhase => Float64,  #Phase elapsed time
        :divide => Bool,     #Divide cell
    ),
    
    agentRule = quote
        #Update phase time
        tPhase += dt
        #Cell cycle
        rnₐ = CBMDistributions.uniform(0,1)
        if cycle == 0 && dt*rb > rnₐ
            tPhase = 0.
            divide = true
        end
    end,

    compile=false
)

###########################################################################
# Cell Division Model
###########################################################################
cellDivisionModel = ABM(3,

    agent = Dict(
        :polarization => Float64, #Polarization
        :θx => Float64,           #Polarization
        :θy => Float64,           #Polarization
        :θz => Float64,           #Polarization
    ),
    
    agentRule = quote

        if divide
            
            #Choose random direction equation (15)
            rxₐ = CBMDistributions.uniform(0,1); ryₐ = CBMDistributions.uniform(0,1); rzₐ = CBMDistributions.uniform(0,1)
            r_θ = rxₐ*θx + ryₐ*θy + rzₐ*θz
            dxₐ = rxₐ - r_θ*θx + (1. - polarization)*r_θ*θx
            dyₐ = ryₐ - r_θ*θy + (1. - polarization)*r_θ*θy
            dzₐ = rzₐ - r_θ*θz + (1. - polarization)*r_θ*θz
            Tₐ = sqrt(dxₐ^2+dyₐ^2+dzₐ^2)
            dxₐ /= Tₐ;dyₐ /= Tₐ;dzₐ /= Tₐ    
    
            #Radius equation (braket in 16)
            rₐ = (f_v(vF,vNS,vCS)*3/4/π)^(1/3)
            rdₐ = rₐ - rₐ/2^(1/3)
            
            @addAgent(
                vF = vF/2,
                vNS = vNS/2,
                vCS = vCS/2,
                tPhase = 0.,
                x = x + rdₐ*dxₐ,
                y = y + rdₐ*dyₐ,
                z = z + rdₐ*dzₐ,
                divide = false,
            )
            @addAgent(
                vF = vF/2,
                vNS = vNS/2,
                vCS = vCS/2,
                tPhase = 0.,
                x = x - rdₐ*dxₐ,
                y = y - rdₐ*dyₐ,
                z = z - rdₐ*dzₐ,
                divide = false,
            )
            @removeAgent()

        end
            
    end,

    compile=false
)

###########################################################################
# Cell Death Models
###########################################################################
cellDeathApoptosisModel = ABM(3,

    model = Dict(
        :rFApop => Float64,
        :rCApop => Float64,
        :rNApop => Float64,
        :rDeathApop => Float64,   #Rate of apoptotic death
    ),

    agentRule = quote
    
        rnₐ = CBMDistributions.uniform(0,1)
        if cycle >= 0 && dt*rDeathApop > rnₐ

            cycle = -1
            vNSTarget = 0.
            fCN = 0.
            fF = 0.
            rF = rFApop
            rC = rCApop
            rN = rNApop

        end

    end,

    compile=false
)

cellDeathNecrosisModel = ABM(3,

    model = Dict(
        :rFNec => Float64,
        :rCNec => Float64,
        :rNNec => Float64,
        :rNecCrit => Float64,
        :pO2Crit => Float64,
        :pO2Thres => Float64,
    ),

    agent = Dict(
        :pO2 => Float64,      #Rate of apoptotic death
        :vRupture => Float64, #Volume of rupture
    ),

    agentRule = quote
    
        rnₐ = CBMDistributions.uniform(0,1)

        rNecₐ = 0.
        if pO2 < pO2Crit
            rNecₐ = rNecCrit
        elseif pO2 <= pO2Thres
            rNecₐ = rNecCrit*(pO2Thres-pO2)/(pO2Thres-pO2Crit)
        end
        if cycle >= 0 && dt*rNecₐ > rnₐ

            cycle = -2
            tPhase = 0.
            vNSTarget = 0.
            fCN = 0.
            fF = 1.
            rF = rFNecEarly
            rC = rCNec
            rN = rNNec

        elseif cycle == -2 && f_v(vF,vNS,vCS) > vRupture

            cycle = -3
            fF = 0.
            rF = rFNecLate

        end

    end,

    compile=false
)

###########################################################################
# Parameters
###########################################################################
parametersVolumeModel = Dict(
    
    # Table 1: Parameters Volume Model
    :v => 2494,         #μm³
    :vN => 540,         #μm³
    :rF =>        3.0,  #h⁻¹
    :rC =>        0.27, #h⁻¹
    :rN =>        0.33, #h⁻¹
    :vNStarget => 135,  #μm³
    :fCN => 3.6,        #adimensional
    :fF => 0.75,        #adimensional
)

parametersAdvancedCellCycleModel = Dict(
    # Table 2: Ki67 Advanced Cell Cycle Model
    :tPhaseK1 => 13,     #h
    :tPhaseK2 => 2.5,    #h
    :tPhaseQ => 3.62,    #h
)

parametersBasicCellCycleModel = Dict(
    # Table 3: Ki67 Basic Cell Cycle Model
    :tPhaseK => 15.5,    #h
    :tPhaseQ => 4.59,    #h
)

parametersLiveCellCycleModel = Dict(
    # Table 4: Live Cells Cycle Model
    :rb => 0.0432,       #h⁻1
)

parametersDeathApoptosisModel = Dict(
    # 1.3.1 Apoptosis
    :rFApop => 3.0,         #h⁻1
    :rCApop => 1.0,         #h⁻1
    :rNApop => 0.35,        #h⁻1
)

parametersDeathNecrosisModel = Dict(
    # 1.3.1 Apoptosis
    :rFNecEarly => 0.67,     #h⁻1
    :rFNecLate => 0.05,      #h⁻1
    :rCNec => 0.0032,        #h⁻1
    :rNNec => 0.015,         #h⁻1
)

parametersDeathCalcificationModel = Dict(
    # 1.3.1 Apoptosis
    :rCalc => 0.0042,        #h⁻1
)