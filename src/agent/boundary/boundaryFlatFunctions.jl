###################################################
#Auxitial functions flat boundaries
###################################################
export boundStopMin, boundStopMax, boundBounceMin, boundBounceMax, boundReflect

boundStopMin(x,min) = max(x,min)
boundStopMax(x,max) = min(x,max)

boundBounceMin(x,min) = min + (min-x)
boundBounceMax(x,max) = max - (x-max)

boundReflect(x) = -x

function checkInitiallyInBoundBoundaryFlat(simulationBox,localV,boundaries)
    for (i,b) in enumerate(boundaries)
        if b in [Periodic,Bounded]
            if any(localV[:,i] .<= simulationBox[i,1]) || any(localV[:,1] .> simulationBox[i,2])
                error("Particles have to be initialised inside the simulation boundary min<X=<max for flat boundaries that are not of type Free.",
                    " Some particles of axis ", i ," with declared boundary ", b ," have been initialised outside it."
                )
            end
        end
    end
end

###################################################
#Return code boundaries
###################################################

#Free
function returnBound_(s::Symbol,pos::Int,b::Free,p::Program_)

    return quote end
end

#Periodic
function returnBound_(s::Symbol,pos::Int,b::Periodic,p::Program_)

    posS = p.update["Local"][s]

    up = quote localVCopy[ic1_,$posS] += simulationBox[$pos,2]-simulationBox[$pos,1] end
    for i in b.addSymbols["add"]
        posm = p.update["Local"][i]
        push!(up.args,:(localVCopy[ic1_,$posm] += simulationBox[$pos,2]-simulationBox[$pos,1]))
    end

    down = quote localVCopy[ic1_,$posS] -= simulationBox[$pos,2]-simulationBox[$pos,1] end
    for i in b.addSymbols["add"]
        posm = p.update["Local"][i]
        push!(down.args,:(localVCopy[ic1_,$posm] -= simulationBox[$pos,2]-simulationBox[$pos,1]))
    end

    code = quote
                if localVCopy[ic1_,$pos] < simulationBox[$pos,1]
                    $up
                elseif localVCopy[ic1_,$pos] >= simulationBox[$pos,2]
                    $down
                end
           end

    return code
end

