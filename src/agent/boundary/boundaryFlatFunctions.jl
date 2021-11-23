###################################################
#Auxitial functions flat boundaries
###################################################
export boundStopMin, boundStopMax, boundBounceMin, boundBounceMax, boundReflect

boundStopMin(x,min) = max(x,min)
boundStopMax(x,max) = min(x,max)

boundBounceMin(x,min) = min + (min-x)
boundBounceMax(x,max) = max - (x-max)

boundReflect(x) = -x

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

    max = (pos-1)*3+2
    min = (pos-1)*3+1
    up = quote localVCopy[ic1_,$posS] += boundsParameters[$max]-boundsParameters[$min] end
    for i in b.addSymbols["add"]
        posm = p.update["Local"][i]
        push!(up.args,:(localVCopy[ic1_,$posm] += boundsParameters[$max]-boundsParameters[$min]))
    end

    down = quote localVCopy[ic1_,$posS] -= boundsParameters[$max]-boundsParameters[$min] end
    for i in b.addSymbols["add"]
        posm = p.update["Local"][i]
        push!(down.args,:(localVCopy[ic1_,$posm] -= boundsParameters[$max]-boundsParameters[$min]))
    end


    code = quote
                if localVCopy[ic1_,$posm] < boundsParameters[$min]
                    $up
                elseif localVCopy[ic1_,$posm] >= boundsParameters[$max]
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
        push!(min.args,:(localVCopy[ic1_,$posm] = boundStopMin(localVCopy[ic1_,$posm],boundsParameters[$min])))
    end
    for i in b.addSymbols["stopMin"]
        posm = p.update["Local"][i]
        push!(min.args,:(localVCopy[ic1_,$posm] = boundStopMin(localVCopy[ic1_,$posm],boundsParameters[$min])))
    end
    for i in b.addSymbols["bounce"]
        posm = p.update["Local"][i]
        push!(min.args,:(localVCopy[ic1_,$posm] = boundBounceMin(localVCopy[ic1_,$posm],boundsParameters[$min])))
    end
    for i in b.addSymbols["bounceMin"]
        posm = p.update["Local"][i]
        push!(min.args,:(localVCopy[ic1_,$posm] = boundBounceMin(localVCopy[ic1_,$posm],boundsParameters[$min])))
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
        push!(max.args,:(localVCopy[ic1_,$posm] = boundStopMax(localVCopy[ic1_,$posm],boundsParameters[$max])))
    end
    for i in b.addSymbols["stopMax"]
        posm = p.update["Local"][i]
        push!(max.args,:(localVCopy[ic1_,$posm] = boundStopMax(localVCopy[ic1_,$posm],boundsParameters[$max])))
    end
    for i in b.addSymbols["bounce"]
        posm = p.update["Local"][i]
        push!(max.args,:(localVCopy[ic1_,$posm] = boundBounceMax(localVCopy[ic1_,$posm],boundsParameters[$max])))
    end
    for i in b.addSymbols["bounceMax"]
        posm = p.update["Local"][i]
        push!(max.args,:(localVCopy[ic1_,$posm] = boundBounceMax(localVCopy[ic1_,$posm],boundsParameters[$max])))
    end
    for i in b.addSymbols["reflect"]
        posm = p.update["Local"][i]
        push!(max.args,:(localVCopy[ic1_,$posm] = boundReflect(localVCopy[ic1_,$posm])))
    end
    for i in b.addSymbols["reflectMax"]
        posm = p.update["Local"][i]
        push!(max.args,:(localVCopy[ic1_,$posm] = boundReflect(localVCopy[ic1_,$posm])))
    end

    posm = p.update["Local"][b.s]

    if !emptyquote_(min) && !emptyquote_(max)

        code = quote 
            if localVCopy[ic1_,$posm] < boundsParameters[$min] 
                $min
            elseif localVCopy[ic1_,$posm] >= boundsParameters[$max] 
                $max
            end
       end        
       
       return code
    elseif !emptyquote_(min)
        code = quote 
            if localVCopy[ic1_,$posm] < boundsParameters[$min] 
                $min
            end
       end        
       
        return code
    elseif !emptyquote_(max)
        code = quote 
            if localVCopy[ic1_,$posm] >= boundsParameters[$max] 
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
        s = [:x,:y,:z][i]
        append!(code.args,returnBound_(s,i,bound,p).args)
    end

    return code
end