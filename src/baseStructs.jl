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

    print(io, (x.value, x.units))

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
| units::String | Units of the parameter. |
| defaultValue::Union{ValueUnits, Number, Nothing} = nothing | Default value of the parameter. |
| description::String = "" | Description of the parameter. |

    Constructors
    ------------

Parameter(name::Symbol, dataType::DataType; defaultValue=ValueUnits(nothing, nothing), description::String="")

    Examples
    --------

```julia
    p = Parameter(:velocity, Float64) # Minimum definition
    p = Parameter(:velocity, Float64, defaultValue=12.0, description="Velocity of the agent")
    p = Parameter(:velocity, Float64, defaultValue=ValueUnits(12.0, :kg), description="Velocity of the agent")
```
"""
mutable struct Parameter
    name::Symbol
    dataType::DataType
    defaultValue::ValueUnits
    description::String

    function Parameter(name::Symbol, dataType::DataType;
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

        new(name, dataType, defaultValue, description)
    end
end

function Base.show(io::IO, x::Parameter)
    println("Parameter: ", x.name)
    println("\t DataType: ", x.dataType)
    println("\t Default Value: ", x.defaultValue)
    println("\t Description: ", x.description)
end

function parameter_convert(parameters::Union{
        OrderedDict{Symbol,DataType}, 
        Dict{Symbol,DataType}, 
        Vector{Parameter}, 
        NamedTuple,
    })
    parameter_namedtuple = if parameters isa OrderedDict || parameters isa Dict
        keys_tuple = Tuple(keys(parameters))
        values_tuple = Tuple([Parameter(i, parameters[i]) for i in keys_tuple])
        NamedTuple{keys_tuple}(values_tuple)
    elseif parameters isa NamedTuple
        keys_tuple = Tuple(keys(parameters))
        values_tuple = Tuple([Parameter(i, parameters[i]) for i in keys_tuple])
        NamedTuple{keys_tuple}(values_tuple)
    elseif parameters isa Vector{Parameter}
        names = Tuple(p.name for p in parameters)
        values = Tuple(p for p in parameters)
        NamedTuple{names}(values)
    else
        error("Unsupported parameter type: $(typeof(parameters))")
    end

    return parameter_namedtuple
end

"""
    mutable struct Agent

Object containing the parameters of an agent.

    Parameters
    ----------

|Field|Description|
|:---|:---|
| name::Symbol | Name of the agent. |
| parameters::NamedTuple{Symbol, Parameter} | Named Tuple with name => Parameter. Parameter.name corresponds with key.|

    Constructors
    ------------

Agent(name::Symbol; parameters::Union{
            OrderedDict{Symbol,DataType}, 
            Dict{Symbol,DataType}, 
            Vector{Parameter}, 
            NamedTuple, 
        }=Dict())

    Examples
    --------

```julia
    agent = Agent(:cell, parameters=(mass=Float64, alive=Bool)) # Using NamedTuple
    agent = Agent(:cell, parameters=OrderedDict(:mass => Float64, :alive => Bool)) # Using OrderedDict
    agent = Agent(:cell, parameters=Dict(:mass => Float64, :alive => Bool)) # Using Dict
    agent = Agent(:cell, 
                    parameters=[
                        Parameter(:mass, Float64, defaultValue=10.0),
                        Parameter(:alive, Bool, defaultValue=true)
                    ]) # Using Vector{Parameter}
```
"""
mutable struct Agent
    name::Symbol
    parameters::NamedTuple

    function Agent(name::Symbol; parameters::Union{
            OrderedDict{Symbol,DataType}, 
            Dict{Symbol,DataType}, 
            Vector{Parameter}, 
            NamedTuple, 
        }=Dict())

        parameter_namedtuple = parameter_convert(parameters)

        new(name, parameter_namedtuple)
    end
end

Base.length(x::Agent) = 1

function Base.show(io::IO, x::Agent)
    println(io, "Agent: ", x.name, "\n")
    println(io, @sprintf("\t%-15s %-15s %-20s %-s", "Name", "DataType", "Default_Value", "Description"))
    println(io, "\t" * repeat("-", 65))
    for (_, par) in pairs(x.parameters)
        println(io, @sprintf("\t%-15s %-15s %-20s %-s", 
            par.name, 
            string(par.dataType), 
            par.defaultValue, 
            par.description))
    end
    println(io)
end

"""
    mutable struct Medium

