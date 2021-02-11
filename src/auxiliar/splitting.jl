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

function splits(income,level,l)
    args = income.args
    out = nothing
    #println(args)
    if args[1] == :+ || args[1] == :-
        for i in 1:length(args)
            if args[i] == :dt
                args[i] = 1
                out = "t"
            elseif args[i] == :dW
                args[i] = 1
                out = "W"
            elseif typeof(args[i]) == Expr
                #println(args[i])
                args[i],out = splits(args[i],level+1,l)
                #println(args[i])
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
    end

    #println(income.args)     
    #income.args = args
    
    return income, out
end

function splitEqs(value)
    list = quote end
    nRand = 0
    for i in 1:length(value.args)
        try value.args[i].head
            eq = value.args[i]
            l = Any[0,0]
            args,out = splits(eq.args[2],0,l)
            eq.args[2] = args
            if l == [0,0]
                push!(list.args,eq)
            else
                var = Meta.parse(string(eq.args[1])[2:end])
                varf = Meta.parse(string(var,"f_"))
                varg = Meta.parse(string(var,"g_"))
                ineq = nothing
                if l[1] != 0
                    push!(list.args,:($varf = $(l[1])))
                    ineq = :($varf*dt)
                end
                if l[2] != 0
                    nRand += 1
                    push!(list.args,:($varg = $(l[2])))
                    if ineq != nothing
                        ineq = :($ineq+$varg*dW)
                    else
                        ineq = :($varg*dW)
                    end
                end
                push!(list.args,:($(eq.args[1]) = $ineq))
            end
        catch
        end
    end
    
    return list, nRand
end