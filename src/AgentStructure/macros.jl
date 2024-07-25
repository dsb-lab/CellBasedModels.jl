"""
    function checkCustomCode(abm)

Function that checks if the macro and other decorators are used in the appropiate rules.
"""
function checkCustomCode(abm)

    #Error if dt in other place
    for up in keys(abm.declaredUpdates)

        #dt()
        if !(up in [:agentODE,:agentSDE,:modelODE,:modelSDE,:mediumODE,:mediumSDE])
            v, _ = captureVariables(abm.declaredUpdates[up])
            if !isempty(v)
                error("Cannot declared a differential equation with the dt() function in $up. The following variables have been declared erroneously:  $(v...) . ")
            end
        end

        #@addAgent
        if !(up in [:agentRule])
            if occursin("@addAgent",string(abm.declaredUpdates[up]))
                error("@addAgent can only be declared in agentRule")
            end
        end

        #@removeAgent
        if !(up in [:agentRule])
            if occursin("@removeAgent",string(abm.declaredUpdates[up]))
                error("@removeAgent can only be declared in agentRule")
            end
        end

        #@loopOverNeighbors
        if !(up in [:agentRule,:agentODE,:agentSDE])
            if occursin("@loopOverNeighbors",string(abm.declaredUpdates[up]))
                error("@loopOverNeighbors can only be declared in agent code")
            end
        end

        #@∂
        if !(up in [:mediumODE,:mediumSDE])
            if occursin("@∂",string(abm.declaredUpdates[up]))
                error("@∂ can only be declared in mediumODE and mediumSDE")
            end
        end

        #@∂2
        if !(up in [:mediumODE,:mediumSDE])
            if occursin("@∂2",string(abm.declaredUpdates[up]))
                error("@∂2 can only be declared in mediumODE and mediumSDE")
            end
        end

        #@mediumInborder
        if !(up in [:mediumRule,:mediumODE,:mediumSDE])
            if occursin("@mediumInborder",string(abm.declaredUpdates[up]))
                error("@mediumInborder can only be declared in medium code")
            end
        end

        #@mediumBorder
        if !(up in [:mediumRule,:mediumODE,:mediumSDE])
            if occursin("@mediumBorder",string(abm.declaredUpdates[up]))
                error("@mediumBorder can only be declared in medium code")
            end
        end

    end

end

########################################################
# Macros
########################################################
"""
    macro loopOverNeighbors(code)
    macro loopOverNeighbors(it1, code)

Macro that creates the loop function to go over all neighbors of the agent. 
    
It can be declared as

```julia
@loopOverNeighbors for iterator in ___
    #code
end
```
or

```julia
@loopOverNeighbors iterator begin
    #code
end
```
for some iterator symbol. It can only be used in agent rules or DEs.
"""
macro loopOverNeighbors(it1, code)

    abm = AGENT

    code = neighborsLoop(code,it1,abm.neighbors,abm.dims)

    code = postwalk(x->@capture(x,i_) && i == :i2_ ? it1 : x, code )

    return esc(code)

end

macro loopOverNeighbors(code)

    if !(isa(code, Expr) && code.head === :for)
        throw(ArgumentError("@threads requires a `for` loop expression"))
    end

    it2 = code.args[1].args[1]
    code = code.args[2]

    abm = AGENT

    code = neighborsLoop(code,it2,abm.neighbors,abm.dims)

    code = postwalk(x->@capture(x,i_) && i == :i2_ ? it2 : x, code )

    return esc(code)

end

