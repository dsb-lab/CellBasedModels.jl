mutable struct interpretedData
    variables::Dict{String, Array{String}}
    equations::Dict{String, String}
    neighboursRules::Array{String}
    cellCellAlgorithms::Dict{String, Array{String}}
    divisionRules::Array{String}
    divisionAlgorithms::Array{String}
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
        text = string(text,"\n\n")
    end
    #Equations
    text = string(text,"Equations:\n\t")
    if length(z.equations) == 0
        text = string(text,"None","\n\t")
    else
        for j in keys(z.equations)
            text = string(text,z.equations[j],"\n\t")
        end
    end

    #Neighbour Rules
    text = string(text,"\nNeighboursRules:\n\t")
    if length(z.neighboursRules) == 0
        text = string(text,"None","\n\t")
    else
        for j in z.neighboursRules
            text = string(text,j,"\n\t")
        end
    end
    #cellCellAlgorithms
    for i in cellCellAlgorithmsHeaders
        text = string(text,"\n",i)
        if length(z.cellCellAlgorithms[i]) == 0
            text = string(text,"\n\tNone")
        else
            for j in z.cellCellAlgorithms[i]
                text = string(text,"\n\t",j)
            end
        end
        text = string(text,"\n")
    end
    #Division Rules
    text = string(text,"\nDivisionRules:")
    if length(z.divisionRules) == 0
        text = string(text,"\n\tNone\n")
    else
        for j in z.divisionRules
            text = string(text,"\n\t",j)
        end
        text = string(text,"\n")
    end
    #Division Algorithms
    text = string(text,"\nDivisionAlgorithms:\n\t")
    if length(z.divisionAlgorithms) == 0
        text = string(text,"None","\n\t")
    else
        for j in z.divisionAlgorithms
            text = string(text,j,"\n\t")
        end
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
    neighboursRules = Array{String}(undef,1) 
    dictionaryCellCellAlgorithms = Dict{String, Array{String}}() 
    divisionRules = Array{String}(undef,1)
    divisionAlgorithms = Array{String}(undef,1)
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
                if (data[counter] != "") && (findfirst("#",data[counter]) === nothing) #Ignore empty and comments
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
        dictionaryEqNames = Dict{String,String}([])
        if length(dictionaryVarNames["Variables:"]) > 0
            error("Some variables were defined but no differential equation was specified for them: ", dictionaryVarNames["Variables:"])
        end
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
            if (data[counter] != "") && (findfirst("#",data[counter]) === nothing) #Ignore empty and comments
                text = string(text,data[counter],"\n")
            end
            counter += 1
        end
        #Merge equations that were cut in different lines
        text = separateEqs(text)
        #Check differential equations are well defined
        for j in text
            if j[1] !=  'd' || split(j,"=")[1][end-2:end] != "/dt"
                error("Error in definition of the differential equation:\n\t", j, """\nWrite if as "dVARIABLE/dt=...", where VARIABLE is the variable of the equation.""")
            else
                dictionaryEqNames[j[2:end-4]]=j
            end
        end
        #Check variables have differential equations
        for i in dictionaryVarNames["Variables:"]
            found = 0
            eq = ""
            for j in text
                if findfirst(string("d",i,"/dt"),j) !== nothing
                    found += 1
                    eq = j
                end
                if found == 0
                    error("No differential equation has been defined for variable ", i, ".\n")
                elseif found > 1
                    error("Several differential equations have been defined for variable ", i, ". Only one is allowed.\n")
                end
            end
            if length(text) != length(dictionaryVarNames["Variables:"]) 
                error("Missmatch in the number of declared Variables: and Equations:\n Number of differential equations: ", length(text),  "\n Number of variables declared: ",length(dictionaryVarNames["Variables:"]))
            end
        end

    end          

    #Check Global algorithms
    pos = findall(x->x=="CellCellGlobalAlgorithms:",data)
    if length(pos) == 0
        dictionaryCellCellAlgorithms["CellCellGlobalAlgorithms:"] = []
    elseif length(pos) > 1
        error("CellCellGlobalAlgorithms header has been declared more than once in the model. If this is an error, please put all the variables in one header.")
    else            
        dictionaryCellCellAlgorithms["CellCellGlobalAlgorithms:"] = []
        #Merge all lines of the equations
        counter = pos[1]+1
        text = ""
        while counter <= l
            if length(findall(x->x==data[counter],AllHeaders)) != 0 
                break
            end
            if (data[counter] != "") && (findfirst("#",data[counter]) === nothing) #Ignore empty and comments
                text = string(text,data[counter],"\n")
            end
            counter += 1
        end
        #Merge equations that were cut in different lines
        text = separateEqs(text,"<-")
        #Check variables have differential equations
        for i in text
            var = split(i,"<-")[1]
            #Check cell is defined
            if var[1:5] != "cell."
                error("Line is not a CellCell algorithm:\n\t", i, "\n Such algorithms should start as cell.LOCAL_PARAMETER/VARIABLE <- ...")
            end
            #Check only one algorithm exists
            if length(findall(x->x==string(var,"<-"),text)) > 1
                error("Parameter ", var , " is updated by more than one different algorithm. Only one should be declared.")
            end 
            push!(dictionaryCellCellAlgorithms["CellCellGlobalAlgorithms:"],i)
        end
    end          

    #Check Neighbours Rules
    pos = findall(x->x=="NeighboursRules:",data)
    if length(pos) == 0
        neighboursRules = []
    elseif length(pos) > 1
        error("NeighboursRules header has not been declared more than once in the model. If this is an error, please put all the rules in one header.")
    else            
        neighboursRules = []
        #Add variables
        counter = pos[1]+1
        while counter <= l
            if length(findall(x->x==data[counter],AllHeaders)) != 0
                break
            end
            if (data[counter] != "") && (findfirst("#",data[counter]) === nothing) #Ignore empty and comments
                push!(neighboursRules,data[counter])
            end
            counter += 1
        end
    end

    #Check Neighbours algorithms
    pos = findall(x->x=="CellCellNeighboursAlgorithms:",data)
    if length(pos) == 0
        dictionaryCellCellAlgorithms["CellCellNeighboursAlgorithms:"] = []
    elseif length(pos) > 1
        error("CellCellNeighboursAlgorithms header has been declared more than once in the model. If this is an error, please put all the variables in one header.")
    else            
        dictionaryCellCellAlgorithms["CellCellNeighboursAlgorithms:"] = []
        #Merge all lines of the equations
        counter = pos[1]+1
        text = ""
        while counter <= l
            if length(findall(x->x==data[counter],AllHeaders)) != 0 
                break
            end
            if (data[counter] != "") && (findfirst("#",data[counter]) === nothing) #Ignore empty and comments
                text = string(text,data[counter],"\n")
            end
            counter += 1
        end
        #Merge equations that were cut in different lines
        text = separateEqs(text,"<-")
        #Check variables have differential equations
        for i in text
            var = split(i,"<-")[1]
            #Check cell is defined
            if var[1:5] != "cell."
                error("Line is not a CellCell algorithm:\n\t", i, "\n Such algorithms should start as cell.LOCAL_PARAMETER/VARIABLE <- ...")
            end
            #Check only one algorithm exists
            if length(findall(x->x==string(var,"<-"),text)) > 1
                error("Parameter ", var , " is updated by more than one different. Only one should be.")
            end
            push!(dictionaryCellCellAlgorithms["CellCellNeighboursAlgorithms:"],i)
        end
    end          

    #Check Division Rules
    pos = findall(x->x=="DivisionRules:",data)
    if length(pos) == 0
        divisionRules = []
    elseif length(pos) > 1
        error("DivisionRules header has been declared more than once in the model. If this is an error, please put all the rules in one header.")
    else            
        divisionRules = []
        #Add variables
        counter = pos[1]+1
        while counter <= l
            if length(findall(x->x==data[counter],AllHeaders)) != 0
                break
            end
            if (data[counter] != "") && (findfirst("#",data[counter]) === nothing) #Ignore empty and comments
                push!(divisionRules,data[counter])
            end
            counter += 1
        end
    end

    #Check Division algorithms
    pos = findall(x->x=="DivisionAlgorithms:",data)
    if length(pos) == 0
        divisionAlgorithms = []
    elseif length(pos) > 1
        error("DivisionAlgorithms header has been declared more than once in the model. If this is an error, please put all the variables in one header.")
    else            
        divisionAlgorithms = []
        #Merge all lines of the equations
        counter = pos[1]+1
        text = ""
        while counter <= l
            if length(findall(x->x==data[counter],AllHeaders)) != 0 
                break
            end
            if (data[counter] != "") && (findfirst("#",data[counter]) === nothing) #Ignore empty and comments
                text = string(text,data[counter],"\n")
            end
            counter += 1
        end
        #Merge equations that were cut in different lines
        text = separateEqs(text)
        #Check variables have differential equations
        for i in text
            var = split(i,"=")[1]
            #Check if is a division rule
            if length(findall(x->x==split(var,".")[1],["daughter1","daughter2","daughters","parent"])) == 0
                error(i , """ is not a division rule for any of the daughters or parent cells. It should be a rule for ["daughter1","daughter2","daughters","parent"].""")
            end
            push!(divisionAlgorithms,i)
        end
    end          

    return interpretedData(dictionaryVarNames, dictionaryEqNames, neighboursRules, dictionaryCellCellAlgorithms,divisionRules,divisionAlgorithms)
