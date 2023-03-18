struct Neighbors
    additionArguments::DataFrame
    loopFunction::Function
    neighborsCompute::Function
end

"""
    mutable struct Platform

Containd the `threads` and `blocks` to be executed when executing cuda kernels.
"""
mutable struct Platform
    threads::Int
    blocks::Int
end

"""
    struct BaseParameter

Object containing the information of each field of the Community object that is fent to the different stepping functions as they appear in BASEPARAMETERS.

|Field|Description|
|:---|:---|
| dtype::Symbol | Type specifying between :Int and :Float dtype. |
| shape::Tuple | Shape of the field. The dimensions can be (:Local,:Global,:Neighbors (number of neighbors), :Dims (0,1,2,3), :Cells or :Medium). |
| saveLevel::Int | Level specifying this variable at which level should be saved. |
| origin::Symbol | Origin of the parameter. |
| reassign::Bool | If to reupdate afte addign or removing agents of the Community. |
| protected::Bool | If protected, you cannot access it directly with Community.parameter or Community[:parameter] |
| reset::Bool | If reset, this parameters will be set to zero before each interactionStep!. |
| necessaryFor::Vector{Symbol} | When declaring Community, if necessary this parameters will be asked if not declared. |
| initialize | Initialize function that creates the parameter if not specified explicitely during Community. |
"""
struct BaseParameter
    dtype::Symbol
    shape::Tuple
    saveLevel::Int
    origin::Symbol
    reassign::Bool
    protected::Bool
    reset::Bool
    necessaryFor::Vector{Symbol}
    initialize
end

"""
    struct BaseSymbol

Structure that contains the operators symbols and types of special symbols in the code.
"""
struct BaseSymbol
    symbol::Symbol
    type::Symbol
end

"""
    mutable struct UserParameter

Structure that contains the properties of each of the user declared parameters.

|Field|Description|
|:---|:---|
| dtype::DataType | Type of data |
| scope::Symbol | If :agent, :model or :medium parameter |
| update::Bool | If the variable is updated |
| variable::Bool | Whether if this parameter is described with a Differential Equation |
| variableMedium::Bool | Whether if this parameter is described with a PDE |
| pos::Int | Position that ocupies at the integration matrix |
"""
mutable struct UserParameter
    dtype::DataType
    scope::Symbol
    update::Bool
    variable::Bool
    variableMedium::Bool
    pos::Int

    function UserParameter(dataType,scope)
        return new(dataType,scope,false,false,false,0)
    end
end

"""
    mutable struct Equation

Structure containing the informatiojn of each equation declared in the model.

|Field|Description|
|:---|:---|
| position::Int | Position of the equation for the variable in BASEPARAMETERS |
| positiondt::Int | Position of the dt part of the ODE equation |
| positiondW::Int | Position of the dW part in the SDE equation |
| deterministic::Union{Expr,Symbol,Number} | Code of the ODE part |
| stochastic::Union{Expr,Symbol,Number} | Code of the SDE part |
"""
mutable struct Equation
    position::Int
    positiondt::Int
    positiondW::Int
    deterministic::Union{Expr,Symbol,Number}
    stochastic::Union{Expr,Symbol,Number}
end

"""EquationMedium
    mutable struct EquationMedium

Structure containing the informatiojn of each equation declared in the model.

|Field|Description|
|:---|:---|
| position::Int | Position of the equation for the variable in BASEPARAMETERS |
| advection::Array{Union{Symbol,Expr,Number}} | Code of the advection equation part |
| difussion::Array{Union{Symbol,Expr,Number}} | Code of the diffusion equation part |
| reaction::Array{Union{Symbol,Expr,Number}} | Code of the reaction equation part |
| delta::Array{Union{Symbol,Expr,Number}} | Code of the delta equation part |
| fromAgents::Array{Union{Symbol,Expr,Number}} | Code for the agents part equation part |
"""
mutable struct EquationMedium
    position::Int
    advectionX::Array{Union{Symbol,Expr,Number}}
    advectionY::Array{Union{Symbol,Expr,Number}}
    advectionZ::Array{Union{Symbol,Expr,Number}}
    difussionXX::Array{Union{Symbol,Expr,Number}}
    difussionYY::Array{Union{Symbol,Expr,Number}}
    difussionZZ::Array{Union{Symbol,Expr,Number}}
    reaction::Array{Union{Symbol,Expr,Number}}
    fromAgents::Array{Union{Symbol,Expr,Number}}
end

"""
    struct Integrator

Structure containin the information of the integration method.

|Field|Description|
|:---|:---|
| length | Number of intermediate steps (e.g. RungeKutta4 has 4 steps) |
| stochasticImplemented | If this integrator is valid for SDE integration. |
| weight | Weight of each step in the integration in the form of a Butcher table of ((weights step 1), (weigths step 2)...) |
"""
struct Integrator
    length
    stochasticImplemented
    weight
end

"""
    struct IntegratorMedium

Structure containin the information of the integration medium method.

|Field|Description|
|:---|:---|
| advection | Advection spatial integration steps. |
| difusion | Difussion spatial integration steps. |
| reaction | Reaction spatial integration steps. |
"""
struct IntegratorMedium
    advection
    difussion
    reaction
end