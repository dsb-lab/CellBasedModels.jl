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
    mutable struct UserParameter

Structure that contains the properties of each of the user declared parameters.

|Field|Description|
|:---|:---|
| dtype::DataType | Type of data |
| scope::Symbol | If :agent, :model or :medium parameter |
| subscope::Symbol | Which type of agent, model or medium this parameter corresponds to |
| update::Bool | If the variable is updated |
| variable::Bool | Whether if this parameter is described with a Differential Equation |
| pos::Int | Position that ocupies at the integration matrix |
"""
mutable struct UserParameter
    dtype
    scope::Symbol
    subscope::Symbol
    update::Bool
    variable::Bool
    pos::Int
    primitive::Union{Nothing,Symbol}
    isId::Bool

    function UserParameter(name, dataType, scope, subscope=:Main; update=false, variable=false, pos=0, primitive=nothing, isId=false)
        if scope in [:medium] && !(dataType <: Number)
            error("Parameters of medium must be of type Number. $name is defined with type $dataType.")
        else
            return new(dataType,scope,subscope,update,variable,pos,primitive,isId)
        end
    end
end

"""
    mutable struct SavingFile

Structure that stores the information of files used for saving Community information.
"""
mutable struct SavingFile

    uuid
    file

end

"""
    mutable struct ValueUnits
Object containing a value and its units.

    Parameters
    ----------

|Field|Description|
|:---|:---|
| value::Any | Value of the parameter. |
| units::Union{Nothing, Symbol, Expr} | Units of the parameter. |

    Constructors
    ------------

ValueUnits(value::Any, units::Union{Nothing, Symbol, Expr}=nothing)

    Examples
    --------

```julia
    vu = ValueUnits(42, :m) # Value with units
    vu = ValueUnits(42, :(m/s^2)) # Value with complex units
    vu = ValueUnits(42) # Value without units
```
"""
mutable struct ValueUnits
    value::Any
    units::Union{Nothing, Symbol, Expr}

    function ValueUnits(value::Any, units::Union{Nothing, Symbol, Expr}=nothing)
        new(value, units)
    end
end

function Base.show(io::IO, x::ValueUnits)

    if x.value === nothing && x.units === nothing
        print(io, nothing)
    elseif x.value === nothing && x.units !== nothing
        print(io, "nothing $(x.units)")
    elseif x.value !== nothing && x.units === nothing
        print(io, x.value)
    else
        print(io, "$(x.value) $(x.units)")  
    end

end

"""
    mutable struct Parameter
Object containing the information of each parameter of an Agent.

    Parameters
    ----------

|Field|Description|
|:---|:---|
| name::Symbol | Name of the parameter. |
| dataType::DataType | Type of data. |
| dimensions::Union{Nothing, Symbol, Expr} = nothing | Dimensions of the parameter, if applicable. |
| defaultValue::Union{ValueUnits, Number, Nothing} = nothing | Default value of the parameter. |
| description::String = "" | Description of the parameter. |

    Constructors
    ------------

Parameter(name::Symbol, dataType::DataType; dimensions=nothing, defaultValue=ValueUnits(nothing, nothing), description::String="")

    Examples
    --------

```julia
    p = Parameter(:velocity, Float64) # Minimum definition
    p = Parameter(:velocity, Float64, dimensions=:(L/T)) # Minimum definition
    p = Parameter(:velocity, Float64, defaultValue=12.0, description="Velocity of the agent")
    p = Parameter(:velocity, Float64, dimensions=:(L/T), defaultValue=ValueUnits(12.0, :(m/s)), description="Velocity of the agent")
```
"""
mutable struct Parameter
    dataType::DataType
    dimensions::Union{Nothing, Symbol, Expr}
    defaultValue::ValueUnits
    description::String

    function Parameter(dataType::DataType;
                       dimensions::Union{Nothing, Symbol, Expr}=nothing,
                       defaultValue::Union{ValueUnits, Number, Nothing}=nothing,
                       description::String="")

        # Convert defaultValue to ValueUnits if needed
        if !(typeof(defaultValue) <: ValueUnits)
            defaultValue = ValueUnits(defaultValue)
        end

        # Check that the value is in the correct format
        if defaultValue.value !== nothing
            try
                defaultValue.value = dataType(defaultValue.value)
            catch e
                throw(ArgumentError("defaultValue does not match the specified dataType"))
            end
        end

        if dimensions === nothing && defaultValue.units !== nothing
            dimensions = defaultValue.units
        elseif dimensions !== nothing && defaultValue.units !== nothing
            if !compareDimensionsUnits2dimensions(defaultValue.units, dimensions)
                throw(ArgumentError("The dimensions of the parameter do not match the default value's dimensions. Expected: $dimensions, Given: $(defaultValue.units)"))
            end
        end

        new(dataType, dimensions, defaultValue, description)
    end
end

function Base.show(io::IO, x::Parameter)
    println("Parameter: ")
    println("\t DataType: ", x.dataType)
    println("\t Dimensions: ", x.dimensions)
    println("\t Default Value: ", x.defaultValue)
    println("\t Description: ", x.description)
end

"""
    function parameter_convert(parameters::Union{
                OrderedDict{Symbol,DataType}, 
                Dict{Symbol,DataType}, 
                Vector{Parameter}, 
                NamedTuple,
            })

    Converts various parameter formats into a NamedTuple of Parameters.

    Parameters
    ----------
