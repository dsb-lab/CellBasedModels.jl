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