"""
    macro ∂(coord,code)

Discretizes the `code` term of a drift process. e.g. Agent in 2D

∂(1,m) → (m[i1_-1,i2_]-m[i1_-1,i2_])/(2*dx)

the coordinate must be 1, 2 or 3, specifing the axis of differentiation.
"""
macro ∂(coord,code)

    abm = AGENT

    if !(coord in [1,2,3][1:abm.dims])
        error("Coordinate in @mediumBorder with model of dimensionality $(abm.dims) must be $([1,2,3][1:abm.dims]).")
    end


    medium = [i for (i,prop) in abm.parameters if prop.scope == :medium]

    if coord == 1 && abm.dims == 1

        code1p = postwalk(x->@capture(x,m_[g_]) && m in medium ? :($m[$g+1]) : x, code)
        code1m = postwalk(x->@capture(x,m_[g_]) && m in medium ? :($m[$g-1]) : x, code)

        return esc(:(($code1p -$code1m)/(2*dx)))

    elseif coord == 1 && abm.dims == 2

        code1p = postwalk(x->@capture(x,m_[g_,g2_]) && m in medium ? :($m[$g+1,$g2]) : x, code)
        code1m = postwalk(x->@capture(x,m_[g_,g2_]) && m in medium ? :($m[$g-1,$g2]) : x, code)

        return esc(:(($code1p -$code1m)/(2*dx)))

    elseif coord == 1 && abm.dims == 3

        code1p = postwalk(x->@capture(x,m_[g_,g2_,g3_]) && m in medium ? :($m[$g+1,$g2,$g3]) : x, code)
        code1m = postwalk(x->@capture(x,m_[g_,g2_,g3_]) && m in medium ? :($m[$g-1,$g2,$g3]) : x, code)

        return esc(:(($code1p -$code1m)/(dx)))

    elseif coord == 2 && abm.dims == 2

        code1p = postwalk(x->@capture(x,m_[g_,g2_]) && m in medium ? :($m[$g,$g2+1]) : x, code)
        code1m = postwalk(x->@capture(x,m_[g_,g2_]) && m in medium ? :($m[$g,$g2-1]) : x, code)

        return esc(:(($code1p -$code1m)/(2*dy)))

    elseif coord == 2 && abm.dims == 3

        code1p = postwalk(x->@capture(x,m_[g_,g2_,g3_]) && m in medium ? :($m[$g,$g2+1,$g3]) : x, code)
        code1m = postwalk(x->@capture(x,m_[g_,g2_,g3_]) && m in medium ? :($m[$g,$g2-1,$g3]) : x, code)

        return esc(:(($code1p -$code1m)/(2*dy)))

    elseif coord == 3 && abm.dims == 3

        code1p = postwalk(x->@capture(x,m_[g_,g2_,g3_]) && m in medium ? :($m[$g,$g2,$g3+1]) : x, code)
        code1m = postwalk(x->@capture(x,m_[g_,g2_,g3_]) && m in medium ? :($m[$g,$g2,$g3-1]) : x, code)

        return esc(:(($code1p -$code1m)/(2*dz)))

    end

end

"""
    macro ∂2(coord,code)

Discretizes the `code` term of a drift process. e.g. Agent in 2D

∂2(1,m) → (m[i1_-1,i2_]-2*m[i1_,i2_]+m[i1_-1,i2_])/dx^2

the coordinate must be 1, 2 or 3, specifing the axis of differentiation.
"""
macro ∂2(coord,code)

    abm = AGENT

    if !(coord in [1,2,3][1:abm.dims])
        error("Coordinate in @mediumBorder with model of dimensionality $(abm.dims) must be $([1,2,3][1:abm.dims]).")
    end

    medium = [i for (i,prop) in abm.parameters if prop.scope == :medium]

    if coord == 1 && abm.dims == 1

        code1p = postwalk(x->@capture(x,m_[g_]) && m in medium ? :($m[$g+1]) : x, code)
        code1m = postwalk(x->@capture(x,m_[g_]) && m in medium ? :($m[$g-1]) : x, code)

        return esc(:(($code1p -2*$code +$code1m)/(dx^2)))

    elseif coord == 1 && abm.dims == 2

        code1p = postwalk(x->@capture(x,m_[g_,g2_]) && m in medium ? :($m[$g+1,$g2]) : x, code)
        code1m = postwalk(x->@capture(x,m_[g_,g2_]) && m in medium ? :($m[$g-1,$g2]) : x, code)

        return esc(:(($code1p -2*$code +$code1m)/(dx^2)))

    elseif coord == 1 && abm.dims == 3

        code1p = postwalk(x->@capture(x,m_[g_,g2_,g3_]) && m in medium ? :($m[$g+1,$g2,$g3]) : x, code)
        code1m = postwalk(x->@capture(x,m_[g_,g2_,g3_]) && m in medium ? :($m[$g-1,$g2,$g3]) : x, code)

        return esc(:(($code1p -2*$code +$code1m)/(dx^2)))

    elseif coord == 2 && abm.dims == 2

        code1p = postwalk(x->@capture(x,m_[g_,g2_]) && m in medium ? :($m[$g,$g2+1]) : x, code)
        code1m = postwalk(x->@capture(x,m_[g_,g2_]) && m in medium ? :($m[$g,$g2-1]) : x, code)

        return esc(:(($code1p -2*$code +$code1m)/(dy^2)))

    elseif coord == 2 && abm.dims == 3

        code1p = postwalk(x->@capture(x,m_[g_,g2_,g3_]) && m in medium ? :($m[$g,$g2+1,$g3]) : x, code)
        code1m = postwalk(x->@capture(x,m_[g_,g2_,g3_]) && m in medium ? :($m[$g,$g2-1,$g3]) : x, code)

        return esc(:(($code1p -2*$code +$code1m)/(dy^2)))

    elseif coord == 3 && abm.dims == 3

        code1p = postwalk(x->@capture(x,m_[g_,g2_,g3_]) && m in medium ? :($m[$g,$g2,$g3+1]) : x, code)
        code1m = postwalk(x->@capture(x,m_[g_,g2_,g3_]) && m in medium ? :($m[$g,$g2,$g3-1]) : x, code)

        return esc(:(($code1p -2*$code +$code1m)/(dz^2)))

    end

