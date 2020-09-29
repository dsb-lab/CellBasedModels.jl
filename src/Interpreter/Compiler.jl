function compile(model::interpretedData;platform="gpu")

    if platform == "gpu"

        #create header
        text = """function evolve(model;
        timeOfEvolution,integrationMethod,maxNumCells,
        timeStep,savingStep,sharingStep,
        saveFile,expectedNumNeighbours,platform="cpu")\n\n"""

        #Create memory allocations
        ##Variables (maxNumCells * OrderIntegrator * Variables)
        text = string(text,"""\tvars = CUDA.zeros(maxNumCells,integrationMethod.order+2,length(model.variables["Variables:"]))\n""")
        ##LocalParams(maxNumCells * 2 * LocalParams)
        text = string(text,"""\tlocParams = CUDA.zeros(maxNumCells,2,length(model.variables["LocalParams:"]))\n""")
        ##GlobalParams(2*GlobalParams)
        text = string(text,"""\tglobParams = CUDA.zeros(2,length(model.variables["GlobalParams:"]))\n""")
        ##Neighbours(maxNumCells * expectedNumNeighbours)
        text = string(text,"""\tnumNeigbours = CUDA.CuArray{Int32}(maxNumCells)\n""")
        text = string(text,"""\tneighbours = CUDA.CuArray{Int32}(maxNumCells,expectedNumNeighbours)\n""")

        #Create functions
        if model.neighboursRules !== []
            ##Neighbours rules
            text = string(text,"""\n""")        
            text = string(text,neighboursTextfunction(model))
        end
        if model.divisionRules !== []
            ##Division rules
            text = string(text,"""\n""")        
            text = string(text,divisionTextfunction(model))
        end
        if length(model.equations) > 0
            ##Equations
            text = string(text,"""\n""")        
            text = string(text,equationsTextfunction(model))
        end
        if length(model.cellCellAlgorithms["CellCellGlobalAlgorithms:"]) > 0        
            ##GlobalAlgorithms
            text = string(text,"""\n""")        
            text = string(text,globalAlgorithmsTextfunction(model))
        end
        if length(model.cellCellAlgorithms["CellCellNeighboursAlgorithms:"]) > 0       
            ##GlobalAlgorithms
            text = string(text,"""\n""")        
            text = string(text,localAlgorithmsTextfunction(model))
        end

        #Finish function
        text = string(text,"end")
    
    end

    return text

end

function neighboursTextfunction(model::interpretedData)
    text = "\tfunction neighbours(vars, localParams, globParams, numNeighbours, neighboursParams, t, i, j)\n\t\treturn "

    for (l,i) in enumerate(model.neighboursRules)
        i = replace(i,"."=>"")
        #Parsing Variables
        for (j,k) in enumerate(model.variables["Variables:"])
            i = findParse(i,string("cell1",k),string("vars[i,1,",j,"]"))
            i = findParse(i,string("cell2",k),string("vars[j,1,",j,"]"))
        end
        #Parsing Local Params
        for (j,k) in enumerate(model.variables["LocalParams:"])
            i = findParse(i,string("cell1",k),string("locParams[i,1,",j,"]"))
            i = findParse(i,string("cell2",k),string("locParams[j,1,",j,"]"))
        end
        #Parsing Global
        for (j,k) in enumerate(model.variables["GlobalParams:"])
            i = findParse(i,k,string("globParams[1,",j,"]"))
        end

        text = string(text,"(",i,")")
        if l < length(model.neighboursRules)
            text = string(text," && ")
        end
    end

    text = string(text,"\n\tend\n")

    return text
end

function divisionTextfunction(model::interpretedData)
    text = "\tfunction isDividing(vars, localParams, globParams, numNeighbours, neighboursParams, t, i)\n\t\treturn "

    for (l,i) in enumerate(model.divisionRules)
        i = replace(i,"."=>"")
        #Parsing Variables
        for (j,k) in enumerate(model.variables["Variables:"])
            i = findParse(i,k,string("vars[i,1,",j,"]"))
        end
        #Parsing Local Params
        for (j,k) in enumerate(model.variables["LocalParams:"])
            i = findParse(i,k,string("locParams[i,1,",j,"]"))
        end
        #Parsing Global
        for (j,k) in enumerate(model.variables["GlobalParams:"])
            i = findParse(i,k,string("globParams[1,",j,"]"))
        end

        text = string(text,"(",i,")")
        if l < length(model.divisionRules)
            text = string(text," && ")
        end
    end

    text = string(text,"\n\tend\n")

    return text
end