|Field|Description|
|:---|:---|
| parameters::Union{OrderedDict{Symbol,DataType}, Dict{Symbol,DataType}, Vector{Parameter}, NamedTuple} | Input parameters in various formats. |

    Returns
    -------
|Field|Description|
|:---|:---|
| NamedTuple{Symbol, Parameter} | A NamedTuple where each key is a parameter name and each value is a Parameter object. |

    Examples
    --------    
```julia
    parameters = OrderedDict(:mass => Float64, :alive => Bool)
    namedtuple_params = parameter_convert(parameters)
```
"""
function parameter_convert(parameters)

    keys_tuple = Tuple(keys(parameters))
    l = []
    for i in keys_tuple
        if typeof(parameters[i]) <: Parameter
            push!(l, parameters[i])
        elseif typeof(parameters[i]) <: DataType
            push!(l, Parameter(parameters[i]))
        else
            error("Parameters must be of type Parameter or DataType. Given: $(typeof(parameters[i])) for parameter $i")
        end
    end
    values_tuple = Tuple(l)
    parameter_namedtuple = NamedTuple{keys_tuple}(values_tuple)

    return parameter_namedtuple
end


# """
#     struct Model

# Object containing the parameters of the Model.

#     Parameters
#     ----------

# |Field|Description|
# |:---|:---|
# | parameters::NamedTuple{Symbol, Parameter} | Named Tuple with name => Parameter. Parameter.name corresponds with key.|

#     Constructors
#     ------------

# Model(parameters::Union{
#             OrderedDict{Symbol,DataType}, 
#             Dict{Symbol,DataType}, 
#             Vector{Parameter}, 
#             NamedTuple, 
#         }=Dict())

#     Examples
#     --------

# ```julia
#     Model = Model(parameters=(mass=Float64, alive=Bool)) # Using NamedTuple
#     Model = Model(parameters=OrderedDict(:mass => Float64, :alive => Bool)) # Using OrderedDict
#     Model = Model(parameters=Dict(:mass => Float64, :alive => Bool)) # Using Dict
#     Model = Model(
#                     parameters=[
#                         Parameter(:mass, Float64, defaultValue=10.0),
#                         Parameter(:alive, Bool, defaultValue=true)
#                     ]) # Using Vector{Parameter}
# ```
# """
# struct Model
#     parameters::NamedTuple

#     function Model(; parameters::Union{
#                     OrderedDict{Symbol,DataType}, 
#                     Dict{Symbol,DataType}, 
#                     Vector{Parameter}, 
#                     NamedTuple, 
#                 }=Dict{Symbol,DataType}())

#         parameter_namedtuple = parameter_convert(parameters)

#         if :t in keys(parameter_namedtuple)
#             error("The parameter :t is reserved for the simulation time. Please choose a different name.")
#         elseif :dt in keys(parameter_namedtuple)
#             error("The parameter :dt is reserved for the time step. Please choose a different name.")
#         elseif :simBox in keys(parameter_namedtuple)
#             error("The parameter :simBox is reserved for the simulation box. Please choose a different name.")
#         end

#         pars = (
#             t=Parameter(:t, Float64, units=:T, description="Simulation time"),
#             dt=Parameter(:dt, Float64, units=:T, description="Time step for the simulation"),
#             simBox=Parameter(:simBox, Array{Float64,2}, units=:L, description="Simulation box")
#         )

