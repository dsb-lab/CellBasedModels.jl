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

            #Make function to compute everything inside the volume

        f = abm.declaredUpdates["UpdateMedium"]
        for (i,j) in enumerate(abm.declaredSymbols["Medium"]) # Change symbol for update
            s = Meta.parse(string(MEDIUMSYMBOL,j))
            f = postwalk(x -> @capture(x,ss_=v__) && ss == s ? :($j = $j + $(v...)) : x, f)
        end
        f = postwalk(x->@capture(x,s_(v_)) ? :($(adaptMedium_(v,s,abm,p))) : x, f) # Adapt

        f = simpleGridLoopWrapInFunction_(platform,:mediumInnerStep_!, f, abm.dims)
        f = postwalk(x->@capture(x,1:Nx_) && Nx == :Nx_ ? :(2:Nx_-1) : x, f)
        f = postwalk(x->@capture(x,1:Ny_) && Ny == :Ny_ ? :(2:Ny_-1) : x, f)
        f = postwalk(x->@capture(x,1:Nz_) && Nz == :Nz_ ? :(2:Nz_-1) : x, f)
                        
        f = vectorize_(abm,f,p)

            #Make function to compute the boundaries
        code = quote end

        

        # println(prettify(code))

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
            add = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,$j]) : x,f)

            f = :(($add+$subs-2*$f)/dx^2)
        elseif abm.dims == 2
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,$j]) : x,f)
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,$j]) : x,f)

            f = :(($add+$subs+$addy+$subsy-4*$f)/dx^2)
        elseif abm.dims == 3
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,ic3_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,ic3_,$j]) : x,f)
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,ic3_,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,ic3_,$j]) : x,f)
            addz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_+1,$j]) : x,f)
            subsz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_-1,$j]) : x,f)

            f = :(($add+$subs+$addy+$subsy+$addz+$subsz-6*$f)/dx^2)

        end
    end

    if op == :Δx
        if abm.dims == 1
            add = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,$j]) : x,f)

            f = :(($add+$subs-2*$f)/dx^2)
        elseif abm.dims == 2
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,$j]) : x,f)

            f = :(($add+$subs-2*$f)/dx^2)
        elseif abm.dims == 3
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,ic3_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,ic3_,$j]) : x,f)

            f = :(($add+$subs-2*$f)/dx^2)
        end
    end

    if op == :Δy
        if abm.dims == 1
            error("Operator Δy cannot exist in Agent with dimension 1.")
        elseif abm.dims == 2
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,$j]) : x,f)

            f = :(($addy+$subsy-2*$f)/dx^2)
        elseif abm.dims == 3
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,ic3_,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,ic3_,$j]) : x,f)

            f = :(($addy+$subsy-2*$f)/dx^2)
        end
    end

    if op == :Δz
        if abm.dims == 1
            error("Operator Δz cannot exist in Agent with dimension 1.")
        elseif abm.dims == 2
            error("Operator Δy cannot exist in Agent with dimension 2.")
        elseif abm.dims == 3
            addz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_+1,$j]) : x,f)
            subsz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_-1,$j]) : x,f)

            f = :(($addz+$subsz-2*$f)/dx^2)
        end
    end

    if op == :∇      
        if abm.dims == 1
            add = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,$j]) : x,f)

            f = :(($add-$subs)/(2*dx))
        elseif abm.dims == 2
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,$j]) : x,f)
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,$j]) : x,f)

            f = :(($add-$subs+$addy-$subsy)/(2*dx))
        elseif abm.dims == 3
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,ic3_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,ic3_,$j]) : x,f)
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,ic3_,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,ic3_,$j]) : x,f)
            addz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_+1,$j]) : x,f)
            subsz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_-1,$j]) : x,f)

            f = :(($add-$subs+$addy-$subsy+$addz-$subsz)/(2*dx))
        end
    end

    if op == :∇x
        if abm.dims == 1
            add = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,$j]) : x,f)

            f = :(($add-$subs)/(2*dx))
        elseif abm.dims == 2
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,$j]) : x,f)

            f = :(($add-$subs)/(2*dx))
        elseif abm.dims == 3
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,ic3_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,ic3_,$j]) : x,f)

            f = :(($add-$subs)/(2*dx))
        end
    end

    if op == :∇y
        if abm.dims == 1
            error("Operator Δy cannot exist in Agent with dimension 1.")
        elseif abm.dims == 2
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,$j]) : x,f)

            f = :(($addy-$subsy)/(2*dx))
        elseif abm.dims == 3
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,ic3_,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,ic3_,$j]) : x,f)

            f = :(($addy-$subsy)/(2*dx))
        end
    end

    if op == :∇z
        if abm.dims == 1
            error("Operator Δz cannot exist in Agent with dimension 1.")
        elseif abm.dims == 2
            error("Operator Δy cannot exist in Agent with dimension 2.")
        elseif abm.dims == 3
            addz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_+1,$j]) : x,f)
            subsz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_-1,$j]) : x,f)

            f = :(($addz-$subsz)/(2*dx))
        end
    end

    return f

end

function vectorizeMedium_(abm,f,p)

    for (i,j) in enumerate(abm.declaredSymbols["Medium"])
        if abm.dims == 1
            f = postwalk(x->@capture(x,s_) && s == j ? :(mediumV[ic1_,$i]) : x,f)
        elseif abm.dims == 2
            f = postwalk(x->@capture(x,s_) && s == j ? :(mediumV[ic1_,ic2_,$i]) : x,f)
        elseif abm.dims == 3
            f = postwalk(x->@capture(x,s_) && s == j ? :(mediumV[ic1_,ic2_,ic3_,$i]) : x,f)
        end
    end

    return f
end

pI(i,M) = if i == 0 M elseif i == M+1 1 else i end
Dirichlet() = 0
Neumann(x0,x1,i,M) = if i == 0 x0 else x1 end

function Periodic(i,Mx)
    if i == 0
        i = Mx
    elseif i == Mx
        i = 1
    end

    return i
end

function Periodic(i,j,Mx,My,id)
    if id == 1
        if i == 0
            i = Mx
        elseif i == Mx
            i = 1
        end
        return i
    elseif id == 2
        if j == 0
            j = My
        elseif i == My
            j = 1
        end
        return j
    end
end

function Periodic(i,j,k,Mx,My,Mz,id)
    if id == 1
        if i == 0
            i = Mx
        elseif i == Mx
            i = 1
        end
        return i
    elseif id == 2
        if j == 0
            j = My
        elseif i == My
            j = 1
        end
        return j
    elseif id == 3
        if k == 0
            k = Mz
        elseif k == Mz
            k = 1
        end
        return k
    end
end
