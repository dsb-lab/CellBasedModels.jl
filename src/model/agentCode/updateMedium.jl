"""
    function addUpdateMedium_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions related with Medium Update.
"""
function addUpdateMedium_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    if "UpdateMedium" in keys(abm.declaredUpdates)

        #Check updated
        up = symbols_(abm,abm.declaredUpdates["UpdateMedium"])
        up = up[Bool.((up[:,"placeDeclaration"].==:Model) .* Bool.((up[:,"assigned"].==true) .+ (up[:,"updated"].==true))),:]

        #Construct functions
        f = postwalk(x->@capture(x,s_(v_)) ? :($(adaptMedium_(v,s,abm,p))) : x, abm.declaredUpdates["UpdateMedium"])

        println(f)

        f = simpleFirstLoopWrapInFunction_(platform,:mediumStep_!,
                        :(begin        
                            if ic1_ > 1 && ic1_ < Nx
                                $(f)
                            end
                        end)
                        )
        
        f = vectorize_(abm,f,p)

        push!(p.declareF.args,
            f)

        push!(p.execInloop.args,
                :(@platformAdapt mediumStep_!(ARGS_)) 
            )
    end

    return nothing
end

function adaptMedium_(f,op,abm,p)

    f = vectorizeMedium_(abm,f,p)

    if op == :Δ
        if abm.dims == 1
            add = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :med_ ? :(med_[ic1_+1,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :med_ ? :(med_[ic1_-1,$j]) : x,f)

            f = :(($add+$subs-2*$f)/dx^2)
        elseif abm.dims == 2
            add = postwalk(x->@capture(x,s_[ic1_,ic2_]) && s == :med_ ? :(med_[ic1_+1,ic2_]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_]) && s == :med_ ? :(med_[ic1_-1,ic2_]) : x,f)
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_]) && s == :med_ ? :(med_[ic1_,ic2_+1]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_]) && s == :med_ ? :(med_[ic1_,ic2_-1]) : x,f)

            f = :(($add+$subs+$addy+$subsy-4*$f)/dx^2)
        elseif abm.dims == 1
            add = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_+1,ic2_,ic3_]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_-1,ic2_,ic3_]) : x,f)
            addy = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_,ic2_+1,ic3_]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_,ic2_-1,ic3_]) : x,f)
            addz = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_,ic2_,ic3_+1]) : x,f)
            subsz = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_,ic2_,ic3_-1]) : x,f)

            f = :(($add+$subs+$addy+$subsy+$addz+$subsz-6*$f)/dx^2)
        end
    end

    if op == :Δx
        if abm.dims == 1
            add = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :med_ ? :(med_[ic1_+1,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :med_ ? :(med_[ic1_-1,$j]) : x,f)

            f = :(($add+$subs-2*$f)/dx^2)
        elseif abm.dims == 2
            add = postwalk(x->@capture(x,s_[ic1_,ic2_]) && s == :med_ ? :(med_[ic1_+1,ic2_]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_]) && s == :med_ ? :(med_[ic1_-1,ic2_]) : x,f)

            f = :(($add+$subs-2*$f)/dx^2)
        elseif abm.dims == 3
            add = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_+1,ic2_,ic3_]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_-1,ic2_,ic3_]) : x,f)

            f = :(($add+$subs-2*$f)/dx^2)
        end
    end

    if op == :Δy
        if abm.dims == 1
            error("Operator Δy cannot exist in Agent with dimension 1.")
        elseif abm.dims == 2
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_]) && s == :med_ ? :(med_[ic1_,ic2_+1]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_]) && s == :med_ ? :(med_[ic1_,ic2_-1]) : x,f)

            f = :(($addy+$subsy-2*$f)/dx^2)
        elseif abm.dims == 3
            addy = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_,ic2_+1,ic3_]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_,ic2_-1,ic3_]) : x,f)

            f = :(($addy+$subsy-2*$f)/dx^2)
        end
    end

    if op == :Δz
        if abm.dims == 1
            error("Operator Δz cannot exist in Agent with dimension 1.")
        elseif abm.dims == 2
            error("Operator Δy cannot exist in Agent with dimension 2.")
        elseif abm.dims == 1
            addz = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_,ic2_,ic3_+1]) : x,f)
            subsz = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_,ic2_,ic3_-1]) : x,f)

            f = :(($addz+$subsz-2*$f)/dx^2)
        end
    end

    if op == :∇      
        if abm.dims == 1
            add = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :med_ ? :(med_[ic1_+1,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :med_ ? :(med_[ic1_-1,$j]) : x,f)

            f = :(($add-$subs)/(2*dx))
        elseif abm.dims == 2
            add = postwalk(x->@capture(x,s_[ic1_,ic2_]) && s == :med_ ? :(med_[ic1_+1,ic2_]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_]) && s == :med_ ? :(med_[ic1_-1,ic2_]) : x,f)
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_]) && s == :med_ ? :(med_[ic1_,ic2_+1]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_]) && s == :med_ ? :(med_[ic1_,ic2_-1]) : x,f)

            f = :(($add-$subs+$addy-$subsy)/(2*dx))
        elseif abm.dims == 1
            add = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_+1,ic2_,ic3_]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_-1,ic2_,ic3_]) : x,f)
            addy = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_,ic2_+1,ic3_]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_,ic2_-1,ic3_]) : x,f)
            addz = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_,ic2_,ic3_+1]) : x,f)
            subsz = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_,ic2_,ic3_-1]) : x,f)

            f = :(($add-$subs+$addy-$subsy+$addz-$subsz)/(2*dx))
        end
    end

    if op == :∇x
        if abm.dims == 1
            add = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :med_ ? :(med_[ic1_+1,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :med_ ? :(med_[ic1_-1,$j]) : x,f)

            f = :(($add-$subs)/(2*dx))
        elseif abm.dims == 2
            add = postwalk(x->@capture(x,s_[ic1_,ic2_]) && s == :med_ ? :(med_[ic1_+1,ic2_]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_]) && s == :med_ ? :(med_[ic1_-1,ic2_]) : x,f)

            f = :(($add-$subs)/(2*dx))
        elseif abm.dims == 3
            add = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_+1,ic2_,ic3_]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_-1,ic2_,ic3_]) : x,f)

            f = :(($add-$subs)/(2*dx))
        end
    end

    if op == :∇y
        if abm.dims == 1
            error("Operator Δy cannot exist in Agent with dimension 1.")
        elseif abm.dims == 2
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_]) && s == :med_ ? :(med_[ic1_,ic2_+1]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_]) && s == :med_ ? :(med_[ic1_,ic2_-1]) : x,f)

            f = :(($addy-$subsy)/(2*dx))
        elseif abm.dims == 3
            addy = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_,ic2_+1,ic3_]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_,ic2_-1,ic3_]) : x,f)

            f = :(($addy-$subsy)/(2*dx))
        end
    end

    if op == :∇z
        if abm.dims == 1
            error("Operator Δz cannot exist in Agent with dimension 1.")
        elseif abm.dims == 2
            error("Operator Δy cannot exist in Agent with dimension 2.")
        elseif abm.dims == 1
            addz = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_,ic2_,ic3_+1]) : x,f)
            subsz = postwalk(x->@capture(x,s_[ic1_]) && s == :med_ ? :(med_[ic1_,ic2_,ic3_-1]) : x,f)

            f = :(($addz-$subsz)/(2*dx))
        end
    end

    return f

end

function vectorizeMedium_(abm,f,p)

    for (i,j) in enumerate(abm.declaredSymbols["Medium"])
        if abm.dims == 1
            f = postwalk(x->@capture(x,s_) && s == j ? :(med_[ic1_,$i]) : x,f)
        elseif abm.dims == 2
            f = postwalk(x->@capture(x,s_) && s == j ? :(med_[ic1_,ic2_,$i]) : x,f)
        elseif abm.dims == 3
            f = postwalk(x->@capture(x,s_) && s == j ? :(med_[ic1_,ic2_,ic3_,$i]) : x,f)
        end
    end

    return f
end