MODEL_BASIC = Model()
    
inter = 
"
rrₐ = sqrt((x₁-x₂)^2+(y₁-y₂)^2+(z₁-z₂)^2) 
rₐ = rrₐ#/r
rxₐ = (x₁-x₂)/rrₐ
ryₐ = (y₁-y₂)/rrₐ
rzₐ = (z₁-z₂)/rrₐ
if rₐ < r && rₐ > 0.
    fx += 2*(r-rₐ)*rxₐ
    fy += 2*(r-rₐ)*ryₐ
    fz += 2*(r-rₐ)*rzₐ
    nn += 1.
elseif rₐ > 1 && rₐ < 1.2
    fx -= 0.5*(rₐ-r)*rxₐ
    fy -= 0.5*(rₐ-r)*ryₐ
    fz -= 0.5*(rₐ-r)*rzₐ
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
dx = fx*dt
dy = fy*dt
dz = fz*dt
"
addVariable!(MODEL_BASIC,[:x,:y,:z],eqs)

#Compile
precompile!(MODEL_BASIC,platform="cpu",integrator="euler",saveRAM=true)
MODEL_BASIC_GPU = deepcopy(MODEL_BASIC)
precompile!(MODEL_BASIC_GPU,platform="gpu",integrator="euler",saveRAM=true)
