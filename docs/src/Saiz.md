# [Embryogenesis example: Saiz et al 2021](@id saiz)

It can be also seen in the corresponding [Jupyter notebook](https://github.com/dsb-lab/AgentBasedModels.jl/blob/master/examples/Saiz_2020.ipynb)

## Model

The model from Saiz et al has three parts in the model

### Mechanics

The cells are spheroids that behave under the following equations:

```math
\begin{aligned}
m_i\frac{dv_i}{dt} &=-bv_i+\sum_j F_{ij}
\frac{dx_i}{dt} &=v_i
\end{aligned}
```

where the force is

```math
F_{ij}=
\begin{cases}
F_0(\frac{r_{ij}}{d_{ij}}-1)(\frac{\mu r_{ij}}{d_{ij}}-1)\frac{(x_i-x_j)}{d_{ij}}\hspace{1cm}if\;d_{ij}<\mu r_{ij}\\
0\hspace{5cm}otherwise
\end{cases}
```
where ``d_{ij}`` is the Euclidean distance and ``r_{ij}`` is the sum of both radius.

### Biochemical interaction

Each cell has a biochemical component that follows an equation of the form:

```math
\frac{dx_i}{dt}=\frac{α(1+x^n_i)^m}{(1+x^n_i)^m+(1+(\langle x\rangle_i)/K)^{2m}}-x_i
```

This is similar to the above case. The only detail required is to note that the average expression can be modeled as the combination of two interacting variables. The biochemical system is activated in the interval ``[t_{on},t_{off}]``.

We made explicit that the average operator can be written as two interaction parameters that are the contraction along the second index that runs over the neighbours of each cell as,

```math
N_{ij}=
\begin{cases}
1\hspace{1cm}d<f_{range}r_{ij}\\
0\hspace{1cm}otherwise
\end{cases}
```

```math
X_{ij}=
\begin{cases}
x_j\hspace{1cm}d<f_{range}r_{ij}\\
0\hspace{1cm}otherwise
\end{cases}
```

```math
\langle x\rangle_i=\frac{\sum_j X_{ij}}{\sum_j N_{ij}}=\frac{X_{i}}{N_{i}}
```

### Growth

The cells present division. The rules for the division in this model are. Random election of a division direction over the unit sphere. The daughter cells divide equally in mass and volume and are positioned in oposite directions around the division axis centered at the parent cell. The chemical concentration is divided asymmetrically with each cell taking ``1\pm\sigma_x \text{Uniform}(0,1)`` for the parent cell. A new division time is assigned to each aghter cell from a uniform distribution ``\text{Uniform}(\tau_{div}(1-\sigma_{div}),\tau_{div}(1+\sigma_{div}))``.

## Creating the agent

```julia
m = @agent(saiz,
    
    #Mechanics
    
    [x,y,z,vx,vy,vz]::Local, #Variables
    [Fix,Fiy,Fiz]::Local,    #Interaction forces
    id::Identity,            #Identity
    [m,r]::Local,            #Mass and radius of the model
    [μ,b]::Global,           #Global parameters of the model
    F₀::GlobalArray,         #Matrix of interaction forces
    
    Equation = begin
        d_vx = (-b*vx/m+Fix/m)*dt
        d_vy = (-b*vy/m+Fiy/m)*dt
        d_vz = (-b*vz/m+Fiz/m)*dt
        d_x = vx*dt
        d_y = vy*dt
        d_z = vz*dt
    end,
    
    UpdateInteraction = begin
        dij = sqrt((dx_i-dx_j)^2+(dy_i-dy_j)^2+(dz_i-dz_j)^2)
        rij = r_i+r_j
        if dij < μ*rij && dij > 0
            Fix_i += F₀[id_i,id_j]*(rij/dij-1)*(μ*rij/dij-1)*(x_i-x_j)/dij
            Fiy_i += F₀[id_i,id_j]*(rij/dij-1)*(μ*rij/dij-1)*(y_i-y_j)/dij
            Fiz_i += F₀[id_i,id_j]*(rij/dij-1)*(μ*rij/dij-1)*(z_i-z_j)/dij   
        end
    end,
    
    #Biochemistry
    
    c::Local,             #Biochemical component
    [ci,ni]::Local,       #Interaction parameters for the mean
    [α,n,mm,K]::Global,
    frange::Global,       #Distance of communication
    [toff,tonn]::Global,
    
    Equation = begin
        if t < toff && t > ton
            d_c = (α*(1+c^n)^mm/((1+c^n)^mm+(1+(ci/ni)/K)^(2*mm))-c)*dt
        else
            d_c = 0*dt
        end
    end,
        
    UpdateInteraction= begin
        if dij < frange*rij #Unnecessary to compute dij and rij again, previously computed in UpdateInteraction
            ni += 1
            ci += c_j
        end 
    end,
    
    #Growth
    
    tu::Local,
    [τdiv,σdiv,σc]::Global,

    EventDivision = begin
        #Choose random direction in unit sphere
        xₐ = Normal(0,1); yₐ = Normal(0,1); zₐ = Normal(0,1)
        Tₐ = sqrt(xₐ^2+yₐ^2+zₐ^2)
        xₐ /= Tₐ;yₐ /= Tₐ;zₐ /= Tₐ    

        #Chose a random distribution
        dist = Uniform(1+σc1,1-σc)

        #Update things of first cell
        x_1 = x+r*xₐ/2; y_1 = y+r*yₐ/2; z_1 = z+r*zₐ/2
        vx_1 = 0.; vy_1 = 0.; vz_1 = 0.
        r_1 = r/2. ^(1. /3)
        m_1 = m/2
        tu_1 = t + Uniform(τdiv-σdiv,τdiv+σdiv)
        c_1 = c*dist
        
        #Update things of second cell
        x_2 = x+r*xₐ/2; y_2 = y+r*yₐ/2; z_2 = z+r*zₐ/2
        vx_2 = 0.; vy_2 = 0.; vz_2 = 0.
        r_2 = r/2. ^(1. /3)
        m_2 = m/2
        tu_2 = t + Uniform(τdiv-σdiv,τdiv+σdiv)
        c_2 = c*(2-dist)
    end,
)
```