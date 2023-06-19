softSpheres2D = ABM(2,
    
    #Parameters
    model = Dict(
        :b=>Float64,
        :μ=>Float64,
        :f0=>Array{Float64}
    ),
    agent = Dict(
        :m=>Float64,
        :r=>Float64,
        :vx=>Float64,
        :vy=>Float64,
        :fx=>Float64,
        :fy=>Float64
    ),
    
    #Mechanics
    agentODE = quote

        fx = 0; fy = 0
        @loopOverNeighbors it2 begin
            dij = sqrt((x-x[it2])^2+(y-y[it2])^2)
            rij = r+r[it2]
            if dij < μ*rij && dij > 0
                fx += f0[cellFate[i1_],cellFate[it2]]*(rij/dij-1)*(μ*rij/dij-1)*(x-x[it2])/dij
                fy += f0[cellFate[i1_],cellFate[it2]]*(rij/dij-1)*(μ*rij/dij-1)*(y-y[it2])/dij
            end
        end

        dt(vx) = -b*vx/m+fx/m
        dt(vy) = -b*vy/m+fy/m
        dt(x) = vx
        dt(y) = vy
    end,

    compile=false
)

softSpheres3D = ABM(3,
    
        #Parameters
        model = Dict(
            :b=>Float64,
            :μ=>Float64,
            :f0=>Array{Float64}
        ),
        agent = Dict(
            :m=>Float64,
            :r=>Float64,
            :vx=>Float64,
            :vy=>Float64,
            :vz=>Float64,
            :fx=>Float64,
            :fy=>Float64,
            :fz=>Float64,
        ),
        
        #Mechanics
        agentODE = quote
    
            fx = 0; fy = 0; fz = 0
            @loopOverNeighbors it2 begin
                dij = sqrt((x-x[it2])^2+(y-y[it2])^2+(z-z[it2])^2)
                rij = r+r[it2]
                if dij < μ*rij && dij > 0
                    fx += f0[cellFate[i1_],cellFate[it2]]*(rij/dij-1)*(μ*rij/dij-1)*(x-x[it2])/dij
                    fy += f0[cellFate[i1_],cellFate[it2]]*(rij/dij-1)*(μ*rij/dij-1)*(y-y[it2])/dij
                    fz += f0[cellFate[i1_],cellFate[it2]]*(rij/dij-1)*(μ*rij/dij-1)*(z-z[it2])/dij
                end
            end
    
            dt(vx) = -b*vx/m+fx/m
            dt(vy) = -b*vy/m+fy/m
            dt(vz) = -b*vz/m+fz/m
            dt(x) = vx
            dt(y) = vy
            dt(z) = vz
        end,

        compile=false
    );