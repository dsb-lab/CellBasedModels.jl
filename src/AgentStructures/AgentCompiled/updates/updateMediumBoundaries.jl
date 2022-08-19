function changeARGS(code,f)
    code = postwalk(x -> @capture(x,ARGS_) && ARGS == :ARGS_ ? f : x, code)

    return code
end

"""
    function boundariesFunctionDefinition(p::AgentCompiled,platform::String)

Generate the code and functions declared in `UpdateMediumInteraction` related with boundaries and adds the code generated to `AgentCompiled`.

# Args
 - **p::AgentCompiled**:  AgentCompiled structure containing all the created code when compiling.
 - **platform::String**: Platform to adapt the code.

# Returns
 -  Nothing
"""
function boundariesFunctionDefinition(p::AgentCompiled, platform::String)

    finalCode = quote end

    ret = false

    if "UpdateMedium" in keys(p.agent.declaredUpdates)

        #Remove all the lines that are not Boundary lines
        code = copy(p.agent.declaredUpdates["UpdateMedium"])
        mediumsym = []
        for i in 1:p.agent.dims
            for key in keys(MEDIUMBOUNDARYSYMBOLS[i])
                append!(mediumsym,MEDIUMBOUNDARYSYMBOLS[i][key])
            end
        end
        code = postwalk(x -> @capture(x,f1_() = f2_) && !(f1 in mediumsym) ? :nothing : x, code)
        code = postwalk(x -> @capture(x,f1_()) && !(f1 in mediumsym) ? :nothing : x, code)
        code = postwalk(x -> @capture(x,f1_(f3_) = f2_) && !(f1 in mediumsym) ? :nothing : x, code)
        code = postwalk(x -> @capture(x,f1_(f3_)) && !(f1 in mediumsym) ? :nothing : x, code)

        codeC = quote end
        codeC.args = [i for i in code.args if i !== :nothing]

        if p.agent.dims == 1
            basis_structure = quote 
                                if ic1_ == 1 BOUNDARY1MIN_ 
                                elseif ic1_ == Nx_ BOUNDARY1MAX_ 
                                else INNERMEDIUM_ end 
                              end
        elseif p.agent.dims == 2
            basis_structure = quote 
                                if ic1_ == 1 BOUNDARY1MIN_ 
                                elseif ic1_ == Nx_ BOUNDARY1MAX_ 
                                elseif ic2_ == 1 BOUNDARY2MIN_
                                elseif ic2_ == Ny_ BOUNDARY2MAX_  
                                else INNERMEDIUM_ end 
                              end
        elseif p.agent.dims == 3
            basis_structure = quote 
                                if ic1_ == 1 BOUNDARY1MIN_ 
                                elseif ic1_ == Nx_ BOUNDARY1MAX_ 
                                elseif ic2_ == 1 BOUNDARY2MIN_
                                elseif ic2_ == Ny_ BOUNDARY2MAX_
                                elseif ic3_ == 1 BOUNDARY3MIN_
                                elseif ic3_ == Nz_ BOUNDARY3MAX_ 
                                else INNERMEDIUM_ end 
                              end
        end

        for i in 1:p.agent.dims

            for key in keys(MEDIUMBOUNDARYSYMBOLS[i])
                #Remove lines that are of the other axis
                code = postwalk(x -> @capture(x,f1_() = f2_) && !(f1 in MEDIUMBOUNDARYSYMBOLS[i][key]) ? :nothing : x, codeC)
                code = postwalk(x -> @capture(x,f1_()) && !(f1 in MEDIUMBOUNDARYSYMBOLS[i][key]) ? :nothing : x, code)
                code = postwalk(x -> @capture(x,f1_(f3_) = f2_) && !(f1 in MEDIUMBOUNDARYSYMBOLS[i][key]) ? :nothing : x, code)
                code = postwalk(x -> @capture(x,f1_(f3_)) && !(f1 in MEDIUMBOUNDARYSYMBOLS[i][key]) ? :nothing : x, code)
                code.args = [j for j in code.args if j !== :nothing]
                #For axis symbols
                codN = quote end
                codD = quote end
                codPer = quote end
                for s in p.agent.declaredSymbols["Medium"]
                    push!(codN.args,:($(MEDIUMBOUNDARYSYMBOLS[i][key][1])($s) = ARGS_))
                    push!(codD.args,:($(MEDIUMBOUNDARYSYMBOLS[i][key][2])($s) = ARGS_))
                    push!(codPer.args,:($(MEDIUMBOUNDARYSYMBOLS[i][key][3])($s)))
                end

                code = postwalk(x -> @capture(x,f1_() = f2_) && f1 == MEDIUMBOUNDARYSYMBOLS[i][key][1] ? changeARGS(codN,f2) : x, code)
                code = postwalk(x -> @capture(x,f1_() = f2_) && f1 == MEDIUMBOUNDARYSYMBOLS[i][key][2] ? changeARGS(codD,f2) : x, code)
                code = postwalk(x -> @capture(x,f1_())  && f1 == MEDIUMBOUNDARYSYMBOLS[i][key][3] ? codPer : x, code)

                for (j,s) in enumerate(p.agent.declaredSymbols["Medium"])

                    up = j #No update in medium

                    dx = DIFFMEDIUM[i]

                    #Neumann
                    if key == "min"
                        ind1 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]; ind2 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]
                        ind1[i] = :(2); ind2[i] = :(1) 
                        code = postwalk(
                            x -> @capture(x,f1_(ss_) = f_) && ss == s && f1 == MEDIUMBOUNDARYSYMBOLS[i][key][1] ? 
                            :(mediumVCopy[$(ind2...),$up] = mediumVCopy[$(ind1...),$j] - ($f)*$(dx)) : x, 
                            code)
                    elseif key == "max"
                        ind1 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]; ind2 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]
                        ind1[i] = :($(MEDIUMSUMATIONSYMBOLS[i])-1); ind2[i] = MEDIUMSUMATIONSYMBOLS[i] 
                        code = postwalk(
                            x -> @capture(x,f1_(ss_) = f_) && ss == s && f1 == MEDIUMBOUNDARYSYMBOLS[i][key][1] ? 
                            :(mediumVCopy[$(ind2...),$up] = mediumVCopy[$(ind1...),$j] - ($f)*$(dx)) : x, 
                            code)
                    end
                
                    #Dirichlet
                    if key == "min"
                        ind2 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]
                        ind2[i] = :(1) 
                        code = postwalk(x -> @capture(x,f1_(ss_) = f_) && ss == s  && f1 == MEDIUMBOUNDARYSYMBOLS[i][key][2] ? 
                                :(mediumVCopy[$(ind2...),$up] = $f) : x, 
                                code)
                    elseif key == "max"
                        ind2 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]
                        ind2[i] = :($(MEDIUMSUMATIONSYMBOLS[i])) 
                        code = postwalk(x -> @capture(x,f1_(ss_) = f_) && ss == s  && f1 == MEDIUMBOUNDARYSYMBOLS[i][key][2] ?
                                :(mediumVCopy[$(ind2...),$up] = $f) : x, 
                                code)
                    end

                    #Periodic
                    if key == "min"
                        ind1 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]; ind2 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]; ind3 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]; ind4 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]
                        ind1[i] = :(2); ind2[i] = :(1); ind3[i] = :($(MEDIUMSUMATIONSYMBOLS[i])-1); ind4[i] = :($(MEDIUMSUMATIONSYMBOLS[i])) 
                        code = postwalk(x -> @capture(x,f1_(ss_)) && ss == s && f1 == MEDIUMBOUNDARYSYMBOLS[i][key][3] ? 
                            :(begin 
                                mediumVCopy[$(ind4...),$up] = mediumV[$(ind1...),$j]
                            end) : x, 
                            code)
                    elseif key == "max"
                        ind1 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]; ind2 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]; ind3 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]; ind4 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]
                        ind1[i] = :(2); ind2[i] = :(1); ind3[i] = :($(MEDIUMSUMATIONSYMBOLS[i])-1); ind4[i] = :($(MEDIUMSUMATIONSYMBOLS[i])) 
                        code = postwalk(x -> @capture(x,f1_(ss_)) && ss == s && f1 == MEDIUMBOUNDARYSYMBOLS[i][key][3] ? 
                            :(begin 
                                mediumVCopy[$(ind2...),$up] = mediumV[$(ind3...),$j]        
                            end) : x, 
                            code)
                    end

                end
                    
                basis_structure = postwalk(x -> @capture(x,g_) && g == MEDIUMAUXILIAR[i][key] ? 
                code : x, 
                basis_structure)            
            end

        end

        #Add inner part of update
        #Remove all the lines that are Boundary lines
        code = copy(p.agent.declaredUpdates["UpdateMedium"])

        mediumsym = []
        for i in 1:p.agent.dims
            for key in keys(MEDIUMBOUNDARYSYMBOLS[i])
                append!(mediumsym,MEDIUMBOUNDARYSYMBOLS[i][key])
            end
        end
        code = postwalk(x -> @capture(x,f1_() = f2_) && (f1 in mediumsym) ? :nothing : x, code)
        code = postwalk(x -> @capture(x,f1_()) && (f1 in mediumsym) ? :nothing : x, code)
        code = postwalk(x -> @capture(x,f1_(f3_) = f2_) && (f1 in mediumsym) ? :nothing : x, code)
        code = postwalk(x -> @capture(x,f1_(f3_)) && (f1 in mediumsym) ? :nothing : x, code)

        f = quote end
        f.args = [i for i in code.args if i !== :nothing]

        basis_structure = postwalk(x -> @capture(x,g_) && g == MEDIUMAUXILIAR[end] ? 
        f : x, 
        basis_structure)

    end

    return basis_structure
end
    