end

"""
    macro mediumInside()

Macro that returns true if mesh position is not in the border of the region.
"""
macro mediumInside()

    abm = AGENT

    code = :(i1_ > 1 && i1_ < NMedium_[1])
    if abm.dims > 1
        code = :($code && i2_ > 1 && i2_ < NMedium_[2])
    end
    if abm.dims > 2
        code = :($code && i3_ > 1 && i3_ < NMedium_[3])
    end

    return esc(code)

end

"""
    mediumBorder(coord, border)

Macro that returns true if mesh position is in the lower (border=-1) or upper (border=1) border of the axis coordinate 1, 2 or 3.
"""
macro mediumBorder(coord, border)

    abm = AGENT

    if !(coord in [1,2,3][1:abm.dims])
        error("Coordinate in @mediumBorder with model of dimensionality $(abm.dims) must be $([1,2,3][1:abm.dims]).")
    end

    if !(border in [-1, 1])
        error("Border in @mediumBorder must be one of: [-1, 1].")
    end

    if coord == 1 && border == -1
        return esc(:(i1_ == 1))
    elseif coord == 1 && border == 1
        return esc(:(i1_ == NMedium_[1]))
    elseif coord == 2 && border == -1
        return esc(:(i2_ == 1))
    elseif coord == 2 && border == 1
        return esc(:(i2_ == NMedium_[2]))
    elseif coord == 3 && border == -1
        return esc(:(i3_ == 1))
    elseif coord == 3 && border == 1
        return esc(:(i3_ == NMedium_[3]))
    end

end

#########################################################################
# Macros under development
#########################################################################
#
# macro loopOverMedium(it1, code)
# 
#     abm = AGENT
# 
#     if abm.dims != 1
#         error("This macri requires to specify $(abm.dims) iterators.")
#     end
# 
#     code = makeSimpleLoop(code,abm,nloops=abm.dims)
# 
#     code = postwalk(x->@capture(x,i_) && i == :i1_ ? it1 : x, code )
# 
#     return esc(code)
# 
# end
# 
# macro loopOverMedium(it1, it2, code)
# 
#     abm = AGENT
# 
#     if abm.dims != 2
#         error("This macri requires to specify $(abm.dims) iterators.")
#     end
# 
#     code = makeSimpleLoop(code,abm,nloops=abm.dims)
# 
#     code = postwalk(x->@capture(x,i_) && i == :i1_ ? it1 : x, code )
# 
#     return esc(code)
# 
# end
# 
# macro loopOverMedium(it1, it2, it3, code)
# 
#     abm = AGENT
# 
#     if abm.dims != 3
#         error("This macri requires to specify $(abm.dims) iterators.")
#     end
# 
#     code = makeSimpleLoop(code,abm,nloops=abm.dims)
# 
#     code = postwalk(x->@capture(x,i_) && i == :i1_ ? it1 : x, code )
# 
#     return esc(code)
# 
# end
# 
# macro loopOverAgents(it1, code)
# 
#     abm = AGENT
# 
#     code = makeSimpleLoop(code,abm)
# 
#     code = postwalk(x->@capture(x,i_) && i == :i1_ ? it1 : x, code )
# 
#     return esc(code)
# 
# end
# 
# macro loopOverAgents(code)
# 
#     if !(isa(code, Expr) && code.head === :for)
#         throw(ArgumentError("@threads requires a `for` loop expression"))
#     end
# 
#     it = code.args[1].args[1]
#     code = code.args[2]
# 
#     abm = AGENT
# 
#     code = makeSimpleLoop(code,abm)
# 
#     code = postwalk(x->@capture(x,i_) && i == :i1_ ? it : x, code )
# 
#     return esc(code)
# 
# end
# 