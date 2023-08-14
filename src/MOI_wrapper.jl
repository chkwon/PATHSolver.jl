# Copyright (c) 2016 Changhyun Kwon, Oscar Dowson, and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

MOI.Utilities.@model(
    Optimizer,
    (),  # Scalar sets
    (),  # Typed scalar sets
    (MOI.Complements,),  # Vector sets
    (),  # Typed vector sets
    (),  # Scalar functions
    (),  # Typed scalar functions
    (MOI.VectorNonlinearFunction,),  # Vector functions
    (MOI.VectorAffineFunction,MOI.VectorQuadraticFunction),  # Typed vector functions
    true,  # is_optimizer
)

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VariableIndex},
    ::Type{<:MOI.AbstractScalarSet},
)
    return false
end

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VariableIndex},
    ::Type{S},
) where {
    S<:Union{
        MOI.LessThan{Float64},
        MOI.GreaterThan{Float64},
        MOI.EqualTo{Float64},
        MOI.Interval{Float64},
    },
}
    return true
end

function MOI.supports(
    ::Optimizer,
    ::MOI.ObjectiveFunction{F},
) where {F<:MOI.AbstractFunction}
    return false
end

struct Solution
    status::MCP_Termination
    x::Vector{Float64}
    info::Information
end

function solution(model::Optimizer)
    return get(model.ext, :solution, nothing)::Union{Nothing,Solution}
end

"""
    Optimizer()

Define a new PATH optimizer.

Pass options using `MOI.RawOptimizerAttribute`. Common options include:

 - output => "yes"
 - convergence_tolerance => 1e-6
 - time_limit => 3600

A full list of options can be found at http://pages.cs.wisc.edu/~ferris/path/options.pdf.

### Example

```julia
import PATHSolver
import MathOptInterface as MOI
model = PATHSolver.Optimizer()
MOI.set(model, MOI.RawOptimizerAttribute("output"), "no")
```
"""
function Optimizer()
    model = Optimizer{Float64}()
    model.ext[:silent] = false
    model.ext[:kwargs] = Dict{Symbol,Any}()
    model.ext[:solution] = nothing
    return model
end

function MOI.set(model::Optimizer, p::MOI.RawOptimizerAttribute, v)
    model.ext[:kwargs][Symbol(p.name)] = v
    return
end

function MOI.get(model::Optimizer, p::MOI.RawOptimizerAttribute)
    return get(model.ext[:kwargs], Symbol(p.name), nothing)
end

MOI.supports(model::Optimizer, ::MOI.Silent) = true

MOI.get(model::Optimizer, ::MOI.Silent) = model.ext[:silent]

function MOI.set(model::Optimizer, ::MOI.Silent, x::Bool)
    model.ext[:silent] = x
    return
end

MOI.get(model::Optimizer, ::MOI.SolverName) = c_api_Path_Version()

function MOI.supports(
    ::Optimizer,
    ::MOI.VariablePrimalStart,
    ::Type{MOI.VariableIndex},
)
    return true
end

function MOI.get(
    model::Optimizer,
    ::MOI.VariablePrimalStart,
    x::MOI.VariableIndex,
)
    initial = get(model.ext, :variable_primal_start, nothing)
    if initial === nothing
        return nothing
    end
    return get(initial, x, nothing)
end

