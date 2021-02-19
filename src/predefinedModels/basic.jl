MODEL_BASIC = Model()
    
inter = 
"
rrₐ = sqrt((x₁-x₂)^2+(y₁-y₂)^2+(z₁-z₂)^2) 
rₐ = rrₐ#/r
rxₐ = (x₁-x₂)/rrₐ
ryₐ = (y₁-y₂)/rrₐ
rzₐ = (z₁-z₂)/rrₐ
if rₐ < 2*r && rₐ > 0.
    fx += 2*(2*r-rₐ)*rxₐ
    fy += 2*(2*r-rₐ)*ryₐ
    fz += 2*(2*r-rₐ)*rzₐ
    nn += 1.
elseif rₐ > 2*r && rₐ < 2.4*r*(1.5/(1+t))
    fx -= 0.5*(rₐ-2*r)*rxₐ
    fy -= 0.5*(rₐ-2*r)*ryₐ
    fz -= 0.5*(rₐ-2*r)*rzₐ
    nn += 1.
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
dx = fx*dt
dy = fy*dt
dz = fz*dt
"
addVariable!(MODEL_BASIC,[:x,:y,:z],eqs)

#Compile
precompile!(MODEL_BASIC,platform="cpu",integrator="euler",saveRAM=true)
MODEL_BASIC_GPU = deepcopy(MODEL_BASIC)
precompile!(MODEL_BASIC_GPU,platform="gpu",integrator="euler",saveRAM=true)
