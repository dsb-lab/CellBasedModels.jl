"""
Split strings by an specified symbol.

# Arguments
 - **text** (String) Text to split
 - **symbol** (String) Symbol to use for spliting

# Returns
Array{String}

# Example
```julia
> text = 
"
a = b
+ 3
c = d
"
> splitLines(text,"=")
["a = b + 3","c = b"]
```
"""
function splitLines(text::String,symbol::String)
    list=[string(i) for i in split(text,"\n") if i != ""]
    listN=[]
    for e in list
        if !occursin(symbol, e) #Append if just jump in line
            listN[end] = string(listN[end]," ",e)
        else
            append!(listN,[e])
        end
    end
    return listN
end


function splitUpdating(text::String)
    list=[string(i) for i in split(text,"\n") if i != ""]
    listN=[]
    for e in list
        app = true
        for i in Array(["+=";"-=";"*=";"/=";"÷=";"%=";"^=";" = "])
            if occursin(i, e)
                app = false
                append!(listN,[e])
                break
            end
        end
        if app
            listN[end] = string(listN[end]," ",e)
        end
    end
    return listN
end

"""
Recurrent function auxiliar to the splitEqs for the block of code adaptation
"""
function splits(income,level,l)
    out = nothing
    if income == :dt && level == 0
        l[1] = 1
    elseif income == :(-dt) && level == 0
        l[1] = -1
    elseif income == :dW && level == 0
        l[2] = 1
    elseif income == :(-dW) && level == 0
        l[2] = -1
    else
        args = income.args
        if args[1] == :+ || args[1] == :-
            for i in 1:length(args)
                if args[i] == :dt
                    args[i] = 1
                    out = "t"
                elseif args[i] == :dW
                    args[i] = 1
                    out = "W"
                elseif typeof(args[i]) == Expr
                    args[i],out = splits(args[i],level+1,l)
                end
                if  out == "t"
                    if l[1] == 0
                        l[1] = args[i]
                    else
                        if args[1] == :+
                            l[1] = :($(l[1])+$(args[i]))
                        else
                            l[1] = :($(l[1])-$(args[i]))
                        end
                    end
                    out = nothing
                elseif  out == "W"
                    if l[2] == 0
                        l[2] = args[i]
                    else
                        if args[2] == :+
                            l[2] = :($(l[2])+$(args[i]))
                        else
                            l[2] = :($(l[2])-$(args[i]))
                        end
                    end
                    out = nothing
                end
            end
        elseif args[1] == :*
            if :dt in args
                if length(args) > 3
                    income.args = args[[i for i in 1:length(args) if args[i]!=:dt]]
                    out = "t" 
                else
                    income = :($(args[[i for i in 2:length(args) if args[i]!=:dt]][1]))
                    out = "t"
                end
            elseif :dW in args
                if length(args) > 3
                    income.args = args[[i for i in 1:length(args) if args[i]!=:dW]]
                    out = "W"
                else
                    income = :($(args[[i for i in 2:length(args) if args[i]!=:dW]][1]))
                    out = "W"
                end
            end
            if level == 0
                if  out == "t"
                    if l[1] == 0
                        l[1] = income
                    else
                        if args[1] == :+
                            l[1] = :($(l[1])+$(income))
                        else
                            l[1] = :($(l[1])-$(income))
                        end
                    end
                    out = nothing
                elseif  out == "W"
                    if l[2] == 0
                        l[2] = income
                    else
                        if args[2] == :+
                            l[2] = :($(l[2])+$(income))
                        else
                            l[2] = :($(l[2])-$(income))
                        end
                    end
                    out = nothing
                end            
            end
        end
    end
    
    return income, out
end

"""
Prepares a block of code with differential equations to be vectorized and introduced in the integration algorithms. 
Returns the adapted block of code and the list of the lines where there has been declared a Wienner random variable.

# Arguments
 - **value** (Expr) Block of code with differential equations

# Returns
Expr, Array{Int} 
"""
function splitEqs(value)
    list = quote end
    nRand = []
    count = 1
    for i in 1:length(value.args)
        try value.args[i].head
            eq = value.args[i]
            l = Any[0,0]
            args,out = splits(eq.args[2],0,l)
            eq.args[2] = args
            if l == [0,0]
                push!(list.args,eq)
                count += 1
            else
                var = Meta.parse(string(eq.args[1])[2:end])
                varf = Meta.parse(string(var,"f_"))
                varg = Meta.parse(string(var,"g_"))
                ineq = nothing
                if l[1] != 0
                    push!(list.args,:($varf = $(l[1])))
                    ineq = :($varf*dt)
                    count += 1
                end
                if l[2] != 0
                    push!(list.args,:($varg = $(l[2])))
                    if ineq != nothing
                        ineq = :($ineq+$varg*dW)
                    else
                        ineq = :($varg*dW)
                    end
                    count += 1
                end
                push!(list.args,:($(eq.args[1]) = $ineq))
                count += 1
                if nRand == []
                    push!(nRand,count)
                    count = 0
                else
                    push!(nRand,nRand[end]+count)
                    count = 0
                end
            end
        catch
        end
    end
    
    return list, nRand
end