import DifferentialEquations: ODEProblem, SDEProblem, DEProblem
import DifferentialEquations: init, step!

struct CBProblem{P}

    mesh::AbstractMesh
    u0::AbstractMeshObject
    tspan::Tuple{Real,Real}
    p::P
    u::AbstractMeshObject
    _DEProblems::Dict{Symbol, DEProblem}

end

"""
    _validate_initialized_parameters(mesh, meshObject)

Check that all parameters without default values have been initialized.
Raises an error if any required parameter is found uninitialized.
Note: This check uses NaN as an uninitialized marker for Float types, so zeros are valid.
"""
function _validate_initialized_parameters(mesh::AbstractMesh, meshObject::AbstractMeshObject)
    uninitialized = Vector{String}()
    
    # Check shared parameters (obj.p.X)
    if hasfield(typeof(mesh), :_parameters) && mesh._parameters !== nothing
        for (name, param) in pairs(mesh._parameters)
            if param.defaultValue === nothing
                # Parameter has no default - check if the user initialized it
                if hasfield(typeof(meshObject), :_parameters) && meshObject._parameters !== nothing
                    if haskey(meshObject._parameters, name)
                        val = meshObject._parameters[name]
                        # Check if value contains NaN (uninitialized marker for floats)
                        if eltype(val) <: AbstractFloat && any(isnan, val)
                            push!(uninitialized, "p.$name (shared parameter)")
                        end
                    end
                end
            end
        end
    end
    
    # Check node/element properties (obj.n.X, etc.)
    for (scope_name, scope_prop) in pairs(mesh._p)
        if scope_prop !== nothing && hasfield(typeof(scope_prop), :p)
            for (prop_name, param) in pairs(scope_prop.p)
                if param.defaultValue === nothing
                    # Parameter has no default - check if the user initialized it
                    mesh_obj_scope = getproperty(meshObject, scope_name)
                    if mesh_obj_scope !== nothing
                        val = getproperty(mesh_obj_scope, prop_name)
                        # Get actual element count from _N field
                        N = mesh_obj_scope._N[]
                        # Check if values contain NaN (uninitialized marker for floats)
                        if N > 0 && eltype(val) <: AbstractFloat && any(isnan, view(val, 1:N))
                            push!(uninitialized, "$scope_name.$prop_name")
                        end
                    end
                end
            end
        end
    end
    
    if !isempty(uninitialized)
        error("The following parameters have no defaultValue and were not initialized:\n  - " * join(uninitialized, "\n  - ") *
              "\n\nPlease either assign values to these parameters before creating CBProblem, " *
              "or provide a defaultValue in the model definition.")
    end
end

function CBProblem(mesh::CellBasedModels.AbstractMesh, meshObject0::CellBasedModels.AbstractMeshObject, tspan::Tuple{T,T}=(0.,1.), p::Tuple=tuple()) where T<:Real

    # Validate that all parameters without defaults have been initialized
    _validate_initialized_parameters(mesh, meshObject0)

    u0 = meshObject0
    u = deepcopy(u0)

    DEProblemsDict = Dict{Symbol, DEProblem}()
    for scope in keys(mesh._functions)
        args = modifiedInScope(mesh, scope)
        type, fs = mesh._functions[scope]

        if type == :RULE
            DEProblemsDict[scope] = RuleProblem(fs[1], partialCopy(u, args), tspan, p)
        elseif type == :ODE
            DEProblemsDict[scope] = ODEProblem(fs[1], partialCopy(u, args), tspan, p)
        elseif type == :SDE
            DEProblemsDict[scope] = SDEProblem(fs[1], fs[2], partialCopy(u, args), tspan, p)
        else
            error("Unknown function type: $type")
        end

    end

    P = typeof(p)

    return CBProblem{P}(mesh, u0, tspan, p, u, DEProblemsDict)

end

mutable struct CBIntegrator{M, I}

    u::M
    integrators::I
    dt::Real
    t::Real
    overflowFactor::Real

end