Object containing the parameters of a medium.

    Parameters
    ----------

|Field|Description|
|:---|:---|
| name::Symbol | Name of the medium. |
| parameters::NamedTuple{Symbol, Parameter} | Named Tuple with name => Parameter. Parameter.name corresponds with key.|

    Constructors
    ------------

Medium(name::Symbol; parameters::Union{
            OrderedDict{Symbol,DataType}, 
            Dict{Symbol,DataType}, 
            Vector{Parameter}, 
            NamedTuple, 
        }=Dict())

    Examples
    --------

```julia
    medium = Medium(:cell, parameters=(mass=Float64, alive=Bool)) # Using NamedTuple
    medium = Medium(:cell, parameters=OrderedDict(:mass => Float64, :alive => Bool)) # Using OrderedDict
    medium = Medium(:cell, parameters=Dict(:mass => Float64, :alive => Bool)) # Using Dict
    medium = Medium(:cell, 
                    parameters=[
                        Parameter(:mass, Float64, defaultValue=10.0),
                        Parameter(:alive, Bool, defaultValue=true)
                    ]) # Using Vector{Parameter}
```
"""
mutable struct Medium
    name::Symbol
    parameters::NamedTuple

    function Medium(name::Symbol; parameters::Union{
            OrderedDict{Symbol,DataType}, 
            Dict{Symbol,DataType}, 
            Vector{Parameter}, 
            NamedTuple, 
        }=Dict())

        parameter_namedtuple = parameter_convert(parameters)

        new(name, parameter_namedtuple)
    end
end

Base.length(x::Medium) = 1

function Base.show(io::IO, x::Medium)
    println(io, "Medium: ", x.name, "\n")
    println(io, @sprintf("\t%-15s %-15s %-s %-s", "Name", "DataType", "Default_Value", "Description"))
    println(io, "\t" * repeat("-", 65))
    for (_, par) in pairs(x.parameters)
        println(io, @sprintf("\t%-15s %-15s %-20s %-s", 
            par.name, 
            string(par.dataType), 
            par.defaultValue, 
            par.description))
    end
    println(io)
end

"""
    mutable struct GlobalEnvironment

Object containing the parameters of the globalEnvironment.

    Parameters
    ----------

|Field|Description|
|:---|:---|
| parameters::NamedTuple{Symbol, Parameter} | Named Tuple with name => Parameter. Parameter.name corresponds with key.|

    Constructors
    ------------

GlobalEnvironment(parameters::Union{
            OrderedDict{Symbol,DataType}, 
            Dict{Symbol,DataType}, 
            Vector{Parameter}, 
            NamedTuple, 
        }=Dict())

    Examples
    --------

```julia
    globalEnvironment = GlobalEnvironment(parameters=(mass=Float64, alive=Bool)) # Using NamedTuple
    globalEnvironment = GlobalEnvironment(parameters=OrderedDict(:mass => Float64, :alive => Bool)) # Using OrderedDict
    globalEnvironment = GlobalEnvironment(parameters=Dict(:mass => Float64, :alive => Bool)) # Using Dict
    globalEnvironment = GlobalEnvironment(
                    parameters=[
                        Parameter(:mass, Float64, defaultValue=10.0),
                        Parameter(:alive, Bool, defaultValue=true)
                    ]) # Using Vector{Parameter}
```
"""
mutable struct GlobalEnvironment
    parameters::NamedTuple

    function GlobalEnvironment(; parameters::Union{
            OrderedDict{Symbol,DataType}, 
            Dict{Symbol,DataType}, 
            Vector{Parameter}, 
            NamedTuple, 
        }=Dict())

        parameter_namedtuple = parameter_convert(parameters)

        new(parameter_namedtuple)
    end
end

Base.length(x::GlobalEnvironment) = 1

function Base.show(io::IO, x::GlobalEnvironment)
    println(io, @sprintf("\t%-15s %-15s %-20s %-s", "Name", "DataType", "Default_Value", "Description"))
    println(io, "\t" * repeat("-", 65))
    for (_, par) in pairs(x.parameters)
        println(io, @sprintf("\t%-15s %-15s %-20s %-s", 
            par.name, 
            string(par.dataType), 
            par.defaultValue, 
            par.description))
    end
    println(io)
end