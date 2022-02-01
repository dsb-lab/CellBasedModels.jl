"""
    function configurator_(kernel,N)

Function to configurate the number of blocks and threads to be launched at runtime.
"""
function configurator_(kernel,N)
    config = launch_configuration(kernel.fun)

    threads = Base.min(max(N,1), config.threads)
    blocks = Base.min(cld(max(N,1), threads),config.blocks)

    return (max(1,round(Int,threads)), max(1,round(Int,blocks)))
end

"""
    function configurator1_(kernel,Nx,Ny)

Function to configurate the number of blocks and threads to be launched at runtime.
"""
function configurator2_(kernel,Nx)
    config = launch_configuration(kernel.fun)

    threadsX = Base.min(Nx,config.threads)
    blocksX = Base.min(cld(Nx,threadsX),config.blocks)

    return (threadsX,blocksX)
end

"""
    function configurator2_(kernel,Nx,Ny)

Function to configurate the number of blocks and threads to be launched at runtime.
"""
function configurator2_(kernel,Nx,Ny)
    config = launch_configuration(kernel.fun)

    threadsX = Base.min(Nx,config.threads)
    threadsY = Base.min(Ny,div(config.threads,threadsX))
    blocksX = Base.min(cld(Nx,threadsX),config.blocks)
    blocksY = Base.min(cld(Ny,threadsY),div(config.blocks,blocksX))

    return (threadsX,threadsY,blocksX,blocksY)
end

"""
    function configurator3_(kernel,Nx,Ny)

Function to configurate the number of blocks and threads to be launched at runtime.
"""
function configurator3_(kernel,Nx,Ny,Nz)
    config = launch_configuration(kernel.fun)

    threadsX = Base.min(Nx,config.threads)
    threadsY = Base.max(Base.min(Ny,div(config.threads,threadsX)),1)
    threadsZ = Base.max(Base.min(Ny,div(config.threads,threadsX*threadsY)),1)
    blocksX = Base.min(cld(Nx,threadsX),config.blocks)
    blocksY = Base.max(Base.min(cld(Ny,threadsY),div(config.blocks,blocksX)),1)
    blocksZ = Base.max(Base.min(cld(Ny,threadsY),div(config.blocks,blocksX*blocksY)),1)

    return (threadsX,threadsY,threadsZ,blocksX,blocksY,blocksZ)
end