end

function separateEqs(text,symbol="=")
    a = split(text,"\n")
    textnew = a[1]
    for i in 2:length(a)
        if findfirst(symbol, a[i]) === nothing
            textnew = string(textnew,a[i])
        else
            textnew = string(textnew,"\n",a[i])
        end
    end

    return split(textnew,"\n")
end

function stackModels(a::Array{interpretedData})
    #Check crashes between parameters
    if length(a) == 1
        return a[1] 
    else
        allVariables = []
        for i in ParameterHeaders
            for j in a[end].variables[i]
                push!(allVariables,j)
            end
        end
        commonVariables = []
        for i in (length(a)-1):1
            for j in ParameterHeaders
                found = false
                for k in a[i].variables[j]
                    if length(findall(x->x==k,allVariables)) !== 0
                        push!(commonVariables,k)
                    else
                        push!(allVariables,k)
                    end
                end
            end
            if length(commonVariables) != 0
                error("No overlap of parameters should be found between both models. ", commonVariables, " were found in both models. Change names or use function upgradeModel.")
            end
        end
        #Merge variables
        c::interpretedData = deepcopy(a[1])

        for i in a[2:end]
            for j in ParameterHeaders
                for k in i.variables[j]
                    push!(c.variables[j],k)
                end
            end
            #Merge equations
            for j in keys(i.equations)
                c.equations[j] = i.equations[j]
            end
            #Merge neighboursRules
            for j in i.neighboursRules
                push!(c.neighboursRules, j)
            end
            #Merge cellCellAlgorithms
            for j in cellCellAlgorithmsHeaders
                for k in i.cellCellAlgorithms[j]
                    push!(c.cellCellAlgorithms[j],k)
                end
            end
            #Merge divisionRules
            for j in i.divisionRules
                push!(c.divisionRules, j)
            end
            #Merge divisionAlgorithms
            for j in i.divisionAlgorithms
                push!(c.divisionAlgorithms, j)
            end
        
        end

        return c
    end
