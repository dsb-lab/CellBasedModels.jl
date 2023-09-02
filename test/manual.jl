using Revise
using CellBasedModels

model = ABM(2,
    model = Dict(
        :D => Float64
        ),
    agent = Dict(
        :secrete => Float64
    ),
    medium = Dict(
        :p=> Float64  #Number of neighbors that the agent has
        ),
    agentRule = quote
        p += secrete/dt*dx*dy #Add to the medium the secretion content of each neighbor at each time point
    end,
    mediumODE = quote
        if @mediumInside()
            dt(p) = @∂2(1,p)        #Diffusion inside
        elseif @mediumBorder(1,-1)
            p = p[2,i2_]                #Newman (reflective) boundaries on the borders
        elseif @mediumBorder(1,1)
            p = 0                   #Dirichlet (absorvant) boundary
        end
    end
)

Community(model, platform = CPU())

prettify(model.declaredUpdatesCode[:mediumODE])