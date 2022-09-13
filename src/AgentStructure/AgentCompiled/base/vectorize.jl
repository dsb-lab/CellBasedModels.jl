"""
    function errorInteraction(vAux)

Throw an error if a variable has not been added a subindex in an Interaction module.
"""
function errorInteraction(vAux)
    error("In an Interaction module the variable ",vAux," has been declared without specifying to which agent is assigned. Please specify putting .i or .j to the variable.")
end

function changedt(code,dt)
    return postwalk(x -> @capture(x,dt) ? dt : x, code)
end

function changetx(code,t,v,x)
    code = postwalk(z -> @capture(z,dt) ? 1 : z, code)
    code = postwalk(z -> @capture(z,t) ? t : z, code)
    return postwalk(z -> @capture(z,f_) && f == v ? x : z, code)
end


"""
    function vectorize_(abm::Agent,code::Expr,p::AgentCompiled;interaction=false)

Function to subtitute all the declared symbols of the agents in the expression into vector form.

# Args
 - **abm::Agent**: Agent structure containing the high level code of the agents.
 - **code::Expr**: Code to ve vectorised.
 - **p::AgentCompiled**: AgentCompiled structure containing all the created code when compiling.

# KwArgs
 - **interaction=false**: Check subindex specifying the to which agent belongs the parameter (e.g. in UpdateInteraction code).

# Returns
 - `Expr` with the code in vectorized form.
"""
function vectorize(code::Expr,p::AgentCompiled;interaction=false,integrator=Euler,integrationStep::Int=1,variablesUpdated=All)

    abm = p.agent

    #Vectorise equation
    for (i,v) in enumerate(abm.declaredSymbols["Local"])

        dt = integrator.steps[integrationStep][1]

        #Obtain position in matrix of initial time
        bs = integrator.steps[integrationStep][2]
        if bs == :localV
            pos = i
        elseif v in keys(abm.declaredSymbolsUpdated["Local"])
            pos = abm.declaredSymbolsUpdated["Variable"][v]
        else
            pos = i
        end

        #Obtain position in matrix of future time
        bsnew = integrator.steps[integrationStep][3]
        if bsnew != :localVCopy
            pos2 = i
        elseif v in keys(abm.declaredSymbolsUpdated["Local"])
            pos2 = abm.declaredSymbolsUpdated["Local"][v]
        else
            pos2 = i
        end

        #Modify argument of equation
        if integrationStep != 1 #If first step, ignore computations at future times
            code = postwalk(x -> @capture(x,g_(s_)=f_) && g == DIFFSYMBOL ? :($g($s) = $(changetx(f,:t,v,:(localV[i,ic1_])))) : x, code)
        else
            code = postwalk(x -> @capture(x,g_(s_)=f_) && g == DIFFSYMBOL ? :($g($s) = $(changetx(f,:(t+$dt),v,:(localV[i,ic1_]+$dt*$bs[$pos,ic1_])))) : x, code)        
        end

    end

    println(code)

    #Vectorise d() operator
    for (i,v) in enumerate(abm.declaredSymbols["Local"])

        dt = integrator.steps[integrationStep][1]

        #Obtain position in matrix of initial time
        bs = integrator.steps[integrationStep][2]
        if bs == :localV
            pos = i
        elseif v in keys(abm.declaredSymbolsUpdated["Local"])
            pos = abm.declaredSymbolsUpdated["Variable"][v]
        else
            pos = i
        end

        bsnew = integrator.steps[integrationStep][3]
        if bsnew != :localVCopy
            pos2 = i
        elseif v in keys(abm.declaredSymbolsUpdated["Local"])
            pos2 = abm.declaredSymbolsUpdated["Local"][v]
        else
            pos2 = i
        end

        if integrationStep != length(integrator.steps)
            code = postwalk(x -> @capture(x,g_(s_)=v_) && g == DIFFSYMBOL && s == v ? :($bsnew[ic1_,$pos2] = $v) : x, code)
        else #Add together all the contributions
            add = :(0.)
            for step in integrator.steps[1:end-1]
                bsnew2 = integrator.steps[integrationStep][3]
                if bsnew2 != :localVCopy
                    pos2 = i
                elseif v in keys(abm.declaredSymbolsUpdated["Local"])
                    pos2 = abm.declaredSymbolsUpdated["Local"][v]
                else
                    pos2 = i
                end

                add = :($add+$bsnew[ic1_,$pos2])
            end

            code = postwalk(x -> @capture(x,g_(s_)=v_) && g == DIFFSYMBOL && s == v ? :($bsnew[ic1_,$pos2] = $v + $add*dt) : x, code)
        end

    end

    #Vectorisation changes        
    for (i,v) in enumerate(abm.declaredSymbols["Local"])

        bs = :localV
        bsnew = :localVCopy
        if v in keys(abm.declaredSymbolsUpdated["Local"])
            pos = abm.declaredSymbolsUpdated["Local"][v]
        else
            pos = i
        end

        code = postwalk(x->@capture(x, vAux_.i.new) && vAux == v ? :($bsnew[ic1_,$pos]) : x, code)
        code = postwalk(x->@capture(x, vAux_.j.new) && vAux == v ? :($bsnew[nnic2_,$pos]) : x, code)
        code = postwalk(x->@capture(x, vAux_.i) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        code = postwalk(x->@capture(x, vAux_.j) && vAux == v ? :($bs[nnic2_,$i]) : x, code)
        if interaction
            code = postwalk(x->@capture(x, vAux_) && vAux == v ? errorInteraction(vAux) : x, code)
        else
            code = postwalk(x->@capture(x, vAux_.new) && vAux == v ? :($bsnew[ic1_,$pos]) : x, code)
            code = postwalk(x->@capture(x, vAux_) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        end

    end

    for (i,v) in enumerate(abm.declaredSymbols["LocalInteraction"])

        bs = :localInteractionV

        code = postwalk(x->@capture(x, vAux_.i.new) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        code = postwalk(x->@capture(x, vAux_.j.new) && vAux == v ? :($bs[nnic2_,$i]) : x, code)
        code = postwalk(x->@capture(x, vAux_.i) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        code = postwalk(x->@capture(x, vAux_.j) && vAux == v ? :($bs[nnic2_,$i]) : x, code)
        if interaction
            code = postwalk(x->@capture(x, vAux_) && vAux == v ? errorInteraction(vAux) : x, code)
        else
            code = postwalk(x->@capture(x, vAux_.new) && vAux == v ? :($bs[ic1_,$i]) : x, code)
            code = postwalk(x->@capture(x, vAux_) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        end

    end

    for (i,v) in enumerate(abm.declaredSymbols["Identity"])

        bs = :identityV
        bsnew = :identityVCopy
        if v in keys(abm.declaredSymbolsUpdated["Identity"])
            pos = abm.declaredSymbolsUpdated["Identity"][v]
        else
            pos = i
        end

        code = postwalk(x->@capture(x, vAux_.i.new) && vAux == v ? :($bsnew[ic1_,$pos]) : x, code)
        code = postwalk(x->@capture(x, vAux_.j.new) && vAux == v ? :($bsnew[nnic2_,$pos]) : x, code)
        code = postwalk(x->@capture(x, vAux_.i) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        code = postwalk(x->@capture(x, vAux_.j) && vAux == v ? :($bs[nnic2_,$i]) : x, code)
        if interaction
            code = postwalk(x->@capture(x, vAux_) && vAux == v ? errorInteraction(vAux) : x, code)
        else
            code = postwalk(x->@capture(x, vAux_.new) && vAux == v ? :($bsnew[ic1_,$pos]) : x, code)
            code = postwalk(x->@capture(x, vAux_) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        end

    end

    for (i,v) in enumerate(abm.declaredSymbols["IdentityInteraction"])

        bs = :identityInteractionV

        code = postwalk(x->@capture(x, vAux_.i.new) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        code = postwalk(x->@capture(x, vAux_.j.new) && vAux == v ? :($bs[nnic2_,$i]) : x, code)
        code = postwalk(x->@capture(x, vAux_.i) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        code = postwalk(x->@capture(x, vAux_.j) && vAux == v ? :($bs[nnic2_,$i]) : x, code)
        if interaction
            code = postwalk(x->@capture(x, vAux_) && vAux == v ? errorInteraction(vAux) : x, code)
        else
            code = postwalk(x->@capture(x, vAux_.new) && vAux == v ? :($bs[ic1_,$i]) : x, code)
            code = postwalk(x->@capture(x, vAux_) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        end

    end

    for (i,v) in enumerate(abm.declaredSymbols["Global"])

        bs = :globalV
        bsnew = :globalVCopy
        if v in keys(abm.declaredSymbolsUpdated["Global"])
            pos = abm.declaredSymbolsUpdated["Global"][v]
        else
            pos = i
        end

        code = postwalk(x->@capture(x, vAux_.new) && vAux == v ? :($bsnew[$pos]) : x, code)
        code = postwalk(x->@capture(x, vAux_) && vAux == v ? :($bs[$i]) : x, code)

    end

    for (i,v) in enumerate(abm.declaredSymbols["GlobalInteraction"])

        bs = :globalInteractionV

        code = postwalk(x->@capture(x, vAux_.new) && vAux == v ? :($bs[$i]) : x, code)
        code = postwalk(x->@capture(x, vAux_) && vAux == v ? :($bs[$i]) : x, code)

    end

    for (i,v) in enumerate(abm.declaredSymbols["Medium"])

        bs = :mediumV
        cp = :mediumVCopy

        if abm.dims == 1
            code = postwalk(x->@capture(x, cc_.new) && cc==v ? :($cp[idMediumX_,$i]) : x, code)
            code = postwalk(x->@capture(x, cc_) && cc==v ? :($bs[idMediumX_,$i]) : x, code)
        elseif abm.dims == 2
            code = postwalk(x->@capture(x, cc_.new) && cc==v ? :($cp[idMediumX_,idMediumY_,$i]) : x, code)
            code = postwalk(x->@capture(x, cc_) && cc==v ? :($bs[idMediumX_,idMediumY_,$i]) : x, code)
        elseif abm.dims == 3
            code = postwalk(x->@capture(x, cc_.new) && cc==v ? :($cp[idMediumX_,idMediumY_,idMediumZ_,$i]) : x, code)
            code = postwalk(x->@capture(x, cc_) && cc==v ? :($bs[idMediumX_,idMediumY_,idMediumZ_,$i]) : x, code)
        end
    end

    return code
end

"""
    function vectorizeMedium_(abm::Agent,code::Union{Expr,Symbol,<:Number},p::AgentCompiled)

Function to subtitute all the declared symbols of the medium in the expression into vector form.

# Args
 - **abm::Agent**: Agent structure containing the high level code of the agents.
 - **code::Union{Expr,Symbol,<:Number}**: Code to ve vectorised.
 - **p::AgentCompiled**: AgentCompiled structure containing all the created code when compiling.

 # Returns
 - `Expr` with the code in vectorized form.
"""
function vectorizeMedium_(abm::Agent,code::Union{Expr,Symbol,<:Number},p::AgentCompiled)

    for (i,v) in enumerate(abm.declaredSymbols["Global"])

        bs = :globalV
        bsnew = :globalVCopy
        if v in keys(abm.declaredSymbolsUpdated["Global"])
            pos = abm.declaredSymbolsUpdated["Global"][v]
        else
            pos = i
        end

        code = postwalk(x->@capture(x, $v.new) ? :($bsnew[$pos]) : x, code)
        code = postwalk(x->@capture(x, $v) ? :($bs[$i]) : x, code)

    end

    for (i,v) in enumerate(abm.declaredSymbols["GlobalArray"])

        name = Meta.parse(string(v,GLOBALARRAYCOPY))
        code = postwalk(x->@capture(x, cc_[c__].new) && cc==v ? :($name[$(c...)]) : x, code)
        code = postwalk(x->@capture(x, cc_.new) && cc==v ? :($name) : x, code)

    end

    for (i,v) in enumerate(abm.declaredSymbols["Medium"])

        bs = :mediumV
        bsnew = :mediumVCopy
        if v in keys(abm.declaredSymbolsUpdated["Medium"])
            pos = abm.declaredSymbolsUpdated["Medium"][v]
        else
            pos = i
        end

        code = postwalk(x->@capture(x, vAux_.new) && vAux == v ? :($bsnew[$(MEDIUMITERATIONSYMBOLS[1:p.agent.dims]...),$pos]) : x, code)
        code = postwalk(x->@capture(x, vAux_) && vAux == v ? :($bs[$(MEDIUMITERATIONSYMBOLS[1:p.agent.dims]...),$i]) : x, code)

    end

    return code

end
