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

        if abm.dims > 0
            subcode = quote end
            for i in 1:abm.dims
                add = quote end
                ic = Meta.parse(string("ic",i,"_"))
                nf = Meta.parse(string("N",["x","y","z"][i],"_"))

                ls = [
                        [(space.medium[i].minBoundaryType,),:(1),:(2),:($nf+1)],
                        [(space.medium[i].maxBoundaryType,),:($nf),:($nf-1),:(1-1)]
                ]
                for l in ls
                    if "Dirichlet" in l[1]
                        for v in keys(p.update["Medium"])
                            upMin = :($v=0.)
                            upMin = vectorize_(abm,upMin,p)
                            upMin = postwalk(x->@capture(x,s_) && s == ic ? l[2] : x, upMin)
                            push!(add.args,upMin)
                        end
                    elseif "Newmann" in l[1]
                        for v in keys(p.update["Medium"])
                            upMin = vectorize_(abm,quote $v end,p)
                            upMin1 = postwalk(x->@capture(x,s_) && s == ic ? l[2] : x, upMin).args[2]
                            upMin2 = postwalk(x->@capture(x,s_) && s == ic ? l[3] : x, upMin).args[2]
                            upMin = :($upMin1 = $upMin2)
                            upMin = postwalk(x->@capture(x,s_) && s == :mediumV ? :mediumVCopy : x, upMin)
                            push!(add.args,upMin)
                        end
                    elseif "Periodic" in l[1]
                        upMin = abm.declaredUpdates["UpdateMedium"]
                        for (i,j) in enumerate(abm.declaredSymbols["Medium"]) # Change symbol for update
                            s = Meta.parse(string(MEDIUMSYMBOL,j))
                            upMin = postwalk(x -> @capture(x,ss_=v__) && ss == s ? :($j = $j + $(v...)) : x, upMin)
                        end
                        upMin = postwalk(x->@capture(x,s_(v_)) ? :($(adaptMedium_(v,s,abm,p))) : x, upMin) # Adapt
                        upMin = vectorize_(abm,upMin,p)
                        upMin = postwalk(x->@capture(x,s_) && s == l[2] ? l[3] : x, upMin)
                        upMin = postwalk(x->@capture(x,s_) && s == l[4] ? l[2] : x, upMin) # change boundary
                        push!(add.args,upMin)
                    else
                        error("Boundary not implemented.")
                    end
                end

                add = simpleGridLoop_(platform,add,abm.dims-1)

                if i == 1 && abm.dims == 2
                    add = postwalk(x->@capture(x,1:Nx_) && Nx == :Nx_ ? :(1:Ny_) : x, add)
                    add = postwalk(x->@capture(x,ic1_) && ic1 == :ic1_ ? :ic2_ : x, add)
                elseif i == 1 && abm.dims == 3
                    add = postwalk(x->@capture(x,1:Nx_) && Nx == :Nx_ ? :(1:Nz_) : x, add)
                    add = postwalk(x->@capture(x,ic1_) && ic1 == :ic1_ ? :ic3_ : x, add)
                elseif i == 2 && abm.dims == 3
                    add = postwalk(x->@capture(x,1:Ny_) && Ny == :Ny_ ? :(1:Nz_) : x, add)
                    add = postwalk(x->@capture(x,ic1_) && ic1 == :ic2_ ? :ic3_ : x, add)
                end
                add = postwalk(x->@capture(x,1:N_) ? :(2:$N-1) : x, add)

                append!(subcode.args,add.args)
            end
    
            push!(code.args,subcode.args)
        end

        if abm.dims > 1
            subcode = quote end
            for i in 1:abm.dims
                for j in i+1:abm.dims
                    add = quote end

                    ic1 = Meta.parse(string("ic",i,"_"))
                    nf1 = Meta.parse(string("N",["x","y","z"][i],"_"))

                    ic2 = Meta.parse(string("ic",j,"_"))
                    nf2 = Meta.parse(string("N",["x","y","z"][j],"_"))

                    ls = [
                        [(space.medium[i].minBoundaryType,space.medium[j].minBoundaryType),:(1),:(2),:(1-1),:($nf1),:(1),:(2),:(1-1),($nf2+1)],
                        [(space.medium[i].minBoundaryType,space.medium[j].maxBoundaryType),:(1),:(2),:(1-1),:($nf1),:($nf2),:($nf2-1),($nf2+1),:(1-1)],
                        [(space.medium[i].maxBoundaryType,space.medium[j].minBoundaryType),:($nf1),:($nf1-1),:($nf1+1),:(1-1),:(1),:(2),:(1-1),($nf2+1)],
                        [(space.medium[i].maxBoundaryType,space.medium[j].maxBoundaryType),:($nf1),:($nf1-1),:($nf1+1),:(1-1),:($nf2),:($nf2-1),($nf2+1),:(1-1)],
                    ]
                    for l in ls
                        if "Dirichlet" in l[1]
                            for v in keys(p.update["Medium"])
                                upMin = :($v=0.)
                                upMin = vectorize_(abm,upMin,p)
                                upMin = postwalk(x->@capture(x,s_) && s == ic1 ? l[2] : x, upMin)
                                upMin = postwalk(x->@capture(x,s_) && s == ic2 ? l[6] : x, upMin)
                                push!(add.args,upMin)
                            end
                        elseif "Newmann" in l[1]
                            for v in keys(p.update["Medium"])
                                upMin = vectorize_(abm,quote $v end,p)
                                upMin1 = postwalk(x->@capture(x,s_) && s == ic1 ? l[2] : x, upMin).args[2]
                                upMin1 = postwalk(x->@capture(x,s_) && s == ic2 ? l[3] : x, upMin).args[2]
                                upMin2 = postwalk(x->@capture(x,s_) && s == ic1 ? l[6] : x, upMin).args[2]
                                upMin2 = postwalk(x->@capture(x,s_) && s == ic2 ? l[7] : x, upMin).args[2]
                                upMin = :($upMin1 = $upMin2)
                                upMin = postwalk(x->@capture(x,s_) && s == :mediumV ? :mediumVCopy : x, upMin)
                                push!(add.args,upMin)
                            end
                        elseif "Periodic" in l[1]
                            upMin = abm.declaredUpdates["UpdateMedium"]
                            for (i,j) in enumerate(abm.declaredSymbols["Medium"]) # Change symbol for update
                                s = Meta.parse(string(MEDIUMSYMBOL,j))
                                upMin = postwalk(x -> @capture(x,ss_=v__) && ss == s ? :($j = $j + $(v...)) : x, upMin)
                            end
                            println(l)
                            upMin = postwalk(x->@capture(x,s_(v_)) ? :($(adaptMedium_(v,s,abm,p))) : x, upMin) # Adapt
                            upMin = vectorize_(abm,upMin,p)
                            upMin = postwalk(x->@capture(x,s_) && s == ic1 ? l[2] : x, upMin)
                            upMin = postwalk(x->@capture(x,s_) && s == l[4] ? l[5] : x, upMin) # change boundary
                            upMin = postwalk(x->@capture(x,s_) && s == ic2 ? l[6] : x, upMin)
                            upMin = postwalk(x->@capture(x,s_) && s == l[8] ? l[9] : x, upMin) # change boundary
                            push!(add.args,upMin)
                        else
                            error("Boundary not implemented.")
                        end
                    end

                    add = simpleGridLoop_(platform,add,abm.dims-2)

                    if i == 1 && j == 2 && abm.dims == 3
                        add = postwalk(x->@capture(x,1:Nx_) && Nx == :Nx_ ? :(1:Nz_) : x, add)
                        add = postwalk(x->@capture(x,ic1_) && ic1 == :ic1_ ? :ic3_ : x, add)
                    elseif i == 1 && j == 3 && abm.dims == 3
                        add = postwalk(x->@capture(x,1:Nx_) && Nx == :Nx_ ? :(1:Ny_) : x, add)
                        add = postwalk(x->@capture(x,ic1_) && ic1 == :ic1_ ? :ic2_ : x, add)
                    end
                    add = postwalk(x->@capture(x,1:N_) ? :(2:$N-1) : x, add)

                    append!(subcode.args,add.args)
                end
            end    
            println(prettify(subcode))
            push!(code.args,subcode.args)            
        end

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