#         merged_parameters = merge(pars, parameter_namedtuple)

#         new(merged_parameters)
#     end
# end

# Base.length(x::Model) = 1

# function Base.show(io::IO, x::Model)
#     println(io, @sprintf("\t%-15s %-15s %-15s %-20s %-s", "Name", "DataType", "Units", "Default_Value", "Description"))
#     println(io, "\t" * repeat("-", 85))
#     for (_, par) in pairs(x.parameters)
#         println(io, @sprintf("\t%-15s %-15s %-15s %-20s %-s", 
#             par.name, 
#             string(par.dataType), 
#             par.units,
#             par.defaultValue, 
#             par.description))
#     end
#     println(io)
# end

# """
#     struct Medium

# Object containing the parameters of a medium.

#     Parameters
#     ----------

# |Field|Description|
# |:---|:---|
# | dims::Int | Number of dimensions of the medium (1, 2, or 3). |
# | name::Symbol | Name of the medium. |
# | parameters::NamedTuple{Symbol, Parameter} | Named Tuple with name => Parameter. Parameter.name corresponds with key.|

#     Constructors
#     ------------

# Medium(dim::Int, name::Symbol=:medium; parameters::Union{
#             OrderedDict{Symbol,DataType}, 
#             Dict{Symbol,DataType}, 
#             Vector{Parameter}, 
#             NamedTuple, 
#         }=Dict())

#     Arguments
#     ---------

# |Field|Description|
# |:---|:---|
# | dim::Int | Number of dimensions of the medium (1, 2, or 3). |
# | name::Symbol | Name of the medium. Default is :medium |
# | parameters::NamedTuple{Symbol, Parameter} | Named Tuple with name => Parameter. Parameter.name corresponds with key.|

#     Examples
#     --------

# ```julia
#     medium = Medium(3, name=:medium, parameters=(mass=Float64, alive=Bool)) # Using NamedTuple
#     medium = Medium(3, name=:medium, parameters=OrderedDict(:mass => Float64, :alive => Bool)) # Using OrderedDict
#     medium = Medium(3, name=:medium, parameters=Dict(:mass => Float64, :alive => Bool)) # Using Dict
#     medium = Medium(3, name=:medium, 
#                     parameters=[
#                         Parameter(:mass, Float64, defaultValue=10.0),
#                         Parameter(:alive, Bool, defaultValue=true)
#                     ]) # Using Vector{Parameter}
# ```
# """
# struct Medium
#     name::Symbol
#     dims::Int
#     parameters::NamedTuple

#     function Medium(dim::Int; name::Symbol=:medium, parameters::Union{
#                     OrderedDict{Symbol,DataType}, 
#                     Dict{Symbol,DataType}, 
#                     Vector{Parameter}, 
#                     NamedTuple, 
#                 }=Dict{Symbol,DataType}())
        
#         if dim < 1 || dim > 3
#             error("Dimensions must be between 1 and 3. Given: $dim")
#         end
        
#         parameter_namedtuple = parameter_convert(parameters)

#         if :NMedium_ in keys(parameter_namedtuple)
#             error("The parameter :NMedium_ is reserved for the number of mediums. Please choose a different name.")
#         elseif any(p.name in [:dx, :dy, :dz] for p in values(parameter_namedtuple))
#             error("The parameters :dx, :dy, and :dz are reserved for the medium's step sizes. Please choose different names.")
#         end

#         pars = (
#             NMedium_=Parameter(:NMedium_, Int, defaultValue=0, description="Number of mediums in the simulation"),
#         )
#         position = parameter_convert([
#             Parameter(:dx, Float64, units=:L, description="X position of the medium"),
#             Parameter(:dy, Float64, units=:L, description="Y position of the medium"),
#             Parameter(:dz, Float64, units=:L, description="Z position of the medium")
#         ][1:1:dim])

#         merged_parameters = merge(pars, position, parameter_namedtuple)

#         new(name, dim, merged_parameters)
#     end
# end

# Base.length(x::Medium) = 1

# function Base.show(io::IO, x::Medium)
#     println(io, "Medium: ", x.name, "\n")
#     println(io, @sprintf("\t%-15s %-15s %-15s %-s %-s", "Name", "DataType", "Units", "Default_Value", "Description"))
#     println(io, "\t" * repeat("-", 85))
#     for (_, par) in pairs(x.parameters)
#         println(io, @sprintf("\t%-15s %-15s %-15s %-20s %-s", 
#             par.name, 
#             string(par.dataType),
#             par.units, 
#             par.defaultValue, 
#             par.description))
#     end
#     println(io)
# end

