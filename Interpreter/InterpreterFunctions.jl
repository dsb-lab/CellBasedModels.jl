mutable struct interpretedData
    variables::Dict{String, Array{String}}
    equations::Dict{String, String}
end
#Pretty printing of the noMovement structure
Base.show(io::IO, z::interpretedData) = print(io, displayInterpretedData(z))

function displayInterpretedData(z::interpretedData)
    text = ""
    #Parameters
    for i in ParameterHeaders
        text = string(text,i,"\n\t")
        if length(z.variables[i]) == 0
            text = string(text,"None")
        else
            for j in z.variables[i]
                text = string(text,j,", ")
            end
        end
        text = string(text,"\n")
    end
    #Equations
    text = string(text,"Equations:\n\t")
    for j in keys(z.equations)
        text = string(text,z.equations[j],"\n")
    end

    return text
end

function extractModel(textModel)

    #Make copy
    data = SubString(textModel,1)

    #Standarize    
    data=replace(data," "=>"")     #Remove spaces
    data=replace(data,"\t"=>"\n")  #Convert tabs into breaks
    data=replace(data,","=>"\n")   #Convert commas into breaks
    data=replace(data,";"=>"\n")   #Convert semicolons into breaks
    data=replace(data,"#"=>"\n#")  #Separate comments into breaks
    #Separate the data
    data = split(data,"\n")

    dictionaryVarNames = Dict{String, Array{String}}() 
    dictionaryEqNames = Dict{String, String}() 
    l = length(data)
    for i in ParameterHeaders
        #Find if header appears
        pos = findall(x->x==i,data)
        if length(pos) == 0 #Check if header has been declared
            dictionaryVarNames[i] = []
        elseif length(pos) > 1
            error(i, " header has been declared more than once in the model. If this is an error, please put all the variables in one header.")
        else            
            dictionaryVarNames[i] = []
            #Add variables
            counter = pos[1]+1
            while counter <= l
                if length(findall(x->x==data[counter],AllHeaders)) != 0
                    break
                end
                if data[counter] != "" || findfirst("#",data[counter]) !== nothing #Ignore empty and comments
                    push!(dictionaryVarNames[i],data[counter])
                end
                counter += 1
            end
        end
    end
    #Check repeated variables in same header
    for (i,j) in enumerate(ParameterHeaders)
        for (k,l) in enumerate(dictionaryVarNames[j])
            if length(findall(x->x==l,dictionaryVarNames[j]))>1
                error("Parameter ", l, " has been declared more then once in ", j)
            end
        end
    end
    #Check repeated variables between headers
    for (i,j) in enumerate(ParameterHeaders[1:end-1])
        for (k,l) in enumerate(dictionaryVarNames[j])
            for (m,n) in enumerate(ParameterHeaders[i+1:end])
                if length(findall(x->x==l,dictionaryVarNames[n]))!=0
                    error("Parameter ", l, " has been declared twice: in ", j, " and ", n, " headers. Should be only specified once.")
                end
            end
        end
    end

    #Check equations
    pos = findall(x->x=="Equations:",data)
    if length(pos) == 0
        dictionaryEqNames[i] = []
    elseif length(pos) > 1
        error("Equations header has been declared more than once in the model. If this is an error, please put all the variables in one header.")
    else            
        #Merge all lines of the equations
        counter = pos[1]+1
        text = ""
        while counter <= l
            if length(findall(x->x==data[counter],AllHeaders)) != 0
                break
            end
            text = string(text,data[counter],"\n")
            counter += 1
        end
        #Merge equations that were cut in different lines
        text = separateEqs(text)
        #Check variables have differential equations
        for i in dictionaryVarNames["Variables:"]
            found = 0
            eq = ""
            for j in text
                if findfirst(string("d",i,"/dt"),j) !== 0
                    found += 1
                    eq = j
                end
                if found == 0
                    error("No differential equation has been defined for variable ", i, ".\n")
                elseif found > 1
                    error("Several differential equations have been defined for variable ", i, ". Only one is allowed.\n")
                else
                    dictionaryEqNames[j]=eq
                end
            end
            if length(text) != length(dictionaryVarNames["Variables:"]) 
                error("Missmatch in the number of declared Variables: and Equations:\n Number of differential equations: ", length(text),  "\n Number of variables declared: ",length(dictionaryVarNames["Variables:"]))
            end
        end
    end          

    return interpretedData(dictionaryVarNames, dictionaryEqNames)
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

function stackModels(a::interpretedData,b::interpretedData)
    #Check crashes between parameters
    commonVariables = []
    for i in ParameterHeaders
        for j in a.variables[i]
            found = false
            for k in ParameterHeaders
                if findall(x->x==j,b.variables[k])
                    push!(commonVariables,j)
                end
            end
        end
    end
    if length(commonVariables) != 0
        error("No overlap of parameters should be found between both models. ", commonVariables, " were found in both models. Change names of use function upgradeModel.")
    end

    #Merge variables
    c::interpretedData = deepcopy(a)
    for i in ParameterHeaders
        for j in b.variables[i]
            push!(c.variables[i],j)
        end
    end
    #Merge equations
    for j in keys(b.equations)
        c.equations[j] = b.equations[j]
    end

    return c
end

function stackModels!(a::interpretedData,b::interpretedData)
    #Check crashes between parameters
    commonVariables = []
    for i in ParameterHeaders
        for j in a.variables[i]
            found = false
            for k in ParameterHeaders
                if findall(x->x==j,b.variables[k])
                    push!(commonVariables,j)
                end
            end
        end
    end
    if length(commonVariables) != 0
        error("No overlap of parameters should be found between both models. ", commonVariables, " were found in both models. Change names of use function upgradeModel.")
    end

    #Merge variables
    for i in ParameterHeaders
        for j in b.variables[i]
            push!(a.variables[i],j)
        end
    end
    #Merge equations
    for j in keys(b.equations)
        a.equations[j] = b.equations[j]
    end

    return
end

function stackModels(a::String,b::String)

    model1::interpretedData = extractModel(a)
    model2::interpretedData = extractModel(b)
    stackModels!(model1,model2)

    return model1
end
