module PhysiCell

    using CellBasedModels

    # PhysiCell Version 1.2.2

    #Relations between volumes from original parameters
    f_v(vF,vNS,vCS) = vNS + vCS + vF                       #(intext)
    f_vC(vF,vNS,vCS) = vCS/(1-(vNS+vCS)/(vNS + vCS + vF))  #(4)
    f_vN(vF,vNS,vCS) = vNS/(1-(vNS+vCS)/(vNS + vCS + vF))  #(5)
    f_vF(vF,vNS,vCS) = vNS + vCS                           #(6)
    f_vCSTarget(fCN,vNSTarget) = fCN*vNSTarget             #(7)
    f_vFTarget(fF,vF,vNS,vCS) = fF*(vNS + vCS + vF)        #(8)
    f_fNC(fCN) = 1/fCN                                     #(intext)
    f_r(vF,vNS,vCS) = (3*(vNS+vCS+vF)/(4*π))^(1/3)

    f_dBM(x,y,z) = Inf
    f_nBMx(x,y,z) = 1
    f_nBMy(x,y,z) = 0
    f_nBMz(x,y,z) = 0

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
            :vNSTarget => Float64,
        ),
        agentODE = quote
            #Volume growth
            dt(vF) = rF*(fF*(vF+vNS+vCS)-vF)               #(1)
            dt(vNS) = rN*(vNSTarget-vNS)                   #(2)
            dt(vCS) = rC*(fCN*vNSTarget-vCS)               #(3)
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
            :cycle => Int64,      #Cycle state (0 Q phase, 1 K1 Phase, 2 K2 phase)
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
            :cycle => Int64,      #Cycle state (0 Q phase, 1 K1 Phase, 2 K2 phase)
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
            :cycle => Int64,      #Cycle state (0 Q phase, 1 K1 Phase, 2 K2 phase)
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
            :cycle => Int64,     #Cycle state (0 Q phase, 1 K phase)
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
            :cycle => Int64,     #Cycle state (0 Q phase, 1 K phase)
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
            :cycle => Int64,     #Cycle state (0 Q phase, 1 K phase)
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
            :cycle => Int64,     #Cycle state (0 Q phase, 1 K phase)
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
                rxₐ = CBMDistributions.normal(0,1); ryₐ = CBMDistributions.normal(0,1); rzₐ = CBMDistributions.normal(0,1)
                r_θ = rxₐ*θx + ryₐ*θy + rzₐ*θz
                dxₐ = rxₐ - r_θ*θx + (1. - polarization)*r_θ*θx
                dyₐ = ryₐ - r_θ*θy + (1. - polarization)*r_θ*θy
                dzₐ = rzₐ - r_θ*θz + (1. - polarization)*r_θ*θz
                Tₐ = sqrt(dxₐ^2+dyₐ^2+dzₐ^2)
                dxₐ /= Tₐ;dyₐ /= Tₐ;dzₐ /= Tₐ    
        
                #Radius equation (braket in 16)
                rₐ = (PhysiCell.f_v(vF,vNS,vCS)*3/4/π)^(1/3)
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
            :tApop => Float64,        #Time for removing it from the model
        ),

        agentRule = quote
        
            rnₐ = CBMDistributions.uniform(0,1)
            if cycle >= 0 && dt*rDeathApop > rnₐ

                cycle = -1
                tPhase = 0.
                vNSTarget = 0.
                fCN = 0.
                fF = 0.
                rF = rFApop
                rC = rCApop
                rN = rNApop

            elseif cycle == -1 && tPhase > tApop

                @removeAgent()

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
    cellMechanicsModelBegin = ABM(3,

        model = Dict(
            :ra => Float64,       #Radius adhesion
        ),

        agent = Dict(
            :ν => Float64,        #Friction Coefficient
            :r => Float64,        #Radius of the cell
            :adhesion => Float64  #Adhesion parameter
        ),

        agentODE = quote
            fxₐ = 0.; fyₐ = 0.; fzₐ = 0.
        end,

        compile=false
    )

    cellMechanicsCellCellAdhesionModel = ABM(3,

        model = Dict(
            :ncca => Int64,       #Exponent of adhesion and repulsion forces
            :nccr => Int64,       #Exponent of adhesion and repulsion forces
            :ccca => Float64,    #Cell adhesion parameter
            :cccr => Float64,    #Cell adhesion parameter
        ),

        agentODE = quote
            
            #Cell-cell forces
            @loopOverNeighbors i2ₐ begin
            
                rxₐ = x[i2ₐ] - x            
                ryₐ = y[i2ₐ] - y            
                rzₐ = z[i2ₐ] - z
                dₐ = sqrt(rxₐ^2+ryₐ^2+rzₐ^2)          
                rrₐ = r+r[i2ₐ]  
                raₐ = ra*rrₐ
                if dₐ < raₐ
                    fxₐ += ccca*adhesion*adhesion[i2ₐ]*(1-dₐ/raₐ)^(ncca+1)*rxₐ/dₐ
                    fyₐ += ccca*adhesion*adhesion[i2ₐ]*(1-dₐ/raₐ)^(ncca+1)*ryₐ/dₐ
                    fzₐ += ccca*adhesion*adhesion[i2ₐ]*(1-dₐ/raₐ)^(ncca+1)*rzₐ/dₐ
                end
                if dₐ < rrₐ
                    fxₐ -= cccr*(1-dₐ/rrₐ)^(nccr+1)*rxₐ/dₐ
                    fyₐ -= cccr*(1-dₐ/rrₐ)^(nccr+1)*ryₐ/dₐ
                    fzₐ -= cccr*(1-dₐ/rrₐ)^(nccr+1)*rzₐ/dₐ
                end

            end

        end,

        agentRule = quote

            r = PhysiCell.f_r(vF,vNS,vCS)

        end,

        compile=false
    )

    cellMechanicsBMAdhesionModel = ABM(3,

        model = Dict(
            :ncba => Int64,      #Exponent of adhesion and repulsion forces
            :ncbr => Int64,      #Exponent of adhesion and repulsion forces
            :ccba => Float64,    #Cell adhesion parameter
            :ccbr => Float64,    #Cell adhesion parameter
        ),

        agentODE = quote
            
            #Cell-BM mechanics
            dₐ = f_dBM(x,y,z)
            nxₐ = f_nBMx(x,y,z)
            nyₐ = f_nBMy(x,y,z)
            nzₐ = f_nBMz(x,y,z)
            if dₐ < ra
                fxₐ -= ccba*(1-dₐ/raₐ)^(ncba+1)*nxₐ
                fyₐ -= ccba*(1-dₐ/raₐ)^(ncba+1)*nyₐ
                fzₐ -= ccba*(1-dₐ/raₐ)^(ncba+1)*nzₐ
            end
            if dₐ < rr
                fxₐ += ccbr*(1-dₐ/rr)^(ncbr+1)*nxₐ
                fyₐ += ccbr*(1-dₐ/rr)^(ncbr+1)*nyₐ
                fzₐ += ccbr*(1-dₐ/rr)^(ncbr+1)*nzₐ
            end

        end,

        compile=false
    )

    cellMechanicsBMAdhesionModel = ABM(3,

        model = Dict(
            :ccba => Float64,    #Cell adhesion parameter
            :ccbr => Float64,    #Cell adhesion parameter
        ),

        agentODE = quote
            
            #Cell-BM mechanics
            dₐ = f_dBM(x,y,z)
            nxₐ = f_nBMx(x,y,z)
            nyₐ = f_nBMy(x,y,z)
            nzₐ = f_nBMz(x,y,z)
            if dₐ < ra
                fxₐ -= ccba*(1-dₐ/raₐ)^(ncba+1)*nxₐ
                fyₐ -= ccba*(1-dₐ/raₐ)^(ncba+1)*nyₐ
                fzₐ -= ccba*(1-dₐ/raₐ)^(ncba+1)*nzₐ
            end
            if dₐ < rr
                fxₐ += ccbr*(1-dₐ/rr)^(ncbr+1)*nxₐ
                fyₐ += ccbr*(1-dₐ/rr)^(ncbr+1)*nyₐ
                fzₐ += ccbr*(1-dₐ/rr)^(ncbr+1)*nzₐ
            end

        end,

        compile=false
    )

    cellMechanicsMotility = ABM(3,

        model = Dict(
            :tPers => Float64, #Time persistence
            :bBias => Float64, #Time persistence
            :dBiasx => Float64, #Time persistence
            :dBiasy => Float64, #Time persistence
            :dBiasz => Float64, #Time persistence
        ),

        agent = Dict(
            :sloc => Float64,   # Migration speed
            :ulocx => Float64,  # Migration direction
            :ulocy => Float64,  # Migration direction
            :ulocz => Float64,  # Migration direction
        ),
        
        agentODE = quote
            
            uₐ = CBMDistributions.uniform(0,1)
            if uₐ <= dt/tPers
                rxₐ = CBMDistributions.normal(0,1); ryₐ = CBMDistributions.normal(0,1); rzₐ = CBMDistributions.normal(0,1)
                
                ulocx = b*dBiasx+(1-b)*rxₐ
                ulocy = b*dBiasy+(1-b)*ryₐ
                ulocz = b*dBiasz+(1-b)*rzₐ
                duₐ = sqrt(uxₐ^2+uyₐ^2+uzₐ^2)
                ulocx /= duₐ
                ulocy /= duₐ
                ulocz /= duₐ
            end

            fxₐ += sloc*ulocx
            fyₐ += sloc*ulocy
            fzₐ += sloc*ulocz

        end,

        compile=false
    )

    cellMechanicsModelEnd = ABM(3,

        agentODE = quote
            dt(x) = fxₐ
            dt(y) = fyₐ
            dt(z) = fzₐ
        end,

        compile=false
    )

    ###########################################################################
    # Medium
    ###########################################################################
    mediumCO2 = ABM(3,

        model = Dict(
            :Dco2 => Float64,
            :λco2 => Float64,
            :co2saturation => Float64
        ),
        
        medium = Dict(
            :co2 => Float64,
            :veins => Float64
        ),

        mediumODE = quote

            if @mediumInside()            
                dt(co2) = veins*(co2saturation-co2)-λco2*co2
            end

        end,

        mediumAlg = CBMIntegrators.DGADI(difussionCoefs=(co2=:Dco2,)),

        compile=false
    )

    mediumCO2Newmann = ABM(3,

        mediumODE = quote

            if @mediumBorder(1,-1)
                co2 = co2[2,i2_,i3_]        
            elseif @mediumBorder(1,1)
                co2 = co2[end-1,i2_,i3_]        
            elseif @mediumBorder(2,-1)
                co2 = co2[i1_,2,i3_]        
            elseif @mediumBorder(2,1)
                co2 = co2[i1_,end-1,i3_]        
            elseif @mediumBorder(3,-1)
                co2 = co2[i1_,i2_,2]        
            elseif @mediumBorder(3,1)
                co2 = co2[i1_,i2_,end-1]        
            end

        end,

        mediumAlg = CBMIntegrators.DGADI(difussionCoefs=(co2=:Dco2,)),

        compile=false
    )

    ###########################################################################
    # Parameters
    ###########################################################################
    parameters = Dict(
        
        # Table 1: Parameters Volume Model
        :v =>         2494,     #μm³
        :vN =>        540,      #μm³
        :rF =>        3.0,      #h⁻¹
        :rC =>        0.27,     #h⁻¹
        :rN =>        0.33,     #h⁻¹
        :vNSTarget => 135,      #μm³
        :fCN =>       3.6,      #adimensional
        :fF =>        0.75,     #adimensional

        # Table 2: Ki67 Advanced Cell Cycle Model
        :tPhaseK1 => 13,        #h
        :tPhaseK2 => 2.5,       #h
        :tPhaseQ => 3.62,       #h

        # Table 3: Ki67 Basic Cell Cycle Model
        :tPhaseK => 15.5,       #h
        :tPhaseQ => 4.59,       #h

        # Table 4: Live Cells Cycle Model
        :rb => 0.0432,          #h⁻1

        # 1.3.1 Apoptosis
        :rFApop => 3.0,         #h⁻1
        :rCApop => 1.0,         #h⁻1
        :rNApop => 0.35,        #h⁻1
        :rDeathApop => 0.01,    #h⁻1
        :tApop => 8.6,          #h (unspecified in docs)

        # 1.3.2 Necrosis
        :rFNecEarly => 0.67,     #h⁻1
        :rFNecLate => 0.05,      #h⁻1
        :rCNec => 0.0032,        #h⁻1
        :rNNec => 0.015,         #h⁻1

        # 1.3.3 Calcification
        :rCalc => 0.0042,        #h⁻1

        # 1.4.6 Table 5 Mechanics Radius
        :ra => 1.25,             #adimensional
        :adhesion => 1,          #adimesional

        # 1.4.6 Table 5 Mechanics CellCell
        :ncca => 1,              #adimensional
        :nccr => 1,              #adimensional
        :cccr =>60* 10. ,        #ν μm h⁻1
        :ccca =>60* 0.4,         #ν μm h⁻1

        # 1.4.6 Table 5 Mechanics BM
        :ncba => 1,              #adimensional
        :ncbr => 1,              #adimensional
        :ccbr =>60* 10.,         #ν μm h⁻1
        :ccba =>60* 4,           #ν μm h⁻1

        # 1.4.6 Table 7 Mechanics Motility
        :tPers => 15,            #min
        :sloc =>60* 1.,          #μm h⁻1

        # Co2 mechanics
        :Dco2 => 10. ^ 5,
        :λco2 => 0.1,
        :co2saturation => 70.
    )

end