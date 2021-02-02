MODEL_BASIC = Model()
    
inter = 
"
rₐ = sqrt((x₁-x₂)^2+(y₁-y₂)^2+(z₁-z₂)^2)/(2*r)
rxₐ = (x₁-x₂)/rₐ
ryₐ = (y₁-y₂)/rₐ
rzₐ = (z₁-z₂)/rₐ
if rₐ < 0.7 && rₐ > 0.
    fx += 2*(0.7-rₐ)*rxₐ
    fy += 2*(0.7-rₐ)*ryₐ
    fz += 2*(0.7-rₐ)*rzₐ
elseif rₐ > 0.8*r && rₐ < 1*r
    fx -= 0.5*(rₐ-0.8)*rxₐ
    fy -= 0.5*(rₐ-0.8)*ryₐ
    fz -= 0.5*(rₐ-0.8)*rzₐ
end
"
addInteraction!(MODEL_BASIC,[:fx,:fy,:fz],inter)

update = 
"
D = 0. /(t+1)
"
addGlobal!(MODEL_BASIC,[:D,:r],updates=update)

eqs = 
"
dxdt = fx
dydt = fy
dzdt = fz
"
addVariable!(MODEL_BASIC,[:x,:y,:z],eqs)

#Compile
precompile!(MODEL_BASIC,platform="cpu",integrator="euler",saveRAM=true)
MODEL_BASIC_GPU = deepcopy(MODEL_BASIC)
precompile!(MODEL_BASIC_GPU,platform="gpu",integrator="euler",saveRAM=true)
