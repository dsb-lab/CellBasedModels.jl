"""
    function addIntegratorMediumLeapfrog_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions related with Medium Update.
"""
function addIntegratorMediumLeapfrog_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    if "UpdateMedium" in keys(abm.declaredUpdates)

        #Check updated
        up = symbols_(abm,abm.declaredUpdates["UpdateMedium"])
        up = up[Bool.((up[:,"placeDeclaration"].==:Model) .* Bool.((up[:,"assigned"].==true) .+ (up[:,"updated"].==true))),:]

        #Construct functions

            #Make function to compute everything inside the volume

        f = abm.declaredUpdates["UpdateMedium"]
        for (i,j) in enumerate(abm.declaredSymbols["Medium"]) # Change symbol for update

            if abm.dims == 1
                add = :(mediumVOld[ic1_,$i])
            elseif abm.dims == 2
                add = :(mediumVOld[ic1_,ic2_,$i])
            elseif abm.dims == 3
                add = :(mediumVOld[ic1_,ic2_,ic3_,$i])
            end

            s = Meta.parse(string(MEDIUMSYMBOL,j))
            f = postwalk(x -> @capture(x,ss_=v_) && ss == s ? :($j = $add + $v*dt) : x, f)
        end
        f = postwalk(x->@capture(x,s_(v_)) ? :($(adaptOperatorsMediumLeapfrog_(v,s,abm,space,p))) : x, f) # Adapt
        f = postwalk(x->@capture(x,s_) ? adaptSymbolsMediumLeapfrog_(s,abm,space,p) : x, f) # Adapt
                        
        f = vectorize_(abm,f,p)

        f = simpleGridLoopWrapInFunction_(platform,:mediumInnerStep_!, f, abm.dims)

        #Remove count over boundaries
        f = postwalk(x->@capture(x,1:Nx_) && Nx == :Nx_ ? :(2:Nx_-1) : x, f)
        f = postwalk(x->@capture(x,1:Ny_) && Ny == :Ny_ ? :(2:Ny_-1) : x, f)
        f = postwalk(x->@capture(x,1:Nz_) && Nz == :Nz_ ? :(2:Nz_-1) : x, f)

            #Make function to compute the boundaries
        code = quote end

        lUpdate = length(abm.declaredSymbols["Medium"])
        for i in 1:abm.dims #Adapt boundary updates depending on the boudary type
            ic = Meta.parse(string("ic",i,"_"))
            nm = Meta.parse(string("N",["x","y","z"][i],"_"))
            subcode = quote end

            if abm.dims == 1
                v = :(mediumVCopy[ic1_,ic4_])
            elseif abm.dims == 2
                v = :(mediumVCopy[ic1_,ic2_,ic4_])
            elseif abm.dims == 3
                v = :(mediumVCopy[ic1_,ic2_,ic3_,ic4_])
            end

            if space.medium[i].minBoundaryType == "Periodic"

                #Lower boundary
                vUp = postwalk(x->@capture(x, t_) && t == ic ? 1 : x, v)
                vAss = postwalk(x->@capture(x, t_) && t == ic ? :($nm-1) : x, v)

                push!(subcode.args, :($vUp=$vAss))

                #Upper boundary
                vUp = postwalk(x->@capture(x, t_) && t == ic ? :($nm) : x, v)
                vAss = postwalk(x->@capture(x, t_) && t == ic ? 2 : x, v)

                push!(subcode.args, :($vUp=$vAss))
            end

            if space.medium[i].minBoundaryType == "Newmann"

                #Lower boundary
                vUp = postwalk(x->@capture(x, t_) && t == ic ? 1 : x, v)
                vAss = postwalk(x->@capture(x, t_) && t == ic ? :(2) : x, v)

                push!(subcode.args, :($vUp=$vAss))
            end            

            if space.medium[i].maxBoundaryType == "Newmann"

                #Lower boundary
                vUp = postwalk(x->@capture(x, t_) && t == ic ? nm : x, v)
                vAss = postwalk(x->@capture(x, t_) && t == ic ? :($nm-1) : x, v)

                push!(subcode.args, :($vUp=$vAss))
            end            

            if space.medium[i].minBoundaryType == "Dirichlet"

                #Lower boundary
                vUp = postwalk(x->@capture(x, t_) && t == ic ? 1 : x, v)

                push!(subcode.args, :($vUp=0.))
            end            

            if space.medium[i].maxBoundaryType == "Dirichlet"

                #Lower boundary
                vUp = postwalk(x->@capture(x, t_) && t == ic ? nm : x, v)

                push!(subcode.args, :($vUp=0.))
            end     

            subcode = :(for ic4_ in 1:$lUpdate
                            $subcode
                        end
                    )

            subcode = simpleGridLoop_(platform,subcode,abm.dims-1, indexes = [1,2,3][findall([1,2,3].!=i)])

            push!(code.args,subcode)
        end

        f2 = wrapInFunction_(:mediumBoundaryStep_!,code)

        fWrap = wrapInFunction_(:mediumStep_!, 
                                :(begin 
                                    @platformAdapt mediumInnerStep_!(ARGS_)
                                    @platformAdapt mediumBoundaryStep_!(ARGS_)
                                    mediumVOld .= mediumV
                                end)
                                )

        # println(prettify(code))

        push!(p.declareVar,:(mediumVOld = copy(mediumV)))

        push!(p.args.args,:mediumVOld)

        push!(p.declareF.args,f,f2,fWrap)

        push!(p.execInloop.args,
                :(mediumStep_!(ARGS_)) 
            )
    end

    return nothing
