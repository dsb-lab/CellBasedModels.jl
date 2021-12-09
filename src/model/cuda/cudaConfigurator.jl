"""
    function configurator_(kernel)

Function to configurate the number of blocks and threads to be launched at runtime.
"""
function configurator_(kernel,N)
    config = launch_configuration(kernel.fun)

    threads = Base.min(max(N,1), config.threads)
    blocks = Base.min(cld(max(N,1), threads),config.blocks)

    return (max(1,round(Int,threads)), max(1,round(Int,blocks)))
end