"""
    function addUpdateMedium_!(p::Program_,platform::String)

Generate the functions related with Medium Update.
"""
function addIntegratorMediumFTCS_!(p::Program_,platform::String)

    if "UpdateMedium" in keys(p.agent.declaredUpdates)

        #Add boundary computation
        boundaryFunction = boundariesFunctionDefinition(p, platform)

        #Remove all the lines that are Boundary lines
        code = copy(p.agent.declaredUpdates["UpdateMedium"])

        mediumsym = []
        for i in 1:p.agent.dims
            append!(mediumsym,MEDIUMBOUNDARYSYMBOLS[i])
        end
        code = postwalk(x -> @capture(x,f1_() = f2_) && (f1 in mediumsym) ? :nothing : x, code)
        code = postwalk(x -> @capture(x,f1_()) && (f1 in mediumsym) ? :nothing : x, code)
        code = postwalk(x -> @capture(x,f1_(f3_) = f2_) && (f1 in mediumsym) ? :nothing : x, code)
        code = postwalk(x -> @capture(x,f1_(f3_)) && (f1 in mediumsym) ? :nothing : x, code)

        f = quote end
        f.args = [i for i in code.args if i !== :nothing]

        #Create modified operator
        for (i,j) in enumerate(p.agent.declaredSymbols["Medium"]) # Change symbol for update
            f = postwalk(x -> @capture(x,g_(s_)=v_) && s == j && g == DIFFMEDIUMSYMBOL ? :($j.new = $j + ($v)*dt) : x, f)
        end
        f = postwalk(x->@capture(x,s_(v_)) ? :($(adaptOperatorsMediumFTCS_(v,s,p))) : x, f) # Adapt
        f = postwalk(x->@capture(x,s_) ? adaptSymbolsMediumFTCS_(s,p) : x, f) # Adapt
                        
        f = vectorizeMedium_(p.agent,f,p)

        f = simpleGridLoopWrapInFunction_(platform,:mediumInnerStep_!, f, p.agent.dims)

        #Remove count over boundaries
        if platform == "cpu"
            f = postwalk(x->@capture(x,1:1:Nx_) && Nx == :Nx_ ? :(2:1:Nx_-1) : x, f)
            f = postwalk(x->@capture(x,1:1:Ny_) && Ny == :Ny_ ? :(2:1:Ny_-1) : x, f)
            f = postwalk(x->@capture(x,1:1:Nz_) && Nz == :Nz_ ? :(2:1:Nz_-1) : x, f)
        elseif platform == "gpu"
            f = postwalk(x->@capture(x,indexX_:strideX_:Nx_) && Nx == :Nx_ ? :(indexX_+1:strideX_:Nx_-1) : x, f)
            f = postwalk(x->@capture(x,indexY_:strideY_:Ny_) && Ny == :Ny_ ? :(indexY_+1:strideY_:Ny_-1) : x, f)
            f = postwalk(x->@capture(x,indexZ_:strideZ_:Nz_) && Nz == :Nz_ ? :(indexZ_+1:strideZ_:Nz_-1) : x, f)
        end
        push!(p.declareF.args, ## Add it to code
                f 
            )        
        
        if p.agent.dims == 1
            wrapFunction = quote @platformAdapt1 mediumInnerStep_!(ARGS_) end
        elseif p.agent.dims == 2
            wrapFunction = quote @platformAdapt2 mediumInnerStep_!(ARGS_) end
        elseif p.agent.dims == 3
            wrapFunction = quote @platformAdapt3 mediumInnerStep_!(ARGS_) end
        end

        if boundaryFunction
            if p.agent.dims == 1
                push!(wrapFunction.args, ## Add it to code
                :(@platformAdapt1 mediumBoundaryStep_!(ARGS_)) 
                )        
            elseif p.agent.dims == 2
                push!(wrapFunction.args, ## Add it to code
                :(@platformAdapt2 mediumBoundaryStep_!(ARGS_)) 
                )        
            elseif p.agent.dims == 3
                push!(wrapFunction.args, ## Add it to code
                :(@platformAdapt3 mediumBoundaryStep_!(ARGS_)) 
                )        
            end
        end

        # if "UpdateMediumInteraction" in keys(p.agent.declaredUpdates)
        #     push!(wrapFunction.args,:(@platformAdapt mediumInteractionStep_!(ARGS_)))
        # end

        fWrap = wrapInFunction_(:mediumStep_!, 
                                wrapFunction
                                )

        push!(p.declareF.args, ## Add it to code
            fWrap 
            )        
        # println(prettify(code))

        push!(p.execInloop.args,
                :(mediumStep_!(ARGS_)) 
            )
    end

    return nothing
end

function adaptSymbolsMediumFTCS_(s,p)

    if s == :xₘ

        return :(ic1_*dxₘ_+box[1,1])

    elseif s == :yₘ

        return :(ic2_*dyₘ_+box[2,1])

    elseif s == :zₘ

        return :(ic1_*dzₘ_+box[3,1])

    end

    return s

end

