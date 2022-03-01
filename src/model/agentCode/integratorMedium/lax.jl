"""
    function addIntegratorMediumImplicitEuler_!(p::Program_,platform::String)

Generate the functions related with Medium Update with Implicit Euler integration method integration method.

The discretization scheme implemented is,

``
∇x(f(u(x,t))) = (f(u(x+dx,t)) - f(u(x-dx,t)))/2dx
``

``
Δx(f(u(x,t))) = (f(u(x+dx,t+dt)) - 2 f(u(x,t+dt)) + f(u(x-dx,t+dt)))/dx^2
``

``
∂ₜ(u(x,t)) = (u(x,t+dt) - (u(x+dx,t)+u(x-dx,t))/2) / dt
``

The accuracy of this scheme is,

``O(Δt)+O(Δx²/Δt)``

The stability of this method for advective equations is (ecc. equations of the form ``∂ₜx(x) = α ∇x u(x)```),

``|α Δt/Δx| ≤ 1``
"""
function addIntegratorMediumLax_!(p::Program_,platform::String)

    if "UpdateMedium" in keys(p.agent.declaredUpdates)

        #Add boundary computation
        f = boundariesFunctionDefinition(p, platform)

        error()

        #Create modified operator
        for (i,j) in enumerate(p.agent.declaredSymbols["Medium"]) # Change symbol for update
            ind1 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims]; 
            ind2 = Vector{Union{Symbol,Expr,Int}}(MEDIUMITERATIONSYMBOLS)[1:p.agent.dims];
            ind1[i] = :($(ind1[i])+1); ind2[i] = :($(ind2[i])-1);
            add = :((mediumV[$(ind1)...,$i] + mediumV[$(ind2)...,$i])/2)
            f = postwalk(x -> @capture(x,g_(s_)=v_) && s == j && g == DIFFMEDIUMSYMBOL ? :($j.new = $add + ($v)*dt) : x, f)
        end
        f = postwalk(x->@capture(x,s_(v_)) ? :($(adaptOperatorsMediumFTCS_(v,s,p))) : x, f) # Adapt
        f = postwalk(x->@capture(x,s_) ? adaptSymbolsMediumFTCS_(s,p) : x, f) # Adapt
                        
        f = vectorizeMedium_(p.agent,f,p)

        f = simpleGridLoopWrapInFunction_(platform,:mediumStep_!, f, p.agent.dims)

        push!(p.declareF.args, ## Add it to code
                f 
            )        
        
        if p.agent.dims == 1
            wrapFunction = quote @platformAdapt1 mediumStep_!(ARGS_) end
        elseif p.agent.dims == 2
            wrapFunction = quote @platformAdapt2 mediumStep_!(ARGS_) end
        elseif p.agent.dims == 3
            wrapFunction = quote @platformAdapt3 mediumStep_!(ARGS_) end
        end

        push!(p.declareF.args, ## Add it to code
            wrapFunction 
            )        

        if p.agent.dims == 1
            push!(p.execInloop.args, ## Add it to code
            :(@platformAdapt1 mediumStep_!(ARGS_)) 
            )        
        elseif p.agent.dims == 2
            push!(p.execInloop.args, ## Add it to code
            :(@platformAdapt2 mediumStep_!(ARGS_)) 
            )        
        elseif p.agent.dims == 3
            push!(p.execInloop.args, ## Add it to code
            :(@platformAdapt3 mediumStep_!(ARGS_)) 
            )        
        end
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

        f = :(δMedium_(round(Int,($f-simulationBox[1,1])/dxₘ_)+1,ic1_))

    elseif op == :δy

        if p.agent.dims < 2
            error("Operator δy cannot be used in Agent with dimension 1.")
        end

        f = :(δMedium_(round(Int,($f-simulationBox[2,1])/dyₘ_)+1,ic2_))

    elseif op == :δz

        if p.agent.dims < 3
            error("Operator δz cannot be used in Agent with dimension 1 or 2.")
        end

        f = :(δMedium_(round(Int,($f-simulationBox[3,1])/dzₘ_)+1,ic3_))

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