function equationsTextfunction(model::interpretedData)
    text = "\tfunction equations(vars, localParams, globParams, numNeighbours, neighboursParams, t, i, j, k)\n\t\t"

    for l in keys(model.equations)
        i = model.equations[l]
        i = replace(i,string("d",l,"/dt")=>string(l,"new"))
        #Parsing Variables
        for (j,k) in enumerate(model.variables["Variables:"])
            i = findParse(i,k,string("vars[i,j,",j,"]"))
            i = findParse(i,string(k,"new"),string("vars[i,k,",j,"]"))
        end
        #Parsing Local Params
        for (j,k) in enumerate(model.variables["LocalParams:"])
            i = findParse(i,k,string("locParams[i,1,",j,"]"))
        end
        #Parsing Global
        for (j,k) in enumerate(model.variables["GlobalParams:"])
            i = findParse(i,k,string("globParams[1,",j,"]"))
        end

        text = string(text,i,"\n\t\t")
    end

    text = string(text,"\n\t\treturn\n\tend\n")

    return text
end

function globalAlgorithmsTextfunction(model::interpretedData)
    text = "\tfunction globalAlgorithms(vars, localParams, globParams, numNeighbours, neighboursParams, t, i, j)\n\t\t"

    for (l,i) in enumerate(model.cellCellAlgorithms["CellCellGlobalAlgorithms:"])
        i = string("rrr",i)
        i = replace(i,"."=>"")
        i = replace(i,"<-"=>"+=")
        #Parsing Variables
        for (j,k) in enumerate(model.variables["Variables:"])
            i = findParse(i,string("rrrcellr",k),string("vars[i,2,",j,"]"))
            i = findParse(i,string("cellr",k),string("vars[i,1,",j,"]"))
            i = findParse(i,string("cellg",k),string("vars[j,1,",j,"]"))
        end
        #Parsing Local Params
        for (j,k) in enumerate(model.variables["LocalParams:"])
            i = findParse(i,string("rrrcellr",k),string("locParams[i,2,",j,"]"))
            i = findParse(i,string("cellr",k),string("locParams[i,1,",j,"]"))
            i = findParse(i,string("cellg",k),string("locParams[j,1,",j,"]"))
        end
        #Parsing Global
        for (j,k) in enumerate(model.variables["GlobalParams:"])
            i = findParse(i,string("rrrcellr",k),string("globParams[2,",j,"]"))
            i = findParse(i,string("cellr",k),string("globParams[1,",j,"]"))
            i = findParse(i,string("cellg",k),string("globParams[1,",j,"]"))
            i = findParse(i,string(k),string("globParams[1,",j,"]"))
        end

        text = string(text,i,"\n\t\t")
    end

    text = string(text,"\n\t\treturn\n\tend\n")

    return text
end

function localAlgorithmsTextfunction(model::interpretedData)
    text = "\tfunction localAlgorithms(vars, localParams, globParams, numNeighbours, neighboursParams, t, i, j)\n\t\t"

    for (l,i) in enumerate(model.cellCellAlgorithms["CellCellNeighboursAlgorithms:"])
        i = string("rrr",i)
        i = replace(i,"."=>"")
        i = replace(i,"<-"=>"+=")
        #Parsing Variables
        for (j,k) in enumerate(model.variables["Variables:"])
            i = findParse(i,string("rrrcellr",k),string("vars[i,2,",j,"]"))
            i = findParse(i,string("cellr",k),string("vars[i,1,",j,"]"))
            i = findParse(i,string("cellg",k),string("vars[j,1,",j,"]"))
        end
        #Parsing Local Params
        for (j,k) in enumerate(model.variables["LocalParams:"])
            i = findParse(i,string("rrrcellr",k),string("locParams[i,2,",j,"]"))
            i = findParse(i,string("cellr",k),string("locParams[i,1,",j,"]"))
            i = findParse(i,string("cellg",k),string("locParams[j,1,",j,"]"))
        end
        #Parsing Global
        for (j,k) in enumerate(model.variables["GlobalParams:"])
            i = findParse(i,string("rrrcellr",k),string("globParams[2,",j,"]"))
            i = findParse(i,string("cellr",k),string("globParams[1,",j,"]"))
            i = findParse(i,string("cellg",k),string("globParams[1,",j,"]"))
            i = findParse(i,string(k),string("globParams[1,",j,"]"))
        end

        text = string(text,i,"\n\t\t")
    end

    text = string(text,"\n\t\treturn\n\tend\n")

    return text
end

function findParse!(expression,var,change)
    for i in 1:length(expression.args)
        if typeof(expression.args[i]) == Symbol && string(expression.args[i]) == var
            expression.args[i]=Meta.parse(change)
        elseif typeof(expression.args[i]) == Expr
            findParse!(expression.args[i],var,change)
        end
    end

    return string(expression)
end

function findParse(text,var,change)
    expression = Meta.parse(text)

    return string(findParse!(expression,var,change))
end
