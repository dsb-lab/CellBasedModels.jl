
            #Check if parameter is a local parameter
            if length(findall(x->x==var,dictionaryVarNames["LocalParams:"])) == 0 && length(findall(x->x==var,dictionaryVarNames["CellCellParams:"])) == 0 
                error("Parameter ", var , " is declared in LocalParams or CellCellParams. It should appear in one of both.")
            end

            #Check if is a division rule
            if length(findall(x->x==split(var,".")[2],dictionaryVarNames["LocalParams:"])) == 0 && length(findall(x->x==split(var,".")[2],dictionaryVarNames["Variables:"])) == 0
                error(i , """ is not updating any local parameter or variable of the cell.""")
            end
