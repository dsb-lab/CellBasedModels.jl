"""
    function plotRods2D!(ax, x, y, d, l, angle; kargs...)
    
Plot rod shape like cells using Makie functions.

||Parameter|Description|
|:---|:---|:---|
|Args| ax | Axis where to plot the rods |
||x| Coordinates of rods in x |
||y| Coordinates of rods in y |
||d| Diameter of the rod |
||l| Length of the rods |
||angle| Angle of the rods of rods in the XY plane |
|KwArgs| | All arguments that want to be passed to meshscatter! function as color etc... |

    function plotRods2D!(ax, x, y, xs1, ys1, xs2, ys2, markerSphere, markerCylinder, angle; kargs...)
    
Plot rod shape like cells using Makie functions. This method is useful to make videos of cells.
    
||Parameter|Description|
|:---|:---|:---|
|Args| ax | Axis where to plot the rods |
||x| Coordinates of center of rod in x |
||y| Coordinates of center of rod in y |
||xs1| Coordinates of rod extreme in x |
||ys1| Coordinates of rod extreme in y |
||xs2| Coordinates of other rod extreme in x |
||ys2| Coordinates of other rod extreme in y |
||markerSphere| Point3f0 describing the radius of the sphere in (x,y,z)  |
||markerCylinder| Point3f0 describing the cylinder sizes in (l,rx,ry) |
|KwArgs| | All arguments that want to be passed to meshscatter! function as color etc... |
    
"""
function plotRods2D!(ax, x, y, d, l, angle; kargs...)

    Main.meshscatter!(ax,
                x.+l./2 .*cos.(angle),
                y.+l./2 .*sin.(angle),
                marker=GeometryBasics.Sphere(Point3f0(0,0,0.),Float32(1)),
                markersize=[
                    Point3f0(i/2,i/2,0)
                    for i in d
                ],
                kargs...
            )

    Main.meshscatter!(ax,
                x.-l./2 .*cos.(angle),
                y.-l./2 .*sin.(angle),
                marker=GeometryBasics.Sphere(Point3f0(0,0,0),Float32(1)),
                markersize=[
                    Point3f0(i/2,i/2,0)
                    for i in d
                ],
                kargs...
            )
            
    Main.meshscatter!(ax,
                x,
                y,
                marker=GeometryBasics.Cylinder(Point3f0(-.5,0,0),Point3f0(.5,0,0),Float32(1)),
                markersize=[Point3f0(ll,dd/2,dd/2) for (ll,dd) in zip(l,d)],
                rotations=angle,
                kargs...
            )

    return

end

function plotRods2D!(ax, x, y, xs1, ys1, xs2, ys2, markerSphere, markerCylinder, angle; kargs...)

    m = meshscatter!(ax,
                xs1,
                ys1,
                marker=GeometryBasics.Sphere(Point3f0(0,0,0.),Float32(1)),
                markersize=markerSphere;
                kargs...
            )

    Main.meshscatter!(ax,
                xs2,
                ys2,
                marker=GeometryBasics.Sphere(Point3f0(0,0,0),Float32(1)),
                markersize=markerSphere;
                kargs...
            )
            
    Main.meshscatter!(ax,
                x,
                y,
                marker=GeometryBasics.Cylinder(Point3f0(-.5,0,0),Point3f0(.5,0,0),Float32(1)),
                markersize=markerCylinder,
                rotations=angle;
                kargs...
            )

    return m

end