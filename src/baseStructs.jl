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

    function UserParameter(name, dataType, scope, subscope=:Main)
        if scope in [:medium] && !(dataType <: Number)
            error("Parameters of medium must be of type Number. $name is defined with type $dataType.")
        else
            return new(dataType,scope,subscope,false,false,0)
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
    struct Agent

Object containing the parameters of an agent.

|Field|Description|
|:---|:---|
| name::Symbol | Name of the agent. |
| parameters::OrderedDict{Symbol,UserParameter} | Parameters of the agent. |
"""
struct Agent

    name::Symbol
    pos::Union{Nothing,Symbol,NamedTuple, OrderedDict{Symbol,DataType}, Dict{Symbol,DataType}}
    id::Symbol
    parameters::Union{OrderedDict{Symbol,DataType}, Dict{Symbol,DataType}, NamedTuple}

    function Agent(name::Symbol; pos, id, parameters::Union{Tuple, OrderedDict{Symbol,DataType}, Dict{Symbol,DataType}}=Dict())
        new(name, pos, id, parameters)
    end

end

Base.length(x::Agent) = 1