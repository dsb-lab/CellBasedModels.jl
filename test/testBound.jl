@testset "bound" begin

    for platform in testplatforms

        #By local update
        m = @agent(
            cell,

            [x,y,z]::Local,
            [sx,sy,sz]::Local, #Steps

            [s,sMin,sMax]::Local, #Stop bounds 
            [b,bMin,bMax]::Local, #Bounce bounds 
            [r,rMin,rMax]::Local, #Hard bounds 

            UpdateLocal = begin
                x += sx
                y += sy
                z += sz
            end
        )
        space = SimulationFree(
            [
                Bound(:x,-1,1,
                    stop=[:s],stopMin=[:sMin],stopMax=[:sMax],
                    bounce=[:b],bounceMin=[:bMin],bounceMax=[:bMax],
                    reflect=[:r],reflectMin=[:rMin],reflectMax=[:rMax]
                ),
                Bound(:y,-1,1,
                    stop=[:s],stopMin=[:sMin],stopMax=[:sMax],
                    bounce=[:b],bounceMin=[:bMin],bounceMax=[:bMax],
                    reflect=[:r],reflectMin=[:rMin],reflectMax=[:rMax]
                ),
                Bound(:z,-1,1,
                    stop=[:s],stopMin=[:sMin],stopMax=[:sMax],
                    bounce=[:b],bounceMin=[:bMin],bounceMax=[:bMax],
                    reflect=[:r],reflectMin=[:rMin],reflectMax=[:rMax]
                )
            ]
        )
        model = compile(m,space,platform=platform)
        #println(prettify(model.program))
        com = Community(model,N=6)
        com.x .= [-.9,.9,0,0,0,0]
        com.y .= [0,0,-.9,.9,0,0]
        com.z .= [0,0,0,0,-.9,.9]

        com.sx .= [-.2,.2,0,0,0,0]
        com.sy .= [0,0,-.2,.2,0,0]
        com.sz .= [0,0,0,0,-.2,.2]

        com.s .= [-1.2,1.2,-1.2,1.2,-1.2,1.2]
        com.sMin .= [-1.2,1.2,-1.2,1.2,-1.2,1.2]
        com.sMax .= [-1.2,1.2,-1.2,1.2,-1.2,1.2]

        com.b .= [-1.2,1.2,-1.2,1.2,-1.2,1.2]
        com.bMin .= [-1.2,1.2,-1.2,1.2,-1.2,1.2]
        com.bMax .= [-1.2,1.2,-1.2,1.2,-1.2,1.2]

        com.r .= 1
        com.rMin .= 1
        com.rMax .= 1        

        comt = model.evolve(com,dt=1,tMax=1.1)

        @test all(abs.(comt[end].s .- [-1.,1.,-1.,1.,-1.,1.]) .< 0.0001)
        @test all(abs.(comt[end].sMin .- [-1.,1.2,-1.,1.2,-1.,1.2]) .< 0.0001)
        @test all(abs.(comt[end].sMax .- [-1.2,1.,-1.2,1.,-1.2,1.]) .< 0.0001)

        @test all(abs.(comt[end].b .- [-.8,.8,-.8,.8,-.8,.8]) .< 0.0001)
        @test all(abs.(comt[end].bMin .- [-.8,1.2,-.8,1.2,-.8,1.2]) .< 0.0001)
        @test all(abs.(comt[end].bMax .- [-1.2,.8,-1.2,.8,-1.2,.8]) .< 0.0001)

        @test all(abs.(comt[end].r .- [-1,-1,-1,-1,-1,-1]) .< 0.0001)
        @test all(abs.(comt[end].rMin .- [-1,1,-1,1,-1,1]) .< 0.0001)
        @test all(abs.(comt[end].rMax .- [1,-1,1,-1,1,-1]) .< 0.0001)


        m = @agent(
            cell,

            [x,y,z]::Local,
            [x1,y1,z1]::Local,
            [sx,sy,sz]::Local, #Steps


            UpdateLocal = begin
                x += sx
                y += sy
                z += sz
            end
        )
        space = SimulationFree(
            [
                Periodic(:x,-1,1,additional=[:x1]),
                Periodic(:y,-1,1,additional=[:y1]),
                Periodic(:z,-1,1,additional=[:z1])
            ]
        )
        model = compile(m,space,platform=platform)
        #println(prettify(model.program))

        com = Community(model,N=6)
        com.x .= [-.9,.9,0,0,0,0]
        com.y .= [0,0,-.9,.9,0,0]
        com.z .= [0,0,0,0,-.9,.9]

        com.sx .= [-.2,.2,0,0,0,0]
        com.sy .= [0,0,-.2,.2,0,0]
        com.sz .= [0,0,0,0,-.2,.2]

        com.x1 .= [-.9,.9,0,0,0,0]
        com.y1 .= [0,0,-.9,.9,0,0]
        com.z1 .= [0,0,0,0,-.9,.9]

        comt = model.evolve(com,dt=1,tMax=1.1)

        @test all(abs.(comt[end].x .- [.9,-.9,0,0,0,0]) .< 0.0001)
        @test all(abs.(comt[end].y .- [0,0,.9,-.9,0,0]) .< 0.0001)
        @test all(abs.(comt[end].z .- [0,0,0,0,.9,-.9]) .< 0.0001)

        @test all(abs.(comt[end].x1 .- [1.1,-1.1,0,0,0,0]) .< 0.0001)
        @test all(abs.(comt[end].y1 .- [0,0,1.1,-1.1,0,0]) .< 0.0001)
        @test all(abs.(comt[end].z1 .- [0,0,0,0,1.1,-1.1]) .< 0.0001)






        #Integration
        m = @agent(
            cell,

            [x,y,z]::Local,
            [sx,sy,sz]::Local, #Steps

            [s,sMin,sMax]::Local, #Stop bounds 
            [b,bMin,bMax]::Local, #Bounce bounds 
            [r,rMin,rMax]::Local, #Hard bounds 

            Equation = begin
                d_x = sx*dt
                d_y = sy*dt
                d_z = sz*dt
            end
        )
        space = SimulationFree(
            [
                Bound(:x,-1,1,
                    stop=[:s],stopMin=[:sMin],stopMax=[:sMax],
                    bounce=[:b],bounceMin=[:bMin],bounceMax=[:bMax],
                    reflect=[:r],reflectMin=[:rMin],reflectMax=[:rMax]
                ),
                Bound(:y,-1,1,
                    stop=[:s],stopMin=[:sMin],stopMax=[:sMax],
                    bounce=[:b],bounceMin=[:bMin],bounceMax=[:bMax],
                    reflect=[:r],reflectMin=[:rMin],reflectMax=[:rMax]
                ),
                Bound(:z,-1,1,
                    stop=[:s],stopMin=[:sMin],stopMax=[:sMax],
                    bounce=[:b],bounceMin=[:bMin],bounceMax=[:bMax],
                    reflect=[:r],reflectMin=[:rMin],reflectMax=[:rMax]
                )
            ]
        )
        model = compile(m,space,platform=platform)
        #println(prettify(model.program))

        com = Community(model,N=6)
        com.x .= [-.9,.9,0,0,0,0]
        com.y .= [0,0,-.9,.9,0,0]
        com.z .= [0,0,0,0,-.9,.9]

        com.sx .= [-.2,.2,0,0,0,0]
        com.sy .= [0,0,-.2,.2,0,0]
        com.sz .= [0,0,0,0,-.2,.2]

        com.s .= [-1.2,1.2,-1.2,1.2,-1.2,1.2]
        com.sMin .= [-1.2,1.2,-1.2,1.2,-1.2,1.2]
        com.sMax .= [-1.2,1.2,-1.2,1.2,-1.2,1.2]

        com.b .= [-1.2,1.2,-1.2,1.2,-1.2,1.2]
        com.bMin .= [-1.2,1.2,-1.2,1.2,-1.2,1.2]
        com.bMax .= [-1.2,1.2,-1.2,1.2,-1.2,1.2]

        com.r .= 1
        com.rMin .= 1
        com.rMax .= 1        

        comt = model.evolve(com,dt=1,tMax=1.1)

        @test all(abs.(comt[end].s .- [-1.,1.,-1.,1.,-1.,1.]) .< 0.0001)
        @test all(abs.(comt[end].sMin .- [-1.,1.2,-1.,1.2,-1.,1.2]) .< 0.0001)
        @test all(abs.(comt[end].sMax .- [-1.2,1.,-1.2,1.,-1.2,1.]) .< 0.0001)

        @test all(abs.(comt[end].b .- [-.8,.8,-.8,.8,-.8,.8]) .< 0.0001)
        @test all(abs.(comt[end].bMin .- [-.8,1.2,-.8,1.2,-.8,1.2]) .< 0.0001)
        @test all(abs.(comt[end].bMax .- [-1.2,.8,-1.2,.8,-1.2,.8]) .< 0.0001)

        @test all(abs.(comt[end].r .- [-1,-1,-1,-1,-1,-1]) .< 0.0001)
        @test all(abs.(comt[end].rMin .- [-1,1,-1,1,-1,1]) .< 0.0001)
        @test all(abs.(comt[end].rMax .- [1,-1,1,-1,1,-1]) .< 0.0001)


        m = @agent(
            cell,

            [x,y,z]::Local,
            [x1,y1,z1]::Local,
            [sx,sy,sz]::Local, #Steps


            Equation = begin
                d_x = sx*dt
                d_y = sy*dt
                d_z = sz*dt
            end
        )
        space = SimulationFree(
            [
                Periodic(:x,-1,1,additional=[:x1]),
                Periodic(:y,-1,1,additional=[:y1]),
                Periodic(:z,-1,1,additional=[:z1])
            ]
        )
        model = compile(m,space,platform=platform)
        #println(prettify(model.program))

        com = Community(model,N=6)
        com.x .= [-.9,.9,0,0,0,0]
        com.y .= [0,0,-.9,.9,0,0]
        com.z .= [0,0,0,0,-.9,.9]

        com.sx .= [-.2,.2,0,0,0,0]
        com.sy .= [0,0,-.2,.2,0,0]
        com.sz .= [0,0,0,0,-.2,.2]

        com.x1 .= [-.9,.9,0,0,0,0]
        com.y1 .= [0,0,-.9,.9,0,0]
        com.z1 .= [0,0,0,0,-.9,.9]

        comt = model.evolve(com,dt=1,tMax=1.1)

        @test all(abs.(comt[end].x .- [.9,-.9,0,0,0,0]) .< 0.0001)
        @test all(abs.(comt[end].y .- [0,0,.9,-.9,0,0]) .< 0.0001)
        @test all(abs.(comt[end].z .- [0,0,0,0,.9,-.9]) .< 0.0001)

        @test all(abs.(comt[end].x1 .- [1.1,-1.1,0,0,0,0]) .< 0.0001)
        @test all(abs.(comt[end].y1 .- [0,0,1.1,-1.1,0,0]) .< 0.0001)
        @test all(abs.(comt[end].z1 .- [0,0,0,0,1.1,-1.1]) .< 0.0001)

    end

end