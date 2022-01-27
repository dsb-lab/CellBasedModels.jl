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
# function boundariesFunctionDefinition(b::Vector{Symbol},p::Program_, platform::String)

#     #Make function to compute the boundaries
#     code = quote end

#     lUpdate = length(p.agent.declaredSymbols["Medium"])
#     for i in 0:p.agent.dims-1 #Adapt boundary updates depending on the boundary type
#         ic = Meta.parse(string("ic",i+1,"_"))
#         nm = Meta.parse(string("N",["x","y","z"][i+1],"_"))
#         subcode = quote end

#         if p.agent.dims == 1
#             v = :(mediumVCopy[ic1_,$up])
#             v2 = :(mediumV[ic1_,$up])
#         elseif p.agent.dims == 2
#             v = :(mediumVCopy[ic1_,ic2_,$up])
#             v2 = :(mediumV[ic1_,ic2_,$up])
#         elseif p.agent.dims == 3
#             v = :(mediumVCopy[ic1_,ic2_,ic3_,$up])
#             v2 = :(mediumV[ic1_,ic2_,ic3_,$up])
#         end

#         if b[2*i+1] == :Periodic

#             #Lower boundary
#             vUp = postwalk(x->@capture(x, t_) && t == ic ? 1 : x, v)
#             vAss = postwalk(x->@capture(x, t_) && t == ic ? :($nm-1) : x, v)

#             push!(subcode.args, :($vUp=$vAss))

#             #Upper boundary
#             vUp = postwalk(x->@capture(x, t_) && t == ic ? :($nm) : x, v)
#             vAss = postwalk(x->@capture(x, t_) && t == ic ? 2 : x, v)

#             push!(subcode.args, :($vUp=$vAss))

#         end

#         if b[2*i+1] == :Newmann

#             #Lower boundary
#             vUp = postwalk(x->@capture(x, t_) && t == ic ? 1 : x, v)
#             vUp2 = postwalk(x->@capture(x, t_) && t == ic ? 2 : x, v2) #Original medium variable

#             xmax = [2,2,2]
#             xmin = [2,2,2]
#             xmin[i+1] = 1
#             xmax = xmax[1:p.agent.dims]
#             xmin = xmin[1:p.agent.dims]
#         end            

#         if b[2*i+2] == :Newmann

#             #Upper boundary
#             vUp = postwalk(x->@capture(x, t_) && t == ic ? nm : x, v)
#             vUp2 = postwalk(x->@capture(x, t_) && t == ic ? :($nm-1) : x, v2) #Original medium variable

#             xmax = Array{Union{Expr,Symbol}}([:Nx_,:Ny_,:Nz_])
#             xmin = Array{Union{Expr,Symbol}}([:Nx_,:Ny_,:Nz_])
#             xmin[i+1] = :($(xmin[i+1])-1)
#             xmax = xmax[1:p.agent.dims]
#             xmin = xmin[1:p.agent.dims]
#             println(:($vUp=(mediumV[$(xmax...),$up]-mediumV[$(xmin...),$up])/dt*$vUp2+$vUp2))
#             push!(subcode.args, :($vUp=(mediumV[$(xmax...),$up]-mediumV[$(xmin...),$up])/dt*$vUp2+$vUp2))

#         end   

#         if b[2*i+1] == :Dirichlet

#             #Lower boundary
#             vUp = postwalk(x->@capture(x, t_) && t == ic ? 1 : x, v)

#             # x = xMin[i+1,1:p.agent.dims]
#             # push!(subcode.args, :($vUp=$(b.boundaries[i].medium.fMin)($(x...),t)))

#         end            

#         if b[2*i+2] == :Dirichlet

#             #Upper boundary
#             vUp = postwalk(x->@capture(x, t_) && t == ic ? nm : x, v)
            
#             # x = xMax[i+1,1:p.agent.dims]
#             # update = :($vUp=$(b.boundaries[i].medium.fMax)($(x...),t))

#             # push!(subcode.args, update)

#         end

#         subcode = :(for $up in 1:$lUpdate
#                         $subcode
#                     end
#                 )

#         subcode = simpleGridLoop_(platform,subcode,p.agent.dims-1, indexes = [1,2,3][findall([1,2,3].!=i)])

#         push!(code.args,subcode) 

#     end

#     f = wrapInFunction_(:mediumBoundaryStep_!,code)