function DifferentialEquations.init(problem::CBProblem; dt::Real, overflowFactor::Real=1.0, kwargs...)

    kwargs_ = deepcopy(kwargs)

    for (k, v) in pairs(kwargs_)
        
        if !(k in keys(problem._DEProblems))
           error("Unknown scope $k for CBProblem. Available scopes: $(keys(problem._DEProblems))")
        end

    end

    CellBasedModels.update!(problem.u)

    integratorsDict = Dict{Symbol, Any}()
    for (scope, deproblem) in problem._DEProblems

        integrator = nothing
        args = Dict{Symbol, Any}()
        if scope in keys(kwargs_)
            v = kwargs_[scope]
            if !(v isa Tuple)
                integrator = v
            else
                integrator, args = v
                args = Dict(args)
            end
        end

        #Override arguments
        args[:save_everystep] = false
        args[:dt] = dt
        # args[:adaptive] = false
        # args[:dtmax] = dt
        # args[:dtmin] = dt
        
        if typeof(deproblem) == RuleProblem
            integratorsDict[scope] = DifferentialEquations.init(deproblem; dt=dt)
        else
            if integrator === nothing
                integratorsDict[scope] = DifferentialEquations.init(deproblem; (;args...)...)
            else
                integratorsDict[scope] = DifferentialEquations.init(deproblem, integrator; (;args...)...)
            end
        end
    end

    integrators = (;integratorsDict...)

    integrator = CBIntegrator{typeof(problem.u), typeof(integrators)}(problem.u, integrators, dt, problem.tspan[1], overflowFactor)

    return integrator

end

function DifferentialEquations.step!(integrator::CBIntegrator)

    dt = integrator.dt

    # Update neighbor structures before running kernels
    CellBasedModels.update!(integrator.u)

    # Step ODEs
    for (scope, deintegrator) in pairs(integrator.integrators)
        if typeof(deintegrator) != Rule
            DifferentialEquations.step!(deintegrator, dt, true)
        end
    end
    # Update Us
    for (scope, deintegrator) in pairs(integrator.integrators)
        if typeof(deintegrator) != Rule
            copyto!(integrator.u, deintegrator.u)
        end
    end
    # Push results to deintegrators
    for (scope, deintegrator) in pairs(integrator.integrators)
        if typeof(deintegrator) == Rule
            CellBasedModels.copyfrom!(deintegrator.u, integrator.u)
        end
    end

    # Step Rules
    for (scope, deintegrator) in pairs(integrator.integrators)
        if typeof(deintegrator) == Rule
            DifferentialEquations.step!(deintegrator)
        end 
    end
    while isOverflowed(integrator.u)
        @warn "Overflow detected in CBIntegrator. Preallocating additional cache. If this happens frequently, consider increasing overflowFactor or preallocate cache sizes before running the simulation."
        # Get overflow information from all fields
        overflows = getOverflow(integrator.u, integrator.overflowFactor)
        resetOverflow!(integrator.u)
        
        # Preallocate based on actual overflow amounts
        preallocate!(integrator, overflows)
        
        # Rerun Rules after preallocation to ensure all pending operations complete
        for (scope, deintegrator) in pairs(integrator.integrators)
            if typeof(deintegrator) == Rule
                DifferentialEquations.step!(deintegrator)
            end 
        end
    end        
    # Now safely update Us after handling any overflows
    for (scope, deintegrator) in pairs(integrator.integrators)
        if typeof(deintegrator) == Rule
            copyto!(integrator.u, deintegrator.u)
        end
    end

    # Update mesh (e.g., add/remove agents)
    CellBasedModels.update!(integrator.u)

    # Push results to deintegrators
    for (scope, deintegrator) in pairs(integrator.integrators)
        CellBasedModels.copyfrom!(deintegrator.u, integrator.u)
    end

    # Increment time
    integrator.t += integrator.dt

    return nothing

end

function preallocate!(integrator::CBIntegrator, additionalCache::NamedTuple = (;))
    """
    Allocate additional cache memory for specific fields in the integrator.
    additionalCache should be a NamedTuple with field names as keys and additional cache sizes as values.
    Fields not specified in the NamedTuple will not be preallocated.
    Reinitializes all sub-integrators with the new mesh state.
    
    Example:
        preallocate!(integrator, (n=100, e=50))  # Preallocate 100 for field n, 50 for field e
    """
    
    # Preallocate the main mesh object with per-field allocation
    CellBasedModels.preallocate!(integrator.u, additionalCache)
    
    # Update all sub-integrators with the new mesh state
    for (scope, deintegrator) in pairs(integrator.integrators)
        DifferentialEquations.reinit!(deintegrator, integrator.u)
    end
    
    return nothing

end

# function preallocate!(integrator::CBIntegrator)

#     CellBasedModels.preallocate!(integrator.u)

#     # Push results to deintegrators
#     for (scope, deintegrator) in pairs(integrator.integrators)
#         CellBasedModels.copyfrom!(deintegrator.u, integrator.u)
#     end

#     return nothing

# end