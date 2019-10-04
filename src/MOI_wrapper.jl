const MOI = MathOptInterface

"""
    Complements()
"""
struct Complements <: MOI.AbstractVectorSet end

MOI.copy(::Complements) = Complements()

MOI.Utilities.@model(
    Optimizer,
    (),  # Scalar sets
    (),  # Typed scalar sets
    (Complements,),  # Vector sets
    (),  # Typed vector sets
    (),  # Scalar functions
    (),  # Typed scalar functions
    (),  # Vector functions
    (MOI.VectorAffineFunction,),  # Typed vector functions
)

struct Solution
    status::MCP_Termination
    x::Vector{Float64}
    info::Information
end

solution(model::Optimizer) = get(model.ext, :solution, nothing)::Union{Nothing, Solution}
kwargs(model::Optimizer) = get(model.ext, :kwargs, nothing)

"""
Optimizer(; kwargs...)
"""
function Optimizer(; kwargs...)
    model = Optimizer{Float64}()
    model.ext[:kwargs] = kwargs
    model.ext[:solution] = nothing
    return model
end

function MOI.supports_constraint(
    ::Optimizer, ::Type{MOI.SingleVariable}, ::Type{S}
) where {S <: MOI.AbstractScalarFunction}
    return false
end

function MOI.supports_constraint(
    ::Optimizer, ::Type{MOI.SingleVariable}, ::Type{S}
) where {S <: MOI.Interval}
    return true
end

MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = false
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction) = false

MOI.get(model::Optimizer, ::MOI.Name) = c_api_Path_Version()

function MOI.get(model::Optimizer, ::MOI.VariablePrimalStart, x::MOI.VariableIndex)
    initial = get(model.ext, :variable_primal_start, nothing)
    if initial === nothing
        return nothing
    end
    return get(initial, x, nothing)
end

function MOI.set(
    model::Optimizer, ::MOI.VariablePrimalStart, x::MOI.VariableIndex, value
)
    initial = get(model.ext, :variable_primal_start, nothing)
    if initial === nothing
        model.ext[:variable_primal_start] = Dict{MOI.VariableIndex, Float64}()
        initial = model.ext[:variable_primal_start]
    end
    if value === nothing
        delete!(initial, x)
    else
        initial[x] = value
    end
    return
end

function _F_linear_operator(model::Optimizer)
    n = MOI.get(model, MOI.NumberOfVariables())
    M = SparseArrays.sparse(Int32[], Int32[], Float64[], n, n)
    q = zeros(n)
    has_term = fill(false, n)
    for index in MOI.get(
        model,
        MOI.ListOfConstraintIndices{
            MOI.VectorAffineFunction{Float64}, Complements
        }()
    )
        Fi = MOI.get(model, MOI.ConstraintFunction(), index)
        if !iszero(Fi.constants[2])
            error("constants[2] not zero.")
        end
        # First pass: get second element and check for invalid functions.
        xi = nothing
        for term in Fi.terms
            if term.output_index == 1
                # No-op: leave for second pass.
            elseif term.output_index == 2
                if xi !== nothing
                    error("Only x in second term")
                elseif term.scalar_term.coefficient != 1.0
                    error("Need plain variable in second term")
                end
                xi = term.scalar_term.variable_index
            else
                error("Too many terms")
            end
        end
        if xi === nothing
            error("No second term")
        end

        row = xi.value

        if has_term[row]
            error("F not square.")
        end

        q[row] = Fi.constants[1]

        # Second pass: add to sparse array
        for term in Fi.terms
            if term.output_index != 1
                continue
            end
            s_term = term.scalar_term
            if iszero(s_term.coefficient)
                continue
            end
            M[row, s_term.variable_index.value] += s_term.coefficient
        end
    end
    return M, q
end

function _bounds_and_starting(model::Optimizer)
    x = MOI.get(model, MOI.ListOfVariableIndices())
    lower = fill(-INFINITY, length(x))
    upper = fill(INFINITY, length(x))
    initial = fill(0.0, length(x))
    for (i, xi) in enumerate(x)
        l, u = MOI.Utilities.get_bounds(model, Float64, xi)
        z = MOI.get(model, MOI.VariablePrimalStart(), xi)
        lower[i] = l
        upper[i] = u
        initial[i] = z !== nothing ? z : 0.5 * (l + u)
    end
    return lower, upper, initial
end

function MOI.optimize!(model::Optimizer)
    model.ext[:solution] = nothing
    lower, upper, initial = _bounds_and_starting(model)
    M, q = _F_linear_operator(model)
    status, x, info = solve_mcp(
        M, q, lower, upper, initial; model.ext[:kwargs]...
    )
    model.ext[:solution] = Solution(status, x, info)
    return
end

const _MCP_TERMINATION_STATUS_MAP =
    Dict{MCP_Termination, MOI.TerminationStatusCode}(
        MCP_Solved => MOI.LOCALLY_SOLVED,
        MCP_NoProgress => MOI.SLOW_PROGRESS,
        MCP_MajorIterationLimit => MOI.ITERATION_LIMIT,
        MCP_MinorIterationLimit => MOI.ITERATION_LIMIT,
        MCP_TimeLimit => MOI.TIME_LIMIT,
        MCP_UserInterrupt => MOI.INTERRUPTED,
        MCP_BoundError => MOI.OTHER_ERROR,
        MCP_DomainError => MOI.NUMERICAL_ERROR,
        MCP_Infeasible => MOI.INFEASIBLE,
        MCP_Error => MOI.OTHER_ERROR,
        MCP_LicenseError => MOI.OTHER_ERROR,
        MCP_OK => MOI.OTHER_ERROR
    )

function MOI.get(model::Optimizer, ::MOI.TerminationStatus)
    if solution(model) === nothing
        return MOI.OPTIMIZE_NOT_CALLED
    end
    return _MCP_TERMINATION_STATUS_MAP[solution(model).status]
end

function MOI.get(model::Optimizer, ::MOI.ResultCount)
    return solution(model) !== nothing ? 1 : 0
end

function MOI.get(model::Optimizer, attr::MOI.VariablePrimal, x::MOI.VariableIndex)
    MOI.check_result_index_bounds(model, attr)
    if solution(model) === nothing
        error("No solution")
    end
    return solution(model).x[x.value]
end

function MOI.get(model::Optimizer, attr::MOI.PrimalStatus)
    if solution(model) === nothing
        return MOI.NO_SOLUTION
    end
    if MOI.get(model, MOI.TerminationStatus()) == MOI.LOCALLY_SOLVED
        return MOI.FEASIBLE_POINT
    end
    return MOI.UNKNOWN_RESULT_STATUS
end
