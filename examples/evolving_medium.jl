using CellBasedModels
using CairoMakie

agent = ABM(
    2,

    model = Dict(
        :r => Float32,
        :speed => Float32
    ),

    medium = Dict(
        :f => Float32
    ),

    # This ODE will increase the radius of the medium over time
    modelODE = quote
        
        dt(r) = speed

    end,

    # This will generate the field instantly at each time step
    mediumODE = quote

        f = tanh((xₘ^2 + yₘ^2)/r) + 0.5

    end
)

community = Community(agent, N=0, dt=0.1, NMedium=[100,100], simBox=[-5.0 5.0;-5.0 5.0])
community.r = 1.0
community.speed = 5.0

evolve!(community, steps = 10)

fig = Figure(resolution = (800, 400))

for i in 1:3

    ax1 = Axis(fig[1, i], title = "Medium field f", xlabel = "x", ylabel = "y")

    heatmap!(
        ax1,
        community[i].f;
        colormap = :viridis,
        colorrange = (0, 1),
    )

end

display(fig)
