"""
    function addIntegratorMediumFTCS_!(p::Program_,platform::String)

Generate the functions related with Medium Update with FTCS integration method.

This method is unconditionally unstable for advection functions without viscosity (ecc. functions with the form `∂ₜx(x) = ∇x u(x)`). It is only advised to use with difussion equations. 
    
The discretization scheme implemented is,

``
∇x(f(u(x,t))) = (f(u(x+dx,t)) - f(u(x-dx,t)))/2dx
``

``
Δx(f(u(x,t))) = (f(u(x+dx,t+dt)) - 2 f(u(x,t+dt)) + f(u(x-dx,t+dt)))/dx^2
``

``
∂ₜ(u(x,t)) = (u(x,t+dt) - u(x,t)) / dt
``

This method is unconditionally stable.
"""
function addIntegratorMediumImplicitEuler_!(p::Program_,platform::String)

    if "UpdateMedium" in keys(p.agent.declaredUpdates)

        #Add boundary computation
        f = boundariesFunctionDefinition(p, platform)

        #Create modified operator
        for (i,j) in enumerate(p.agent.declaredSymbols["Medium"]) # Change symbol for update
            f = postwalk(x -> @capture(x,g_(s_)=v_) && s == j && g == DIFFMEDIUMSYMBOL ? divisionFactorImplicitEuler_(j,v,1) : x, f)
        end
        println(f)
        f = postwalk(x->@capture(x,s_(v_)) ? :($(adaptOperatorsMediumImplicitEuler_(v,s,p))) : x, f) # Adapt
        f = postwalk(x->@capture(x,s_) ? adaptSymbolsMediumImplicitEuler_(s,p) : x, f) # Adapt
                        
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

function adaptSymbolsMediumImplicitEuler_(s,p)

    if s == :xₘ

        return :(ic1_*dxₘ_+box[1,1])

    elseif s == :yₘ

        return :(ic2_*dyₘ_+box[2,1])

    elseif s == :zₘ

        return :(ic1_*dzₘ_+box[3,1])

    end

    return s

end

function adaptOperatorsMediumImplicitEuler_(f,op,p)

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

function divisionFactorImplicitEuler_(j,f,dims)

    div = :(1)
    if dims == 1
        fMod = postwalk(x->@capture(x,g_(v_)) && g == :Δx ? :AUX_ : x,f)
        if inexpr(fMod,:AUX_)
            par = postwalk(x->@capture(x,k_=g_) ? g : x,f)
            par = postwalk(x->@capture(x,k_*g_(v_)) && g != :Δx ? 0 : x, par)
            par = postwalk(x->@capture(x,k_*g_(v_)) && g == :Δx ? k : x, par)
            par = postwalk(x->@capture(x,g_(v_)) && g == :Δx ? 1 : x, par)
            div = :($div+2*$par)
        end
    elseif dims == 2
        fMod = postwalk(x->@capture(x,g_(v_)) && g == :Δy ? :AUX_ : x,f)
        if inexpr(fMod,:AUX_)
            par = postwalk(x->@capture(x,k_=g_) ? g : x,f)
            par = postwalk(x->@capture(x,k_*g_(v_)) && g != :Δy ? 0 : x, par)
            par = postwalk(x->@capture(x,k_*g_(v_)) && g == :Δy ? k : x, par)
            par = postwalk(x->@capture(x,g_(v_)) && g == :Δy ? 1 : x, par)
            div = :($div+2*$par)
        end
    elseif dims == 3
        fMod = postwalk(x->@capture(x,g_(v_)) && g == :Δz ? :AUX_ : x,f)
        if inexpr(fMod,:AUX_)
            par = postwalk(x->@capture(x,k_=g_) ? g : x,f)
            par = postwalk(x->@capture(x,k_*g_(v_)) && g != :Δz ? 0 : x, par)
            par = postwalk(x->@capture(x,k_*g_(v_)) && g == :Δz ? k : x, par)
            par = postwalk(x->@capture(x,g_(v_)) && g == :Δz ? 1 : x, par)
            div = :($div+2*$par)
        end
    end

    return :($j.new = ($j + ($f)*dt)/$div)
end