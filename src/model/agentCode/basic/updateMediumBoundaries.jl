function changeARGS(code,f)
    code = postwalk(x -> @capture(x,ARGS_) && ARGS == :ARGS_ ? f : x, code)

    return code
end

function boundariesFunctionDefinition(p::Program_, platform::String)

    finalCode = quote end

    ret = false

    if "UpdateMedium" in keys(p.agent.declaredUpdates)

        #Remove all the lines that are not Boundary lines
        code = copy(p.agent.declaredUpdates["UpdateMedium"])
        mediumsym = []
        for i in 1:p.agent.dims
            append!(mediumsym,MEDIUMBOUNDARYSYMBOLS[i])
        end
        code = postwalk(x -> @capture(x,f1_() = f2_) && !(f1 in mediumsym) ? :nothing : x, code)
        code = postwalk(x -> @capture(x,f1_()) && !(f1 in mediumsym) ? :nothing : x, code)
        code = postwalk(x -> @capture(x,f1_(f3_) = f2_) && !(f1 in mediumsym) ? :nothing : x, code)
        code = postwalk(x -> @capture(x,f1_(f3_)) && !(f1 in mediumsym) ? :nothing : x, code)

        codeC = quote end
        codeC.args = [i for i in code.args if i !== :nothing]

        for i in 1:p.agent.dims

            #Remove lines that are of the other axis
            code = postwalk(x -> @capture(x,f1_() = f2_) && !(f1 in MEDIUMBOUNDARYSYMBOLS[i]) ? :nothing : x, codeC)
            code = postwalk(x -> @capture(x,f1_()) && !(f1 in MEDIUMBOUNDARYSYMBOLS[i]) ? :nothing : x, code)
            code = postwalk(x -> @capture(x,f1_(f3_) = f2_) && !(f1 in MEDIUMBOUNDARYSYMBOLS[i]) ? :nothing : x, code)
            code = postwalk(x -> @capture(x,f1_(f3_)) && !(f1 in MEDIUMBOUNDARYSYMBOLS[i]) ? :nothing : x, code)
            code.args = [j for j in code.args if j !== :nothing]
            #For axis symbols
            codNMin = quote end
            codNMax = quote end
            codMin = quote end
            codMax = quote end
            codPer = quote end
            for s in p.agent.declaredSymbols["Medium"]
                push!(codNMin.args,:($(MEDIUMBOUNDARYSYMBOLS[i][1])($s) = ARGS_))
                push!(codNMax.args,:($(MEDIUMBOUNDARYSYMBOLS[i][2])($s) = ARGS_))
                push!(codMin.args,:($(MEDIUMBOUNDARYSYMBOLS[i][3])($s) = ARGS_))
                push!(codMax.args,:($(MEDIUMBOUNDARYSYMBOLS[i][4])($s) = ARGS_))
                push!(codPer.args,:($(MEDIUMBOUNDARYSYMBOLS[i][5])($s)))
            end

            code = postwalk(x -> @capture(x,f1_() = f2_) && f1 == MEDIUMBOUNDARYSYMBOLS[i][1] ? changeARGS(codNMin,f2) : x, code)
            code = postwalk(x -> @capture(x,f1_() = f2_) && f1 == MEDIUMBOUNDARYSYMBOLS[i][2] ? changeARGS(codNMax,f2) : x, code)
            code = postwalk(x -> @capture(x,f1_() = f2_) && f1 == MEDIUMBOUNDARYSYMBOLS[i][3] ? changeARGS(codMin,f2) : x, code)
            code = postwalk(x -> @capture(x,f1_() = f2_) && f1 == MEDIUMBOUNDARYSYMBOLS[i][4] ? changeARGS(codMax,f2) : x, code)
            code = postwalk(x -> @capture(x,f1_())  && f1 == MEDIUMBOUNDARYSYMBOLS[i][5] ? codPer : x, code)

            for (j,s) in enumerate(p.agent.declaredSymbols["Medium"])

                up = j #No update in medium

                dx = DIFFMEDIUM[i]

                #Neumann
                ind1 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]; ind2 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]
                ind1[i] = :(2); ind2[i] = :(1) 
                code = postwalk(x -> @capture(x,f1_(ss_) = f_) && ss == s && f1 == MEDIUMBOUNDARYSYMBOLS[i][1] ? :(mediumVCopy[$(ind2...),$up] = mediumVCopy[$(ind1...),$j] - ($f)*$(dx)) : x, code)

                ind1 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]; ind2 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]
                ind1[i] = :($(MEDIUMSUMATIONSYMBOLS[i])-1); ind2[i] = MEDIUMSUMATIONSYMBOLS[i] 
                code = postwalk(x -> @capture(x,f1_(ss_) = f_) && ss == s && f1 == MEDIUMBOUNDARYSYMBOLS[i][2] ? :(mediumVCopy[$(ind2...),$up] = mediumVCopy[$(ind1...),$j] - ($f)*$(dx)) : x, code)
            
                #Dirichlet
                ind2 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]
                ind2[i] = :(1) 
                code = postwalk(x -> @capture(x,f1_(ss_) = f_) && ss == s  && f1 == MEDIUMBOUNDARYSYMBOLS[i][3] ? 
                        :(mediumVCopy[$(ind2...),$up] = $f) : x, code)

                ind2 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]
                ind2[i] = :($(MEDIUMSUMATIONSYMBOLS[i])) 
                code = postwalk(x -> @capture(x,f1_(ss_) = f_) && ss == s  && f1 == MEDIUMBOUNDARYSYMBOLS[i][4] ?
                        :(mediumVCopy[$(ind2...),$up] = $f) : x, code)

                #Periodic
                ind1 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]; ind2 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]; ind3 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]; ind4 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]
                ind1[i] = :(2); ind2[i] = :(1); ind3[i] = :($(MEDIUMSUMATIONSYMBOLS[i])-1); ind4[i] = :($(MEDIUMSUMATIONSYMBOLS[i])) 
                code = postwalk(x -> @capture(x,f1_(ss_)) && ss == s && f1 == MEDIUMBOUNDARYSYMBOLS[i][5] ? 
                :(begin 
                mediumVCopy[$(ind4...),$up] = mediumV[$(ind1...),$j]
                mediumVCopy[$(ind2...),$up] = mediumV[$(ind3...),$j]        
                end)
                : x, code)
            end

            push!(finalCode.args,simpleGridLoop_(platform, code, p.agent.dims-1,indexes=[j for j in [1,2,3] if j != i]))

            # if platform == "cpu"
            #     if p.agent.dims == 1
            #         final_code = quote
            #             $code
            #         end
            #     elseif p.agent.dims == 2
            #         sum1 = [j for j in MEDIUMITERATIONSYMBOLS[1:2] if j != MEDIUMITERATIONSYMBOLS[i]]
            #         nmax = [j for j in MEDIUMSUMATIONSYMBOLS[1:2] if j != MEDIUMSUMATIONSYMBOLS[i]]
                    
            #         final_code = quote
            #             Theads.@theads for $(sum1[1]) in 2:1:$(nmax[1])-1
            #                 $code
            #             end
            #         end
            #     elseif p.agent.dims == 3
            #         sum1 = [j for j in MEDIUMITERATIONSYMBOLS if j != MEDIUMITERATIONSYMBOLS[i]]
            #         nmax = [j for j in MEDIUMSUMATIONSYMBOLS if j != MEDIUMSUMATIONSYMBOLS[i]]
                    
            #         final_code = quote
            #             Theads.@theads for $(sum1[1]) in 2:1:$(nmax[1])-1
            #                 for $(sum1[2]) in 2:1:$(nmax[2])-1
            #                     $code
            #                 end
            #             end
            #         end
            #     end
            # else
            #     if p.agent.dims == 1
            #         final_code = quote
            #             $code
            #         end
            #     elseif p.agent.dims == 2
            #         sum1 = [j for j in MEDIUMITERATIONSYMBOLS[1:2] if j != MEDIUMITERATIONSYMBOLS[i]]
            #         nmax = [j for j in MEDIUMSUMATIONSYMBOLS[1:2] if j != MEDIUMSUMATIONSYMBOLS[i]]
                    
            #         final_code = quote
            #             for $(sum1[1]) in index_+1:stride_:$(nmax[1])-1
            #                 $code
            #             end
            #         end
            #     elseif p.agent.dims == 3
            #         sum1 = [j for j in MEDIUMITERATIONSYMBOLS if j != MEDIUMITERATIONSYMBOLS[i]]
            #         nmax = [j for j in MEDIUMSUMATIONSYMBOLS if j != MEDIUMSUMATIONSYMBOLS[i]]
                    
            #         final_code = quote
            #             for $(sum1[1]) in index_+1:stride_:$(nmax[1])-1
            #                 for $(sum1[2]) in 2:1:$(nmax[2])-1
            #                     $code
            #                 end
            #             end
            #         end
            #     end
            # end

            if length([i for i in codeC.args if typeof(i) != LineNumberNode]) > 0
                ret = true
            end
        end

        if ret
            finalCode = vectorizeMedium_(p.agent,finalCode,p)

            finalFunction = wrapInFunction_(:mediumBoundaryStep_!,finalCode)

            push!(p.execInit.args, ## Add it to code
            :(@platformAdapt mediumBoundaryStep_!(ARGS_); mediumV .= mediumVCopy) 
            )        

            push!(p.declareF.args, ## Add it to code
            finalFunction 
            )        
        end
    end

    return ret
end
    