function MOI.set(
    model::Optimizer,
    ::MOI.VariablePrimalStart,
    x::MOI.VariableIndex,
    value,
)
    initial = get(model.ext, :variable_primal_start, nothing)
    if initial === nothing
        model.ext[:variable_primal_start] = Dict{MOI.VariableIndex,Float64}()
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
            MOI.VectorAffineFunction{Float64},
            MOI.Complements,
        }(),
    )
        Fi = MOI.get(model, MOI.ConstraintFunction(), index)
        Si = MOI.get(model, MOI.ConstraintSet(), index)
        var_i = div(Si.dimension, 2) + 1
        if Si.dimension != length(Fi.constants)
            error(
                "Dimension of constant vector $(length(Fi.constants)) does not match the " *
                "required dimension of the complementarity set $(Si.dimension).",
            )
        elseif any(!iszero, Fi.constants[var_i:end])
            error(
                "VectorAffineFunction malformed: a constant associated with a " *
                "complemented variable is not zero: $(Fi.constants[var_i:end]).",
            )
        end
        # First pass: get rows vector and check for invalid functions.
        rows = fill(0, Si.dimension)
        for term in Fi.terms
            if term.output_index <= div(Si.dimension, 2)
                # No-op: leave for second pass.
                continue
            elseif term.output_index > Si.dimension
                error(
                    "VectorAffineFunction malformed: output_index $(term.output_index) " *
                    "is too large.",
                )
            end
            dimension_i = term.output_index - div(Si.dimension, 2)
            row_i = term.scalar_term.variable.value
            if rows[dimension_i] != 0 || has_term[row_i]
                error(
                    "The variable $(term.scalar_term.variable) appears in more " *
                    "than one complementarity constraint.",
                )
            elseif term.scalar_term.coefficient != 1.0
                error(
                    "VectorAffineFunction malformed: variable " *
                    "$(term.scalar_term.variable) has a coefficient that is not 1 " *
                    "in row $(term.output_index) of the VectorAffineFunction.",
                )
            end
            rows[dimension_i] = row_i
            has_term[row_i] = true
            q[row_i] = Fi.constants[dimension_i]
        end
        # Second pass: add to sparse array
        for term in Fi.terms
            s_term = term.scalar_term
            if term.output_index >= var_i || iszero(s_term.coefficient)
                continue
            end
            row_i = rows[term.output_index]
            if iszero(row_i)
                error(
                    "VectorAffineFunction malformed: expected variable in row " *
                    "$(div(Si.dimension, 2) + term.output_index).",
                )
            end
            M[row_i, s_term.variable.value] += s_term.coefficient
        end
    end
    return M, q, SparseArrays.nnz(M)
end

function _F_nonlinear_operator(model::Optimizer)
    x = MOI.get(model, MOI.ListOfVariableIndices())
    f_map = Vector{MOI.ScalarNonlinearFunction}(undef, length(x))
    # Parse VectorQuadraticFunction-in-Complements
    T = MOI.VectorQuadraticFunction{Float64}
    for ci in MOI.get(model, MOI.ListOfConstraintIndices{T,MOI.Complements}())
        f = MOI.get(model, MOI.ConstraintFunction(), ci)
        scalars = MOI.Utilities.scalarize(f)
        s = MOI.get(model, MOI.ConstraintSet(), ci)
        N = div(MOI.dimension(s), 2)
        for i in 1:N
            xi = convert(MOI.VariableIndex, scalars[i+N])
            f_map[xi.value] = convert(MOI.ScalarNonlinearFunction, scalars[i])
        end
    end
    # Parse VectorNonlinearFunction-in-Complements
    T = MOI.VectorNonlinearFunction
    for ci in MOI.get(model, MOI.ListOfConstraintIndices{T,MOI.Complements}())
        f = MOI.get(model, MOI.ConstraintFunction(), ci)
        s = MOI.get(model, MOI.ConstraintSet(), ci)
        N = div(MOI.dimension(s), 2)
        for i in 1:N
            xi = f.rows[i+N]
            # Hacky way to ensure that xi is a standalone variable
            @assert xi isa MOI.ScalarNonlinearFunction
            @assert xi.head == :+ && length(xi.args) == 1
            @assert xi.args[1] isa MOI.VariableIndex
            f_map[xi.args[1].value] = f.rows[i]
        end
    end
    nlp = MOI.Nonlinear.Model()
    for fi in f_map
        MOI.Nonlinear.add_constraint(nlp, fi, MOI.EqualTo(0.0))
    end
    evaluator =
        MOI.Nonlinear.Evaluator(nlp, MOI.Nonlinear.SparseReverseMode(), x)
    MOI.initialize(evaluator, [:Jac])
    J_structure = MOI.jacobian_structure(evaluator)
    forward_perm = sortperm(J_structure; by = reverse)
    inverse_perm = invperm(forward_perm)
    jacobian_called = false
    function F(::Cint, x::Vector{Cdouble}, f::Vector{Cdouble})
        MOI.eval_constraint(evaluator, f, x)
        return Cint(0)
    end
    function J(
        ::Cint,
        nnz::Cint,
        x::Vector{Cdouble},
        col::Vector{Cint},
        len::Vector{Cint},
        row::Vector{Cint},
        data::Vector{Cdouble},
    )
        if !jacobian_called
            k = 1
            last_col = 0
            for p in forward_perm
                r, c = J_structure[p]
                if c != last_col
                    col[c], len[c], last_col = k, 0, c
                end
                len[c] += 1
                row[k] = r
                k += 1
            end
            jacobian_called = true
            @assert nnz == k - 1
        end
        MOI.eval_constraint_jacobian(evaluator, view(data, inverse_perm), x)
        return Cint(0)
    end
    return F, J, length(J_structure)
