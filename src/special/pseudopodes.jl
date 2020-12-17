function addKRandomNeighbours!(agentModel::Model,name::Symbol;updateCond::String,weight::String,updatePars::String,baseNeighbourhood::Symbol=:fullConnected_,k=1)
    
    #Check if baseNeighbourhood exist in model
    if baseNeighbourhood != :Nothing_
        if !(baseNeighbourhood in agentModel.declaredSymb["nn"])
            error(baseNeighbourhood, " is not a neighborhood existing in the model.")
        end
        baseN = Meta.parse(string(baseNeighbourhood,"N_[i1_]"))
        baseList = Meta.parse(string(baseNeighbourhood,"List_[i1_,i2_]"))
        neighMax = agentModel.nn[baseNeighbourhood].neighMax
    else
        baseN = :N_
        baseList = :i2_
        neighMax = :N_
    end

    #Create Neighbour Object
    no = NeighboursObject(name)
    no.neighMax = neighMax
    
    #Add neighbours list and number of neighbours (COMPULSORY MATRICES)
    nameList = Meta.parse(string(name,"List_"))
    nameN = Meta.parse(string(name,"N_"))
    no.varDeclared[nameList]=:(zeros(:N_,$neighMax))
    no.varDeclared[nameN]=:(zeros(Int,:N_))
    #Add weiths, total weight and random choose matrix (AUXILIAR MATRICES)    
    nameW = Meta.parse(string(name,"W_"))
    nameWT = Meta.parse(string(name,"WT_"))
    nameRand = Meta.parse(string(name,"Rand_"))
    no.varDeclared[nameW]=:(zeros(:N_,$neighMax))
    no.varDeclared[nameWT]=:(zeros(:N_,2))
    no.varDeclared[nameRand]=:(zeros(:N_,$k))
    
    #Add outFunction
    of = :(rand!($nameRand)) #Generate a random set before computing the nn
    no.outFunc = of
    #Add inFunction
    f = :(
        for i1_ in index_:stride_:N_
            $nameN[i1_] = 0
            if $updateCond
                #Reweight the matrices
                for i2_ in 1:$baseN
                    $nameW[i1_,$baseList] = $weight
                    $nameWT[i1_,2] += $weight
                end
                for j_ in 1:$k
                    $nameWT[i1_,1] = 0 #Initialize the cumulative sum
                    for i2_ in 1:$baseN[i1_]
                        if $nameW[i1_,i2_] < $nameWT[i1_,2]*$nameRand[i1_,j_]
                            $nameWT[i1_,1] += $nameW[i1_,i2_]
                        else
                            $nameN[i1_] += 1
                            $nameList[i1_,$nameN[i1_]] = i2_ 
                            #Remove the weight of the already chosen connection
                            $nameW[i1_,i2_] = 0
                        end
                    end
                end
                $updatePars
            end
        end    
        )

    no.inFunc = f
    
    return no
    
end