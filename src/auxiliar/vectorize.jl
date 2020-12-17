function vectParams(agentModel::Model,text)
        
    #Vectorisation changes
    varsOb = ["NAME_","NAME_₁","NAME_₂","NAME_ₚ"]
    varsTar = ["v_[ic1_,POS_]","v_[ic1_,POS_]","v_[nnic2_,POS_]","v_[ic1_,POS_]"]
    text = subs(agentModel.declaredSymb["var"],varsOb,varsTar,text)
        
    interOb = ["NAME_","NAME_₁","NAME_₂","NAME_ₚ"]
    interTar = ["inter_[ic1_,POS_]","inter_[ic1_,POS_]","inter_[nnic2_,POS_]","inter_[ic1_,POS_]"]
    text = subs(agentModel.declaredSymb["inter"],interOb,interTar,text)

    locInterOb = ["NAME_","NAME_₁","NAME_₂","NAME_ₚ"]
    locInterTar = ["locInter_[ic1_,POS_]","locInter_[ic1_,POS_]","locInter_[nnic2_,POS_]","locInter_[ic1_,POS_]"]
    text = subs(agentModel.declaredSymb["locInter"],locInterOb,locInterTar,text)
    
    globOb = ["NAME_"]
    globTar = ["glob_[POS_]"]
    text = subs(agentModel.declaredSymb["glob"],globOb,globTar,text)

    locOb = ["NAME_","NAME_₁","NAME_₂","NAME_ₚ"]
    locTar = ["loc_[ic1_,POS_]","loc_[ic1_,POS_]","loc_[nnic2_,POS_]","loc_[ic1_,POS_]"]
    text = subs(agentModel.declaredSymb["loc"],locOb,locTar,text)

    ##Random variables
    locRandOb = ["NAME_"]
    locRandTar = ["locRand_[ic1_,POS_]"]
    text = subs([i[1] for i in agentModel.declaredRandSymb["locRand"]],locRandOb,locRandTar,text)

    locInterRandOb = ["NAME_"]
    locInterRandTar = ["locInterRand_[ic1_,ic2_,POS_]"]
    text = subs([i[1] for i in agentModel.declaredRandSymb["locInterRand"]],locInterRandOb,locInterRandTar,text)

    globRandOb = ["NAME_"]
    globRandTar = ["globRand_[POS_]"]
    text = subs([i[1] for i in agentModel.declaredRandSymb["globRand"]],globRandOb,globRandTar,text)
    
    return text
end

function vectParams(agentModel::Model,text::Array)
    textF = [] 
    for textL in text
        push!(textF,vectParams(agentModel,textL))
    end
    
    return textF
end