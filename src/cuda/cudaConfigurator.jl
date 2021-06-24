"""
    function configurator_(kernel)

Function to configurate the number of blocks and threads to be launched at runtime.
"""
function configurator_(kernel,N)
    config = launch_configuration(kernel.fun)

    threads = Base.min(N, config.threads)
    blocks = cld(N, threads)

    return (threads, blocks)
end