#Bounded
function returnBound_(s::Symbol,pos::Int,b::Bounded,p::Program_)

    #Add main symbol if not present
    symbolPresent = false
    for i in keys(b.addSymbols)
        if s in b.addSymbols[i]
            symbolPresent = true
            break
        end
    end
    if !symbolPresent
        push!(b.addSymbols["stop"],s)
    end

    min = quote end
    for i in b.addSymbols["stop"]
        posm = p.update["Local"][i] 
        push!(min.args,:(localVCopy[ic1_,$posm] = boundStopMin(localVCopy[ic1_,$posm],simulationBox[$pos,1])))
    end
    for i in b.addSymbols["stopMin"]
        posm = p.update["Local"][i]
        push!(min.args,:(localVCopy[ic1_,$posm] = boundStopMin(localVCopy[ic1_,$posm],simulationBox[$pos,1])))
    end
    for i in b.addSymbols["bounce"]
        posm = p.update["Local"][i]
        push!(min.args,:(localVCopy[ic1_,$posm] = boundBounceMin(localVCopy[ic1_,$posm],simulationBox[$pos,1])))
    end
    for i in b.addSymbols["bounceMin"]
        posm = p.update["Local"][i]
        push!(min.args,:(localVCopy[ic1_,$posm] = boundBounceMin(localVCopy[ic1_,$posm],simulationBox[$pos,1])))
    end
    for i in b.addSymbols["reflect"]
        posm = p.update["Local"][i]
        push!(min.args,:(localVCopy[ic1_,$posm] = boundReflect(localVCopy[ic1_,$posm])))
    end
    for i in b.addSymbols["reflectMin"]
        posm = p.update["Local"][i]
        push!(min.args,:(localVCopy[ic1_,$posm] = boundReflect(localVCopy[ic1_,$posm])))
    end

    max = quote end
    for i in b.addSymbols["stop"]
        posm = p.update["Local"][i]
        push!(max.args,:(localVCopy[ic1_,$posm] = boundStopMax(localVCopy[ic1_,$posm],simulationBox[$pos,2])))
    end
    for i in b.addSymbols["stopMax"]
        posm = p.update["Local"][i]
        push!(max.args,:(localVCopy[ic1_,$posm] = boundStopMax(localVCopy[ic1_,$posm],simulationBox[$pos,2])))
    end
    for i in b.addSymbols["bounce"]
        posm = p.update["Local"][i]
        push!(max.args,:(localVCopy[ic1_,$posm] = boundBounceMax(localVCopy[ic1_,$posm],simulationBox[$pos,2])))
    end
    for i in b.addSymbols["bounceMax"]
        posm = p.update["Local"][i]
        push!(max.args,:(localVCopy[ic1_,$posm] = boundBounceMax(localVCopy[ic1_,$posm],simulationBox[$pos,2])))
    end
    for i in b.addSymbols["reflect"]
        posm = p.update["Local"][i]
        push!(max.args,:(localVCopy[ic1_,$posm] = boundReflect(localVCopy[ic1_,$posm])))
    end
    for i in b.addSymbols["reflectMax"]
        posm = p.update["Local"][i]
        push!(max.args,:(localVCopy[ic1_,$posm] = boundReflect(localVCopy[ic1_,$posm])))
    end

    posm = p.update["Local"][s]

    if !emptyquote_(min) && !emptyquote_(max)

        code = quote 
            if localVCopy[ic1_,$posm] < simulationBox[$pos,1] 
                $min
            elseif localVCopy[ic1_,$posm] >= simulationBox[$pos,2] 
                $max
            end
       end        
       
       return code
    elseif !emptyquote_(min)
        code = quote 
            if localVCopy[ic1_,$posm] < simulationBox[$pos,1] 
                $min
            end
       end        
       
        return code
    elseif !emptyquote_(max)
        code = quote 
            if localVCopy[ic1_,$posm] >= simulationBox[$pos,2] 
                $max
            end
       end        
       
        return code
    else

        return quote end
    end

end

function returnBound_(b::BoundaryFlat,p::Program_)

    code = quote end

    for (i,bound) in enumerate(b.boundaries)
        s = POSITIONSYMBOLS[i]
        append!(code.args,returnBound_(s,i,bound,p).args)
    end

    return code
end