end

_finite(x, y) = isfinite(x) ? x : y

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
        initial[i] = something(z, _finite(l, _finite(u, 0.0)))
    end
    return lower, upper, initial
end

function MOI.optimize!(model::Optimizer)
    con_types = MOI.get(model, MOI.ListOfConstraintTypesPresent())
    S = MOI.Complements
    F, J, nnz = if (MOI.VectorNonlinearFunction, S) in con_types ||
                   (MOI.VectorQuadraticFunction{Float64}, S) in con_types
        _F_nonlinear_operator(model)
    else
        _F_linear_operator(model)
    end
    model.ext[:solution] = nothing
    lower, upper, initial = _bounds_and_starting(model)
    status, x, info = solve_mcp(
        F,
        J,
        lower,
        upper,
        initial;
        nnz = nnz,
        silent = model.ext[:silent],
        jacobian_structure_constant = true,
        jacobian_data_contiguous = true,
        [k => v for (k, v) in model.ext[:kwargs]]...,
    )
    model.ext[:solution] = Solution(status, x, info)
    return
end

const _MCP_TERMINATION_STATUS_MAP =
    Dict{MCP_Termination,Tuple{MOI.TerminationStatusCode,String}}(
        MCP_Solved => (MOI.LOCALLY_SOLVED, "The problem was solved"),
        MCP_NoProgress => (MOI.SLOW_PROGRESS, "A stationary point was found"),
        MCP_MajorIterationLimit =>
            (MOI.ITERATION_LIMIT, "Major iteration limit met"),
        MCP_MinorIterationLimit =>
            (MOI.ITERATION_LIMIT, "Cumulative minor iterlim met"),
        MCP_TimeLimit => (MOI.TIME_LIMIT, "Ran out of time"),
        MCP_UserInterrupt => (MOI.INTERRUPTED, "Control-C, typically"),
        MCP_BoundError => (MOI.INVALID_MODEL, "Problem has a bound error"),
        MCP_DomainError =>
            (MOI.NUMERICAL_ERROR, "Could not find a starting point"),
        MCP_Infeasible => (MOI.INFEASIBLE, "Problem has no solution"),
        MCP_Error => (MOI.OTHER_ERROR, "An error occured within the code"),
        MCP_LicenseError => (MOI.OTHER_ERROR, "License could not be found"),
        MCP_OK => (MOI.OTHER_ERROR, ""),
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
    model::Optimizer,
    attr::MOI.VariablePrimal,
    x::MOI.VariableIndex,
)
    MOI.check_result_index_bounds(model, attr)
    return solution(model).x[x.value]
end

function MOI.get(model::Optimizer, attr::MOI.PrimalStatus)
    if solution(model) === nothing || attr.result_index != 1
        return MOI.NO_SOLUTION
    end
    if MOI.get(model, MOI.TerminationStatus()) == MOI.LOCALLY_SOLVED
        return MOI.FEASIBLE_POINT
    end
    return MOI.UNKNOWN_RESULT_STATUS
end

MOI.get(::Optimizer, ::MOI.DualStatus) = MOI.NO_SOLUTION

function MOI.get(model::Optimizer, ::MOI.SolveTimeSec)
    return solution(model).info.total_time
end
