MODEL_BASIC = Model()
    
inter = 
"
rrₐ = sqrt((x₁-x₂)^2+(y₁-y₂)^2+(z₁-z₂)^2) 
rₐ = rrₐ#/r
rxₐ = (x₁-x₂)/rrₐ
ryₐ = (y₁-y₂)/rrₐ
rzₐ = (z₁-z₂)/rrₐ
if rₐ < 0.7*r && rₐ > 0.
    fx += 2*(0.7*r-rₐ)*rxₐ
    fy += 2*(0.7*r-rₐ)*ryₐ
    fz += 2*(0.7*r-rₐ)*rzₐ
    nn += 1.
elseif rₐ > 0.8 && rₐ < 1.
    fx -= 0.5*(rₐ-0.8*r)*rxₐ
    fy -= 0.5*(rₐ-0.8*r)*ryₐ
    fz -= 0.5*(rₐ-0.8*r)*rzₐ
    nn += 1.
elseif rₐ > 1*r && rₐ < (1+2*n)*r && nn < 1.
    fx -= 0.1*r*rxₐ
    fy -= 0.1*r*ryₐ
    fz -= 0.1*r*rzₐ
end
"
addInteraction!(MODEL_BASIC,[:fx,:fy,:fz,:nn],inter)

update = 
"
D = 0. /(t+1)
"
addGlobal!(MODEL_BASIC,[:D,:r,:n],updates=update)

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
