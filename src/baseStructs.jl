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
|Field|Description|
|:---|:---|
| value::Any | Value of the parameter. |
| units::Symbol | Units of the parameter. |
"""
mutable struct ValueUnits
    value::Any
    units::Union{Nothing, Symbol, Expr}

    function ValueUnits(value::Any, units::Union{Nothing, Symbol, Expr}=nothing)
        new(value, units)
    end
end

function Base.show(io::IO, x::ValueUnits)

    if x.units === nothing
        return print(io, x.value)
    else
        print(io, x.value, x.units)
    end
end

"""
    mutable struct Parameter
Object containing the information of each parameter of an Agent.
|Field|Description|
|:---|:---|
| name::Symbol | Name of the parameter. |
| dataType::DataType | Type of data. |
| units::String | Units of the parameter. |
| defaultValue::Any | Default value of the parameter. |
| description::String | Description of the parameter. |
"""
mutable struct Parameter
    name::Symbol
    dataType::DataType
    defaultValue::ValueUnits
    description::String

    function Parameter(name::Symbol, dataType::DataType;
                       defaultValue::Union{ValueUnits, Any}=nothing,
                       description::String="")

        # Convert defaultValue to ValueUnits if needed
        if !(typeof(defaultValue) <: ValueUnits)
            defaultValue = ValueUnits(defaultValue)
        end

        # Check that the value is in the correct format
        defaultValue.value = dataType(defaultValue.value)

        # Check that the wrapped value type matches the specified dataType
        if defaultValue !== nothing && dataType != typeof(defaultValue.value)
            throw(TypeError("defaultValue has a different data type than dataType declared", dataType, defaultValue.value))
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

"""
    struct Agent

Object containing the parameters of an agent.

|Field|Description|
|:---|:---|
| name::Symbol | Name of the agent. |
| parameters::OrderedDict{Symbol,UserParameter} | Parameters of the agent. |
"""
struct Agent
    name::Symbol
    parameters::NamedTuple

    function Agent(name::Symbol; parameters::Union{
            OrderedDict{Symbol,DataType}, 
            OrderedDict{Symbol,Parameter}, 
            Dict{Symbol,DataType}, 
            Dict{Symbol,Parameter}, 
            NamedTuple, 
            Vector{Parameter}
        }=Dict())

        parameter_namedtuple = if parameters isa OrderedDict || parameters isa Dict
            keys_tuple = Tuple(keys(parameters))
            values_tuple = Tuple(parameters[i] for i in keys_tuple)
            NamedTuple{keys_tuple}(values_tuple)
        elseif parameters isa Vector{Parameter}
            names = Tuple(p.name for p in parameters)
            values = Tuple(p for p in parameters)
            NamedTuple{names}(values)
        elseif parameters isa NamedTuple
            parameters  # already a NamedTuple
        else
            error("Unsupported parameter type: $(typeof(parameters))")
        end

        new(name, parameter_namedtuple)
    end
end

Base.length(x::Agent) = 1

function Base.show(io::IO, x::Agent)
    println(io, "Agent: ", x.name, "\n")
    println(io, @sprintf("\t%-15s %-15s %-15s %-s", "Name", "DataType", "Default_Value", "Description"))
    println(io, "\t" * repeat("-", 65))
    for (_, par) in pairs(x.parameters)
        println(io, @sprintf("\t%-15s %-15s %-15s %-s", 
            par.name, 
            string(par.dataType), 
            par.defaultValue, 
            par.description))
    end
    println(io)
end
