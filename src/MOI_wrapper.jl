const MOI = MathOptInterface

MOI.Utilities.@model(
    Optimizer,
    (),  # Scalar sets
    (),  # Typed scalar sets
    (MOI.Complements,),  # Vector sets
    (),  # Typed vector sets
    (),  # Scalar functions
    (),  # Typed scalar functions
    (),  # Vector functions
    (MOI.VectorAffineFunction,),  # Typed vector functions
    true,  # is_optimizer
)

function MOI.supports_constraint(
    ::Optimizer, ::Type{MOI.SingleVariable}, ::Type{S}
) where {S <: Union{MOI.Semiinteger, MOI.Semicontinuous, MOI.ZeroOne, MOI.Integer}}
    return false
end

function MOI.supports(
    ::Optimizer, ::MOI.ObjectiveFunction{F}
) where {F<:Union{MOI.SingleVariable, MOI.ScalarAffineFunction, MOI.ScalarQuadraticFunction}}
    return false
end

struct Solution
    status::MCP_Termination
    x::Vector{Float64}
    info::Information
end

solution(model::Optimizer) = get(model.ext, :solution, nothing)::Union{Nothing, Solution}

"""
    Optimizer()

Define a new PATH optimizer.

Pass options using `MOI.RawParameter`. Common options include:

 - output => "yes"
 - convergence_tolerance => 1e-6
 - time_limit => 3600

A full list of options can be found at http://pages.cs.wisc.edu/~ferris/path/options.pdf.

### Example

    optimizer = PATH.Optimizer()
    MOI.set(optimizer, MOI.RawParameter("output"), "no")
"""
function Optimizer()
    model = Optimizer{Float64}()
    model.ext[:kwargs] = Dict{Symbol, Any}()
    model.ext[:solution] = nothing
    return model
end

function MOI.set(model::Optimizer, p::MOI.RawParameter, v)
    model.ext[:kwargs][Symbol(p.name)] = v
    return
end

function MOI.get(model::Optimizer, p::MOI.RawParameter)
    return get(model.ext[:kwargs], Symbol(p.name), nothing)
end

MOI.get(model::Optimizer, ::MOI.SolverName) = c_api_Path_Version()

function MOI.get(
    model::Optimizer, ::MOI.VariablePrimalStart, x::MOI.VariableIndex
)
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
            MOI.VectorAffineFunction{Float64}, MOI.Complements
        }()
    )
        Fi = MOI.get(model, MOI.ConstraintFunction(), index)
        Si = MOI.get(model, MOI.ConstraintSet(), index)

        if 2 * Si.dimension != length(Fi.constants)
            error(
                "Dimension of constant vector $(length(Fi.constants)) does not match the " *
                "required dimension of the complementarity set $(2 * Si.dimension)."
            )
        elseif any(i -> !iszero(Fi.constants[Si.dimension + i]), 1:Si.dimension)
            error(
                "VectorAffineFunction malformed: a constant associated with a " *
                "complemented variable is not zero: $(Fi.constants[Si.dimension+1:end])."
            )
        end

        # First pass: get rows vector and check for invalid functions.
        rows = fill(0, Si.dimension)
        for term in Fi.terms
            if term.output_index <= Si.dimension
                # No-op: leave for second pass.
                continue
            elseif term.output_index > 2 * Si.dimension
                error(
                    "VectorAffineFunction malformed: output_index $(term.output_index) " *
                    "is too large."
                )
            end
            dimension_i = term.output_index - Si.dimension
            row_i = term.scalar_term.variable_index.value
            if rows[dimension_i] != 0 || has_term[row_i]
                error(
                    "The variable $(term.scalar_term.variable_index) appears in more " *
                    "than one complementarity constraint."
                )
            elseif term.scalar_term.coefficient != 1.0
                error(
                    "VectorAffineFunction malformed: variable " *
                    "$(term.scalar_term.variable_index) has a coefficient that is not 1 " *
                    "in row $(term.output_index) of the VectorAffineFunction."
                )
            end
            rows[dimension_i] = row_i
            has_term[row_i] = true
            q[row_i] = Fi.constants[dimension_i]
        end

        # Second pass: add to sparse array
        for term in Fi.terms
            s_term = term.scalar_term
            if term.output_index > Si.dimension || iszero(s_term.coefficient)
                continue
            end
            row_i = rows[term.output_index]
            if iszero(row_i)
                error(
                    "VectorAffineFunction malformed: expected variable in row " *
                    "$(Si.dimension + term.output_index)."
                )
            end
            M[row_i, s_term.variable_index.value] += s_term.coefficient
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
        M,
        q,
        lower,
        upper,
        initial;
        [k => v for (k, v) in model.ext[:kwargs]]...
    )
    model.ext[:solution] = Solution(status, x, info)
    return
end

const _MCP_TERMINATION_STATUS_MAP =
    Dict{MCP_Termination, Tuple{MOI.TerminationStatusCode, String}}(
        MCP_Solved => (MOI.LOCALLY_SOLVED, "The problem was solved"),
        MCP_NoProgress => (MOI.SLOW_PROGRESS, "A stationary point was found"),
        MCP_MajorIterationLimit => (MOI.ITERATION_LIMIT, "Major iteration limit met"),
        MCP_MinorIterationLimit => (MOI.ITERATION_LIMIT, "Cumulative minor iterlim met"),
        MCP_TimeLimit => (MOI.TIME_LIMIT, "Ran out of time"),
        MCP_UserInterrupt => (MOI.INTERRUPTED, "Control-C, typically"),
        MCP_BoundError => (MOI.INVALID_MODEL, "Problem has a bound error"),
        MCP_DomainError => (MOI.NUMERICAL_ERROR, "Could not find a starting point"),
        MCP_Infeasible => (MOI.INFEASIBLE, "Problem has no solution"),
        MCP_Error => (MOI.OTHER_ERROR, "An error occured within the code"),
        MCP_LicenseError => (MOI.OTHER_ERROR, "License could not be found"),
        MCP_OK => (MOI.OTHER_ERROR, "")
    )

function MOI.get(model::Optimizer, ::MOI.TerminationStatus)
    if solution(model) === nothing
        return MOI.OPTIMIZE_NOT_CALLED
    end
    status, _ = _MCP_TERMINATION_STATUS_MAP[solution(model).status]
    return status
end

function MOI.get(model::Optimizer, ::MOI.RawStatusString)
    if solution(model) === nothing
        return "MOI.optimize! was not called yet"
    end
    _, reason = _MCP_TERMINATION_STATUS_MAP[solution(model).status]
    return reason
end

function MOI.get(model::Optimizer, ::MOI.ResultCount)
    return solution(model) !== nothing ? 1 : 0
end

function MOI.get(
    model::Optimizer, attr::MOI.VariablePrimal, x::MOI.VariableIndex
)
    MOI.check_result_index_bounds(model, attr)
    return solution(model).x[x.value]
end

function MOI.get(model::Optimizer, attr::MOI.PrimalStatus)
    if solution(model) === nothing || attr.N != 1
        return MOI.NO_SOLUTION
    end
    if MOI.get(model, MOI.TerminationStatus()) == MOI.LOCALLY_SOLVED
        return MOI.FEASIBLE_POINT
    end
    return MOI.UNKNOWN_RESULT_STATUS
end
