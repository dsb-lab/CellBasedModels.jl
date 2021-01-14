function saveVTKCompile(agentModel::Model,pos::Array{Symbol}=[:x,:y,:z])

    varDeclare = []
    fDeclare = []
    execute = []
    final = []
    kargs = []

    commArgs = commonArguments(agentModel)
    positions = findPositions(agentModel,pos)

    #varDeclare
    push!(varDeclare,
     :(pvdVTK = WriteVTK.paraview_collection(VTKfoldername_))
     )
    #fDeclare
    #Save all parameters
    l=[]
    if length(agentModel.declaredSymb["var"])>0
        for (i,j) in enumerate(agentModel.declaredSymb["var"])
            push!(l,:(vtkfile[$(string(j))] = Array(v_)[1:N_,$i]))
        end
    end
    if length(agentModel.declaredSymb["inter"])>0
        for (i,j) in enumerate(agentModel.declaredSymb["inter"])
            push!(l,:(vtkfile[$(string(j))] = Array(inter_)[1:N_,$i]))
        end
    end
    if length(agentModel.declaredSymb["loc"])>0
        for (i,j) in enumerate(agentModel.declaredSymb["loc"])
            push!(l,:(vtkfile[$(string(j))] = Array(loc_)[1:N_,$i]))
        end
    end
    if length(agentModel.declaredSymb["locInter"])>0
        for (i,j) in enumerate(agentModel.declaredSymb["locInter"])
            push!(l,:(vtkfile[$(string(j))] = Array(locInter_)[1:N_,$i]))
        end
    end
    if length(agentModel.declaredSymb["glob"])>0
        for (i,j) in enumerate(agentModel.declaredSymb["glob"])
            push!(l,:(vtkfile[$(string(j))] = Array(glob_)[$i]))
        end
    end
    if length(agentModel.declaredIds)>0
        for (i,j) in enumerate(agentModel.declaredIds)
            push!(l,:(vtkfile[$(string(j))] = Array(ids_)[1:N_,$i]))
        end
    end

    push!(fDeclare,
    :(
        function saveVTK(VTKfoldername_,$(commArgs...),pvdVTK,countSave)
            cells=[]
            for ic1_ in 1:N_
                cells = [WriteVTK.MeshCell(VTKCellTypes.VTK_VERTEX,[i]) for i in 1:N_]
            end

            #Create file
            vtkfile = WriteVTK.vtk_grid(string(VTKfoldername_,"_",countSave), transpose($positions), cells)
            #Save all parameters
            $(l...)
            #Add to the ParaView object
            pvdVTK[t_] = vtkfile

            return
        end
    )
    )
    #execute
    push!(execute,
    :(saveVTK(VTKfoldername_,$(commArgs...),pvdVTK,countSave))
    )
    #final
    push!(final,
    :(WriteVTK.vtk_save(pvdVTK))
    )
    #kargs
    push!(kargs,
    :(VTKfoldername_)
    )

    return varDeclare,fDeclare,execute,final,kargs
end

function findPositions(agentModel,vars)

    loc = "["
    for var in vars
        if var in agentModel.declaredSymb["var"]
            pos = findfirst(agentModel.declaredSymb["var"].==var)
            loc=string(loc,:(Array(v_)[:,$pos])," ")
        elseif var in agentModel.declaredSymb["loc"]
            pos = findfirst(agentModel.declaredSymb["loc"].==var) 
            loc=string(loc,:(Array(loc_)[:,$pos])," ")
        else
            error("Position parameter not found in the community. Position parameters have to be or variables or local parameters.")
        end
    end
    loc=string(loc[1:end-1],"]")

    return Meta.parse(loc)
end