end

function stackModels(a::Array{String})

    modelStack = Array{interpretedData}([])
    for i in a
        push!(modelStack, extractModel(i))
    end

    return stackModels(modelStack)
end

function upgradeModels(a::Array{interpretedData})
    #Check crashes between parameters
    if length(a) == 1
        return a[1] 
    else
        allVariables = Dict{String,Array{String}}([])
        allVariables["Variables:"]=[]
        allVariables["LocalParams:"]=[]
        allVariables["GlobalParams:"]=[]
        allVariables["RandomVariables:"]=[]
        allVariables["CellCellParams:"]=[]
        for i in ParameterHeaders
            for j in a[end].variables[i]
                push!(allVariables[i],j)
            end
        end
        commonVariables = []
        upgradedVariables = []
        for i in (length(a)-1):1
            println("Merging ", i)
            for j in ParameterHeaders
                for k in a[i].variables[j]
                    found = false
                    for l in ParameterHeaders
                        if length(findall(x->x==k,allVariables[l])) !== 0
                            if j == "GlobalParams:" && (l == "LocalParams:" || l == "Variables:")
                                if length(findall(x->x=k,upgradedVariables))==0
                                    push!(upgradedVariables,k)
                                end
                                println("Upgrade ",k,":", j,"->",l,)
                            elseif j == "LocalParams:" && l == "VariablesParams:"
                                if length(findall(x->x=k,upgradedVariables))==0
                                    push!(upgradedVariables,k)
                                end
                                println("Upgrade ",k,":", j,"->",l)
                            elseif j == "GlobalParams:" && l == "GlobalParams:"
                                println("Upgrade ",k,":", j,"->",l)
                            elseif j == "LocalParams:" && l == "LocalParams:"
                                println("Merged ",k,":", j,"->",l)
                            elseif j == "RandomVariables:" && l == "RandomVariables:"
                                println("Merged ",k,":", j,"->",l)
                            elseif j == "CellCellParams:" && l == "CellCellParams:"
                                println("Merged ",k,":", j,"->",l)
                            elseif j == "Variables:" && l == "Variables:"
                                error("Variable ", k, " defined in two different models. Variables should only have one definition.")
                            elseif j == "LocalParams:" && l == "GlobalParams:"
                                allVariables["GlobalParams:"] = allVariables["GlobalParams:"][allVariables["GlobalParams:"].!=k]
                                push!(allVariables["LocalParams:"],k)
                                if length(findall(x->x=k,upgradedVariables))==0
                                    push!(upgradedVariables,k)
                                end
                                println("Upgrade ",k,":", l,"->",j)
                            elseif j == "Variables:" && l == "GlobalParams:"
                                allVariables["GlobalParams:"] = allVariables["GlobalParams:"][allVariables["GlobalParams:"].!=k]
                                push!(allVariables["Variables:"],k)
                                if length(findall(x->x=k,upgradedVariables))==0
                                    push!(upgradedVariables,k)
                                end
                                println("Upgrade ",k,":", l,"->",j)
                            elseif j == "Variables:" && l == "LocalParams:"
                                allVariables["LocalParams:"] = allVariables["LocalParams:"][allVariables["LocalParams:"].!=k]
                                push!(allVariables["Variables:"],k)
                                if length(findall(x->x=k,upgradedVariables))==0
                                    push!(upgradedVariables,k)
                                end
                                println("Upgrade ",k,":", l,"->",j)
                            else
                                push!(commonVariables,k)
                            end
                            found = true
                        end
                    end
                    if found == false
                        push!(allVariables[j],k)
                    end
                end
            end
        end
        if length(commonVariables) != 0
            error("""No upgrade of parameters can happen for parameters defined as ["RandomVariables", "CellCellParams"]. """, commonVariables, " were found crashing between models. Change names or use function upgradeModel.")
        end

        #Merge variables
        c::interpretedData = deepcopy(a[1])
        for j in ParameterHeaders
            c.variables = allVariables
        end

        for i in a[2:end]
            #Merge equations
            for j in keys(i.equations)
                c.equations[j] = i.equations[j]
            end
            #Merge neighboursRules
            for j in i.neighboursRules
                push!(c.neighboursRules, j)
            end
            #Merge cellCellAlgorithms
            for j in cellCellAlgorithmsHeaders
                for k in i.cellCellAlgorithms[j]
                    push!(c.cellCellAlgorithms[j],k)
                end
            end
            #Merge divisionRules
            for j in i.divisionRules
                push!(c.divisionRules, j)
            end
            #Merge divisionAlgorithms
            for j in i.divisionAlgorithms
                push!(c.divisionAlgorithms, j)
            end
        
        end

        return c
    end
end

function upgradeModels(a::Array{String})

    modelStack = Array{interpretedData}([])
    for i in a
        push!(modelStack, extractModel(i))
    end

    return upgradeModels(modelStack)
end