function adaptOperatorsMediumFTCS_(f,op,p)

    f = vectorizeMedium_(p.agent,f,p)

    if op == :δx

        f = :(δMedium_(round(Int,($f-simulationBox[1,1])/dxₘ_)+2,ic1_))

    elseif op == :δy

        if p.agent.dims < 2
            error("Operator δy cannot be used in Agent with dimension 1.")
        end

        f = :(δMedium_(round(Int,($f-simulationBox[2,1])/dyₘ_)+2,ic2_))

    elseif op == :δz

        if p.agent.dims < 3
            error("Operator δz cannot be used in Agent with dimension 1 or 2.")
        end

        f = :(δMedium_(round(Int,($f-simulationBox[3,1])/dzₘ_)+2,ic3_))

    elseif op == :Δ
        if p.agent.dims == 1
            add = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,$j]) : x,f)

            f = :(($add+$subs-2*$f)/dxₘ_^2)
        elseif p.agent.dims == 2
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,$j]) : x,f)
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,$j]) : x,f)

            f = :(($add+$subs-2*$f)/dxₘ_^2+($addy+$subsy-2*$f)/dyₘ_^2)
        elseif p.agent.dims == 3
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,ic3_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,ic3_,$j]) : x,f)
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,ic3_,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,ic3_,$j]) : x,f)
            addz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_+1,$j]) : x,f)
            subsz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_-1,$j]) : x,f)

            f = :(($add+$subs-2*$f)/dxₘ_^2+($addy+$subsy-2*$f)/dyₘ_^2+($addz+$subsz-2*$f)/dzₘ_^2)

        end
    elseif op == :Δx
        if p.agent.dims == 1
            add = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,$j]) : x,f)

            f = :(($add+$subs-2*$f)/dxₘ_^2)
        elseif p.agent.dims == 2
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,$j]) : x,f)

            f = :(($add+$subs-2*$f)/dxₘ_^2)
        elseif p.agent.dims == 3
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,ic3_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,ic3_,$j]) : x,f)

            f = :(($add+$subs-2*$f)/dxₘ_^2)
        end
    elseif op == :Δy
        if p.agent.dims == 1
            error("Operator Δy cannot exist in Agent with dimension 1.")
        elseif p.agent.dims == 2
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,$j]) : x,f)

            f = :(($addy+$subsy-2*$f)/dyₘ_^2)
        elseif p.agent.dims == 3
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,ic3_,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,ic3_,$j]) : x,f)

            f = :(($addy+$subsy-2*$f)/dyₘ_^2)
        end
    elseif op == :Δz
        if p.agent.dims == 1
            error("Operator Δz cannot exist in Agent with dimension 1.")
        elseif p.agent.dims == 2
            error("Operator Δz cannot exist in Agent with dimension 2.")
        elseif p.agent.dims == 3
            addz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_+1,$j]) : x,f)
            subsz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_-1,$j]) : x,f)

            f = :(($addz+$subsz-2*$f)/dzₘ_^2)
        end
    elseif op == :∇      
        if p.agent.dims == 1
            add = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,$j]) : x,f)

            f = :(($add-$subs)/(2*dxₘ_))
        elseif p.agent.dims == 2
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,$j]) : x,f)
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,$j]) : x,f)

            f = :(($add-$subs)/(2*dxₘ_)+($addy-$subsy)/(2*dyₘ_))
        elseif p.agent.dims == 3
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,ic3_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,ic3_,$j]) : x,f)
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,ic3_,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,ic3_,$j]) : x,f)
            addz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_+1,$j]) : x,f)
            subsz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_-1,$j]) : x,f)

            f = :(($add-$subs)/(2*dxₘ_)+($addy-$subsy)/(2*dyₘ_)+($addz-$subsz)/(2*dzₘ_))
        end
    elseif op == :∇x
        if p.agent.dims == 1
            add = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,$j]) : x,f)

            f = :(($add-$subs)/(2*dxₘ_))
        elseif p.agent.dims == 2
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,$j]) : x,f)

            f = :(($add-$subs)/(2*dxₘ_))
        elseif p.agent.dims == 3
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,ic3_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,ic3_,$j]) : x,f)

            f = :(($add-$subs)/(2*dxₘ_))
        end
    elseif op == :∇y
        if p.agent.dims == 1
            error("Operator Δy cannot exist in Agent with dimension 1.")
        elseif p.agent.dims == 2
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,$j]) : x,f)

            f = :(($addy-$subsy)/(2*dyₘ_))
        elseif p.agent.dims == 3
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,ic3_,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,ic3_,$j]) : x,f)

            f = :(($addy-$subsy)/(2*dyₘ_))
        end
    elseif op == :∇z
        if p.agent.dims == 1
            error("Operator Δz cannot exist in Agent with dimension 1.")
        elseif p.agent.dims == 2
            error("Operator Δy cannot exist in Agent with dimension 2.")
        elseif p.agent.dims == 3
            addz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_+1,$j]) : x,f)
            subsz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_-1,$j]) : x,f)

            f = :(($addz-$subsz)/(2*dzₘ_))
        end
    end

    return f

end