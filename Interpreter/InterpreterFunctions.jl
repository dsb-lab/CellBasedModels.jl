function extractModel(textModel)

    #Make copy
    data = SubString(textModel,1)

    #Standarize    
    data=replace(data," "=>"")    #Remove spaces
    data=replace(data,"\t"=>"\n") #Convert tabs into breaks
    data=replace(data,","=>"\n")  #Convert commas into breaks
    data=replace(data,";"=>"\n")  #Convert semicolons into breaks

    dictionaryNames = Dict{String, Array{String}}() 
    dictionaryValues = Dict{String, Array{String}}() 
    dictionaryDyn = Dict{String, Array{String}}() 
    data = split(data,"\n")
    l = length(data)
    for i in AllHeadersParams
        #Find if header appears
        pos = findall(x->x==i,data)
        #Check no double declarations
        if length(pos)>1
            error(string(i, " has been declared more than once in the Spatial model. Put all the variables under one declaration only."))
        elseif length(pos) == 0
            dictionaryNames[i] = []
            dictionaryValues[i] = []
        else            
            dictionaryNames[i] = []
            dictionaryValues[i] = []
            #Add variables
            counter = pos[1]+1
            while counter <= l
                if length(findall(x->x==data[counter],AllHeadersParams)) != 0
                    break
                end
                if data[counter] != ""
                    #Add with initialisation
                    if length(findall("=",data[counter])) == 1
                        value = split(data[counter],"=")
                        push!(dictionaryNames[i],value[1])
                        push!(dictionaryValues[i],value[2])
                    else #Add without initialisation
                        push!(dictionaryNames[i],data[counter])
                        push!(dictionaryValues[i],"NaN")
                    end
                end
                counter += 1
            end
        end
    end
    for i in AllHeadersEqs
        #Find if header appears
        pos = findall(x->x==i,data)
        #Check no double declarations
        if length(pos)>1
            error(string(i, " has been declared more than once in the Spatial model. Put all the variables under one declaration only."))
        elseif length(pos) == 0
            dictionaryDyn[i] = []
        else            
            dictionaryDyn[i] = []
            #Merge all lines of the equations
            counter = pos[1]+1
            text = ""
            while counter <= l
                if length(findall(x->x==data[counter],AllHeadersParams)) != 0
                    break
                end
                text = string(text,data[counter],"\n")
                counter += 1
            end
            #Merge equations that were cut in different lines
            text = separateEqs(text)
            println(text)
            for j in text
                push!(dictionaryDyn[i],j)
            end          
        end
    end

    return dictionaryNames, dictionaryValues, dictionaryDyn
end

function separateEqs(text)
    a = split(text,"\n")
    textnew = a[1]
    for i in 2:length(a)
        if findfirst("=", a[i]) === nothing
            textnew = string(textnew,a[i])
        else
            textnew = string(textnew,"\n",a[i])
        end
    end
    return split(textnew,"\n")
end

function changeParse(variable,list,name)
    for i in 1:length(list)
        if variable == Meta.parse(list[i])
            return Meta.parse(string(name,i,"]"))
            break
        end
    end
end

function findParse(expression,list)
    for i in 1:length(expression.args)
        if typeof(expression.args[i]) == Symbol
            returned = changeParse(expression.args[i],list,"dsparams[i,")
            if returned !== nothing
                expression.args[i]=returned
            end
            #println("Symbol")
        elseif typeof(expression.args[i]) == Expr
            findParse(expression.args[i],list)
        end
    end
end