#######################################################################################
#Return computation over boundaries
#######################################################################################
function boundariesFunctionDefinition(b::BoundaryFlat,p::Program_, platform::String)

    #Make function to compute the boundaries
    code = quote end

    lUpdate = length(p.agent.declaredSymbols["Medium"])
    for i in 1:p.agent.dims #Adapt boundary updates depending on the boundary type
        ic = Meta.parse(string("ic",i,"_"))
        nm = Meta.parse(string("N",["x","y","z"][i],"_"))
        subcode = quote end

        if p.agent.dims == 1
            v = :(mediumVCopy[ic1_,ic4_])
            v2 = :(mediumV[ic1_,ic4_])
        elseif p.agent.dims == 2
            v = :(mediumVCopy[ic1_,ic2_,ic4_])
            v2 = :(mediumV[ic1_,ic2_,ic4_])
        elseif p.agent.dims == 3
            v = :(mediumVCopy[ic1_,ic2_,ic3_,ic4_])
            v2 = :(mediumV[ic1_,ic2_,ic3_,ic4_])
        end

        if b.boundaries[i].medium == PeriodicBoundaryCondition

            #Lower boundary
            vUp = postwalk(x->@capture(x, t_) && t == ic ? 1 : x, v)
            vAss = postwalk(x->@capture(x, t_) && t == ic ? :($nm-1) : x, v)

            push!(subcode.args, :($vUp=$vAss))

            #Upper boundary
            vUp = postwalk(x->@capture(x, t_) && t == ic ? :($nm) : x, v)
            vAss = postwalk(x->@capture(x, t_) && t == ic ? 2 : x, v)

            push!(subcode.args, :($vUp=$vAss))

        end

        xMin = [:(simulationBox[1,1]) :(ic2_*(simulationBox[2,2]-simulationBox[2,1])/Ny_+simulationBox[2,1]) :(ic3_*(simulationBox[3,2]-simulationBox[3,1])/Nz_+simulationBox[3,1]);
        :(ic1_*(simulationBox[1,2]-simulationBox[1,1])/Nx_+simulationBox[1,1]) :(simulationBox[2,1]) :(ic3_*(simulationBox[3,2]-simulationBox[3,1])/Nz_+simulationBox[3,1]);
        :(ic1_*(simulationBox[1,2]-simulationBox[1,1])/Nx_+simulationBox[1,1]) :(ic2_*(simulationBox[2,2]-simulationBox[2,1])/Ny_+simulationBox[2,1]) :(simulationBox[3,1])]

        xMax = [:(simulationBox[1,2]) :(ic2_*(simulationBox[2,2]-simulationBox[2,1])/Ny_+simulationBox[2,1]) :(ic3_*(simulationBox[3,2]-simulationBox[3,1])/Nz_+simulationBox[3,1]);
        :(ic1_*(simulationBox[1,2]-simulationBox[1,1])/Nx_+simulationBox[1,1]) :(simulationBox[2,2]) :(ic3_*(simulationBox[3,2]-simulationBox[3,1])/Nz_+simulationBox[3,1]);
        :(ic1_*(simulationBox[1,2]-simulationBox[1,1])/Nx_+simulationBox[1,1]) :(ic2_*(simulationBox[2,2]-simulationBox[2,1])/Ny_+simulationBox[2,1]) :(simulationBox[3,2])]

        if typeof(b.boundaries[i].medium) in [NewmannBoundaryCondition,NewmannBoundaryCondition_DirichletBoundaryCondition]

            #Lower boundary
            vUp = postwalk(x->@capture(x, t_) && t == ic ? 1 : x, v)
            vUp2 = postwalk(x->@capture(x, t_) && t == ic ? 2 : x, v2) #Original medium variable

            x = xMin[i,1:p.agent.dims]
            push!(subcode.args, :($vUp=$(b.boundaries[i].medium.fMin)($(x...),t)*$vUp2+$vUp2))

        end            

        if typeof(b.boundaries[i].medium) in [NewmannBoundaryCondition,DirichletBoundaryCondition_NewmannBoundaryCondition]

            #Upper boundary
            vUp = postwalk(x->@capture(x, t_) && t == ic ? nm : x, v)
            vUp2 = postwalk(x->@capture(x, t_) && t == ic ? :($nm-1) : x, v2) #Original medium variable

            x = xMin[i,1:p.agent.dims]
            push!(subcode.args, :($vUp=$(b.boundaries[i].medium.fMax)($(x...),t)*$vUp2+$vUp2))

        end   

        if typeof(b.boundaries[i].medium) in [DirichletBoundaryCondition,DirichletBoundaryCondition_NewmannBoundaryCondition]

            #Lower boundary
            vUp = postwalk(x->@capture(x, t_) && t == ic ? 1 : x, v)

            x = xMin[i,1:p.agent.dims]
            push!(subcode.args, :($vUp=$(b.boundaries[i].medium.fMin)($(x...),t)))

        end            

        if typeof(b.boundaries[i].medium) in [DirichletBoundaryCondition,NewmannBoundaryCondition_DirichletBoundaryCondition]

            #Upper boundary
            vUp = postwalk(x->@capture(x, t_) && t == ic ? nm : x, v)
            
            x = xMax[i,1:p.agent.dims]
            update = :($vUp=$(b.boundaries[i].medium.fMax)($(x...),t))

            push!(subcode.args, update)

        end

        if !(typeof(b.boundaries[i]) in [Bounded,Periodic])
            error("Boundary has to be a bounded boundary but some was set to a non-valid type: ", [typeof(i) for i in b.boundaries])
        end

        subcode = :(for ic4_ in 1:$lUpdate
                        $subcode
                    end
                )

        subcode = simpleGridLoop_(platform,subcode,p.agent.dims-1, indexes = [1,2,3][findall([1,2,3].!=i)])

        push!(code.args,subcode) 

    end

    f = wrapInFunction_(:mediumBoundaryStep_!,code)

    push!(p.declareF.args,f)
end
    