end

function adaptSymbolsMediumLeapfrog_(s,abm,space,p)

    if s == :xₘ

        return :(ic1_*dxₘ_+$(space.box[1].min))

    elseif s == :yₘ

        return :(ic2_*dyₘ_+$(space.box[2].min))

    elseif s == :zₘ

        return :(ic1_*dzₘ_+$(space.box[3].min))

    end

    return s

end

function adaptOperatorsMediumLeapfrog_(f,op,abm,space,p)

    f = vectorizeMedium_(abm,f,p)

    if op == :δx

        if space.medium[1].minBoundaryType == "Periodic"
            f = :(δMedium_(round(Int,($f-$(space.box[1].min))/dxₘ_)+1,ic1_))
        else
            f = :(δMedium_(round(Int,($f-$(space.box[1].min))/dxₘ_),ic1_))
        end

    elseif op == :δy

        if abm.dims < 2
            error("Operator δy cannot be used in Agent with dimension 1.")
        end

        if space.medium[2].minBoundaryType == "Periodic"
            f = :(δMedium_(round(Int,($f-$(space.box[2].min))/dyₘ_)+1,ic2_))
        else
            f = :(δMedium_(round(Int,($f-$(space.box[2].min))/dyₘ_),ic2_))
        end

    elseif op == :δz

        if abm.dims < 3
            error("Operator δz cannot be used in Agent with dimension 1 or 2.")
        end

        if space.medium[3].minBoundaryType == "Periodic"
            f = :(δMedium_(round(Int,($f-$(space.box[3].min))/dzₘ_)+1,ic3_))
        else
            f = :(δMedium_(round(Int,($f-$(space.box[3].min))/dzₘ_),ic3_))
        end

    elseif op == :Δ
        if abm.dims == 1
            add = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,$j]) : x,f)

            f = :(($add+$subs-2*$f)/dxₘ_^2)
        elseif abm.dims == 2
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,$j]) : x,f)
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,$j]) : x,f)

            f = :(($add+$subs-2*$f)/dxₘ_^2+($addy+$subsy-2*$f)/dyₘ_^2)
        elseif abm.dims == 3
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,ic3_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,ic3_,$j]) : x,f)
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,ic3_,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,ic3_,$j]) : x,f)
            addz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_+1,$j]) : x,f)
            subsz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_-1,$j]) : x,f)

            f = :(($add+$subs-2*$f)/dxₘ_^2+($addy+$subsy-2*$f)/dyₘ_^2+($addz+$subsz-2*$f)/dzₘ_^2)

        end
    elseif op == :Δx
        if abm.dims == 1
            add = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,$j]) : x,f)

            f = :(($add+$subs-2*$f)/dxₘ_^2)
        elseif abm.dims == 2
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,$j]) : x,f)

            f = :(($add+$subs-2*$f)/dxₘ_^2)
        elseif abm.dims == 3
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,ic3_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,ic3_,$j]) : x,f)

            f = :(($add+$subs-2*$f)/dxₘ_^2)
        end
    elseif op == :Δy
        if abm.dims == 1
            error("Operator Δy cannot exist in Agent with dimension 1.")
        elseif abm.dims == 2
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,$j]) : x,f)

            f = :(($addy+$subsy-2*$f)/dyₘ_^2)
        elseif abm.dims == 3
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,ic3_,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,ic3_,$j]) : x,f)

            f = :(($addy+$subsy-2*$f)/dyₘ_^2)
        end
    elseif op == :Δz
        if abm.dims == 1
            error("Operator Δz cannot exist in Agent with dimension 1.")
        elseif abm.dims == 2
            error("Operator Δy cannot exist in Agent with dimension 2.")
        elseif abm.dims == 3
            addz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_+1,$j]) : x,f)
            subsz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_-1,$j]) : x,f)

            f = :(($addz+$subsz-2*$f)/dzₘ_^2)
        end
    elseif op == :∇      
        if abm.dims == 1
            add = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,$j]) : x,f)

            f = :(($add-$subs)/(2*dxₘ_))
        elseif abm.dims == 2
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,$j]) : x,f)
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,$j]) : x,f)

            f = :(($add-$subs)/(2*dxₘ_)+($addy-$subsy)/(2*dyₘ_))
        elseif abm.dims == 3
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,ic3_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,ic3_,$j]) : x,f)
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,ic3_,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,ic3_,$j]) : x,f)
            addz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_+1,$j]) : x,f)
            subsz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_-1,$j]) : x,f)

            f = :(($add-$subs)/(2*dxₘ_)+($addy-$subsy)/(2*dyₘ_)+($addz-$subsz)/(2*dzₘ_))
        end
    elseif op == :∇x
        if abm.dims == 1
            add = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,$j]) : x,f)

            f = :(($add-$subs)/(2*dxₘ_))
        elseif abm.dims == 2
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,$j]) : x,f)

            f = :(($add-$subs)/(2*dxₘ_))
        elseif abm.dims == 3
            add = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_+1,ic2_,ic3_,$j]) : x,f)
            subs = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_-1,ic2_,ic3_,$j]) : x,f)

            f = :(($add-$subs)/(2*dxₘ_))
        end
    elseif op == :∇y
        if abm.dims == 1
            error("Operator Δy cannot exist in Agent with dimension 1.")
        elseif abm.dims == 2
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,$j]) : x,f)

            f = :(($addy-$subsy)/(2*dyₘ_))
        elseif abm.dims == 3
            addy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_+1,ic3_,$j]) : x,f)
            subsy = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_-1,ic3_,$j]) : x,f)

            f = :(($addy-$subsy)/(2*dyₘ_))
        end
    elseif op == :∇z
        if abm.dims == 1
            error("Operator Δz cannot exist in Agent with dimension 1.")
        elseif abm.dims == 2
            error("Operator Δy cannot exist in Agent with dimension 2.")
        elseif abm.dims == 3
            addz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_+1,$j]) : x,f)
            subsz = postwalk(x->@capture(x,s_[ic1_,ic2_,ic3_,j_]) && s == :mediumV ? :(mediumV[ic1_,ic2_,ic3_-1,$j]) : x,f)

            f = :(($addz-$subsz)/(2*dzₘ_))
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

δMedium_(i1,i2) = if i1==i2 1. else 0. end