#     push!(p.declareF.args,f)
# end

function changeARGS(code,f)
    code = postwalk(x -> @capture(ARRGS_, x) ? f : x, code)

    return code
end

function boundariesFunctionDefinition(p::Program_, platform::String)

    if "UpdateMediumBoundary" in keys(p.agent.declaredUpdates)

        code = p.agent.declaredUpdates["UpdateMediumBoundary"]

        #For all axis
        codMin = quote end
        codMax = quote end
        codPer = quote end
        for i in ["x","y","z"][1:p.agent.dims]
            d1 = MetaTools.parse(string("∂Min$i"))
            d2 = MetaTools.parse(string("∂Max$i"))
            d3 = MetaTools.parse(string("periodic$i"))
            push!(codxMin.args,:($d1($s) = ARGS_))
            push!(codxMax.args,:($d2($s) = ARGS_))
            push!(codxPer.args,:($d3($s)))
        end
        code = postwalk(x -> @capture(∂Min() = f_, x) ? changeARGS(codMin,f) : x, code)
        code = postwalk(x -> @capture(∂Max() = f_, x) ? changeARGS(codMax,f) : x, code)
        code = postwalk(x -> @capture(periodic(), x) ? codxPer : x, code)

        #For axis symbols
        codxMin = quote end
        codyMin = quote end
        codzMin = quote end
        codxMax = quote end
        codyMax = quote end
        codzMax = quote end
        codxPer = quote end
        codyPer = quote end
        codzPer = quote end
        for s in p.agent.declaredSymbols["Medium"]
            push!(codxMin.args,:(∂xMin($s) = ARGS_))
            push!(codyMin.args,:(∂yMin($s) = ARGS_))
            push!(codzMin.args,:(∂zMin($s) = ARGS_))
            push!(codxMax.args,:(∂xMax($s) = ARGS_))
            push!(codyMax.args,:(∂yMax($s) = ARGS_))
            push!(codxMax.args,:(∂zMax($s) = ARGS_))
            push!(codxPer.args,:(periodicx($s)))
            push!(codyPer.args,:(periodicy($s)))
            push!(codzPer.args,:(periodicz($s)))
        end
        code = postwalk(x -> @capture(∂xMin() = f_, x) ? changeARGS(codxMin,f) : x, code)
        code = postwalk(x -> @capture(∂yMin() = f_, x) ? changeARGS(codyMin,f) : x, code)
        code = postwalk(x -> @capture(∂zMin() = f_, x) ? changeARGS(codzMin,f) : x, code)
        code = postwalk(x -> @capture(∂xMax() = f_, x) ? changeARGS(codxMax,f) : x, code)
        code = postwalk(x -> @capture(∂yMax() = f_, x) ? changeARGS(codyMax,f) : x, code)
        code = postwalk(x -> @capture(∂zMax() = f_, x) ? changeARGS(codzMax,f) : x, code)
        code = postwalk(x -> @capture(periodicx(), x) ? codxPer : x, code)
        code = postwalk(x -> @capture(periodicy(), x) ? codyPer : x, code)
        code = postwalk(x -> @capture(periodicz(), x) ? codzPer : x, code)

        #For each symbol
        for (i,s) in enumerate(p.agent.declaredSymbols["Medium"])

            up = p.update["Medium"][s]

            #Neumann
            ind1 = copy(ind); ind2 = copy(ind)
            ind1[1] = :(2); ind2[1] = :(1) 
            code = postwalk(x -> @capture(∂xMin(ss_) = f_, x) && ss == s ? :(mediumVCopy[$(ind2...),$up] = mediumV[$(ind1...),$i] - ($f)*dx_) : x, code)

            ind1 = copy(ind); ind2 = copy(ind)
            ind1[1] = :(Nx_-1); ind2[1] = :(Nx_) 
            code = postwalk(x -> @capture(∂xMax(ss_) = f_, x) && ss == s ? :(mediumVCopy[$(ind2...),$up] = mediumV[$(ind1...),$i] - ($f)*dx_) : x, code)

            ind1 = copy(ind); ind2 = copy(ind)
            ind1[2] = :(2); ind2[2] = :(1) 
            code = postwalk(x -> @capture(∂yMin(ss_) = f_, x) && ss == s ? :(mediumVCopy[$(ind2...),$up] = mediumV[$(ind1...),$i] - ($f)*dy_) : x, code)

            ind1 = copy(ind); ind2 = copy(ind)
            ind1[2] = :(Ny_-1); ind2[2] = :(Ny_) 
            code = postwalk(x -> @capture(∂yMax(ss_) = f_, x) && ss == s ? :(mediumVCopy[$(ind2...),$up] = mediumV[$(ind1...),$i] - ($f)*dy_) : x, code)

            ind1 = copy(ind); ind2 = copy(ind)
            ind1[3] = :(2); ind2[3] = :(1) 
            code = postwalk(x -> @capture(∂zMin(ss_) = f_, x) && ss == s ? :(mediumVCopy[$(ind2...),$up] = mediumV[$(ind1...),$i] - ($f)*dz_) : x, code)

            ind1 = copy(ind); ind2 = copy(ind)
            ind1[3] = :(Nz_-1); ind2[3] = :(Nz_) 
            code = postwalk(x -> @capture(∂zMax(ss_) = f_, x) && ss == s ? :(mediumVCopy[$(ind2...),$up] = mediumV[$(ind1...),$i] - ($f)*dz_) : x, code)

            #Periodic
            ind1 = copy(ind); ind2 = copy(ind); ind3 = copy(ind); ind4 = copy(ind)
            ind1[1] = :(2); ind2[1] = :(1); ind3[1] = :(Nx_-1); ind4[1] = :(Nx_) 
            code = postwalk(x -> @capture(periodicx(ss_), x) && ss == s ? 
            :(begin 
            mediumVCopy[$(ind4...),$up] = mediumV[$(ind1...),$i]
            mediumVCopy[$(ind3...),$up] = mediumV[$(ind2...),$i]        
            end)
            : x, code)

            ind1 = copy(ind); ind2 = copy(ind); ind3 = copy(ind); ind4 = copy(ind)
            ind1[2] = :(2); ind2[2] = :(1); ind3[2] = :(Ny_-1); ind4[2] = :(Ny_) 
            code = postwalk(x -> @capture(periodicx(ss_), x) && ss == s ? 
            :(begin 
            mediumVCopy[$(ind4...),$up] = mediumV[$(ind1...),$i]
            mediumVCopy[$(ind3...),$up] = mediumV[$(ind2...),$i]        
            end)
            : x, code)

            ind1 = copy(ind); ind2 = copy(ind); ind3 = copy(ind); ind4 = copy(ind)
            ind1[3] = :(2); ind2[3] = :(1); ind3[3] = :(Nz_-1); ind4[3] = :(Nz_) 
            code = postwalk(x -> @capture(periodicx(ss_), x) && ss == s ? 
            :(begin 
            mediumVCopy[$(ind4...),$up] = mediumV[$(ind1...),$i]
            mediumVCopy[$(ind3...),$up] = mediumV[$(ind2...),$i]        
            end)
            : x, code)

            #Dirichlet
            ind2 = copy(ind)
            ind2[1] = :(1) 
            code = postwalk(x -> @capture(ss_.min = f_, x) && ss == s ? :(mediumVCopy[$(ind2...),$up] = $f) : x, code)

            ind2 = copy(ind)
            ind2[1] = :(Nx_) 
            code = postwalk(x -> @capture(ss_.max = f_, x) && ss == s ? :(mediumVCopy[$(ind2...),$up] = $f) : x, code)

            ind2 = copy(ind)
            ind2[2] = :(1) 
            code = postwalk(x -> @capture(ss_.min = f_, x) && ss == s ? :(mediumVCopy[$(ind2...),$up] = $f) : x, code)

            ind2 = copy(ind)
            ind2[2] = :(Ny_) 
            code = postwalk(x -> @capture(ss_.max = f_, x) && ss == s ? :(mediumVCopy[$(ind2...),$up] = $f) : x, code)

            ind2 = copy(ind)
            ind2[3] = :(1) 
            code = postwalk(x -> @capture(ss_.min = f_, x) && ss == s ? :(mediumVCopy[$(ind2...),$up] = $f) : x, code)

            ind2 = copy(ind)
            ind2[3] = :(Nz_) 
            code = postwalk(x -> @capture(ss_.max = f_, x) && ss == s ? :(mediumVCopy[$(ind2...),$up] = $f) : x, code)
        end
    else
        code = quote end
    end

    return code
end
    