# """
#     struct Interaction

# Object containing the parameters of an agent.

#     Parameters
#     ----------

# |Field|Description|
# |:---|:---|
# | name::Symbol | Name of the agent. |
# | interactionAgents::Union{Symbol, Tuple{Symbol, Symbol}} | Name of the agents involved in the interaction. If a single agent is provided, it is assumed to interact with itself. |
# | parameters::NamedTuple{Symbol, Parameter} | Named Tuple with name => Parameter. Parameter.name corresponds with key.|

#     Constructors
#     ------------

# Interaction(interactionAgents::Union{Symbol, Tuple{Symbol, Symbol}}; name::Symbol=:interaction, parameters::Union{
#             OrderedDict{Symbol,DataType}, 
#             Dict{Symbol,DataType}, 
#             Vector{Parameter}, 
#             NamedTuple, 
#         }=Dict())

# |Field|Description|
# |:---|:---|
# | interactionAgents::Union{Symbol, Tuple{Symbol, Symbol}} | Name of the agents involved in the interaction. If a single agent is provided, it is assumed to interact with itself. |
# | name::Symbol | Name of the agent. Default :interaction |
# | parameters::NamedTuple{Symbol, Parameter} | Named Tuple with name => Parameter. Parameter.name corresponds with key.|

#     Examples
#     --------

# ```julia
#     # Considering that you have defined some agents named :agent1 and :agent2, you can create an interaction as follows:
#     interaction = Interaction(:agent1, parameters=(mass=Float64, alive=Bool)) # Using NamedTuple
#     interaction = Interaction((:agent1, :agent2), parameters=(mass=Float64, alive=Bool)) # Using NamedTuple
#     interaction = Interaction(:agent1, parameters=OrderedDict(:mass => Float64, :alive => Bool)) # Using OrderedDict
#     interaction = Interaction((:agent1, :agent2), parameters=OrderedDict(:mass => Float64, :alive => Bool)) # Using OrderedDict
#     interaction = Interaction(:agent1, parameters=Dict(:mass => Float64, :alive => Bool)) # Using Dict
#     interaction = Interaction((:agent1, :agent2), parameters=Dict(:mass => Float64, :alive => Bool)) # Using Dict
#     interaction = Interaction(:agent1, 
#                     parameters=[
#                         Parameter(:mass, Float64, defaultValue=10.0),
#                         Parameter(:alive, Bool, defaultValue=true)
#                     ]) # Using Vector{Parameter}
#     interaction = Interaction((:agent1, :agent2), 
#                     parameters=[
#                         Parameter(:mass, Float64, defaultValue=10.0),
#                         Parameter(:alive, Bool, defaultValue=true)
#                     ]) # Using Vector{Parameter}
# ```
# """
# struct Interaction
#     name::Symbol
#     interactionAgents::Tuple{Symbol, Symbol}
#     parameters::NamedTuple

#     function Interaction(interactionAgents::Union{Symbol, Tuple{Symbol, Symbol}}; name::Symbol=:interaction,
#                 parameters::Union{
#                     OrderedDict{Symbol,DataType}, 
#                     Dict{Symbol,DataType}, 
#                     Vector{Parameter}, 
#                     NamedTuple, 
#                 }=Dict{Symbol,DataType}())

#         if interactionAgents isa Symbol
#             interactionAgents = (interactionAgents, interactionAgents)
#         end

#         parameter_namedtuple = parameter_convert(parameters)

#         new(name, interactionAgents, parameter_namedtuple)
#     end
# end

# Base.length(x::Interaction) = 1

# function Base.show(io::IO, x::Interaction)
#     println(io, "Interaction: ", x.name, " between agents ", x.interactionAgents[1], " and ", x.interactionAgents[2], "\n")
#     println(io, @sprintf("\t%-15s %-15s %-15s %-20s %-s", "Name", "DataType", "Units", "Default_Value", "Description"))
#     println(io, "\t" * repeat("-", 85))
#     for (_, par) in pairs(x.parameters)
#         println(io, @sprintf("\t%-15s %-15s %-15s %-20s %-s", 
#             par.name, 
#             string(par.dataType), 
#             par.units,
#             par.defaultValue, 
#             par.description))
#     end
#     println(io)
# end
