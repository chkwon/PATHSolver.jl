"""
    @c_api(f, return_type, arg_types, args...)

A `ccall` wrapper for PATH functions.
"""
macro c_api(f, args...)
    f = "$(f)"
    args = esc.(args)
    return quote
        ccall(($f, $PATH_SOLVER), $(args...))
    end
end

# PATH uses the Float64 value 1e20 to represent +infinity.
const INFINITY = 1e20

###
### Options.h
###

mutable struct Options
    ptr::Ptr{Cvoid}
    function Options(ptr::Ptr{Cvoid})
        o = new(ptr)
        finalizer(c_api_Options_Destroy, o)
        return o
    end
end

function c_api_Options_Create()
    ptr = @c_api(Options_Create, Ptr{Cvoid}, ())
    return Options(ptr)
end

function c_api_Options_Destroy(o::Options)
    @c_api(Options_Destroy, Cvoid, (Ptr{Cvoid},), o.ptr)
    return
end

function c_api_Options_Default(o::Options)
    @c_api(Options_Default, Cvoid, (Ptr{Cvoid},), o.ptr)
    return
end

function c_api_Options_Display(o::Options)
    @c_api(Options_Read, Cvoid, (Ptr{Cvoid},), o.ptr)
    return
end

function c_api_Options_Read(o::Options, filename::String)
    @c_api(Options_Read, Cvoid, (Ptr{Cvoid}, Ptr{Cchar}), o.ptr, filename)
    return
end

function c_api_Path_AddOptions(o::Options)
    @c_api(Path_AddOptions, Cvoid, (Ptr{Cvoid},), o.ptr)
    return
end

###
### MCP_Interface.h
###

mutable struct InterfaceData
    n::Cint
    nnz::Cint
    z::Vector{Cdouble}
    lb::Vector{Cdouble}
    ub::Vector{Cdouble}
    F::Function
    J::Function
    c_problem_size::Ptr{Cvoid}
    c_bounds::Ptr{Cvoid}
    c_function_eval::Ptr{Cvoid}
    c_jacobian_eval::Ptr{Cvoid}
end

function _c_problem_size(
    id_ptr::Ptr{Cvoid}, n_ptr::Ptr{Cint}, nnz_ptr::Ptr{Cint}
)
    id_data = unsafe_pointer_to_objref(id_ptr)::InterfaceData
    n = unsafe_wrap(Array{Cint}, n_ptr, 1)
    n[1] = id_data.n
    nnz = unsafe_wrap(Array{Cint}, nnz_ptr, 1)
    nnz[1] = id_data.nnz
    return
end

function _c_bounds(
    id_ptr::Ptr{Cvoid},
    n::Cint,
    z_ptr::Ptr{Cdouble},
    lb_ptr::Ptr{Cdouble},
    ub_ptr::Ptr{Cdouble},
)
    id_data = unsafe_pointer_to_objref(id_ptr)::InterfaceData
    z = unsafe_wrap(Array{Cdouble}, z_ptr, Int(n))
    lb = unsafe_wrap(Array{Cdouble}, lb_ptr, Int(n))
    ub = unsafe_wrap(Array{Cdouble}, ub_ptr, Int(n))
    for i in 1:n
        z[i] = id_data.z[i]
        lb[i] = id_data.lb[i]
        ub[i] = id_data.ub[i]
    end
    return
end

function _c_function_evaluation(
    id_ptr::Ptr{Cvoid}, n::Cint, x_ptr::Ptr{Cdouble}, f_ptr::Ptr{Cdouble}
)
    id_data = unsafe_pointer_to_objref(id_ptr)::InterfaceData
    x = unsafe_wrap(Array{Cdouble}, x_ptr, Int(n))
    f = unsafe_wrap(Array{Cdouble}, f_ptr, Int(n))
    err = id_data.F(n, x, f)
    return err
end

function _c_jacobian_evaluation(
    id_ptr::Ptr{Cvoid},
    n::Cint,
    x_ptr::Ptr{Cdouble},
    wantf::Cint,
    f_ptr::Ptr{Cdouble},
    nnz_ptr::Ptr{Cint},
    col_ptr::Ptr{Cint},
    len_ptr::Ptr{Cint},
    row_ptr::Ptr{Cint},
    data_ptr::Ptr{Cdouble}
)
    id_data = unsafe_pointer_to_objref(id_ptr)::InterfaceData
    x = unsafe_wrap(Array{Cdouble}, x_ptr, n)
    err = Cint(0)
    if wantf > 0
        f = unsafe_wrap(Array{Cdouble}, f_ptr, n)
        err += id_data.F(n, x, f)
    end
    nnz = unsafe_wrap(Array{Cint}, nnz_ptr, 1)
    col = unsafe_wrap(Array{Cint}, col_ptr, n)
    len = unsafe_wrap(Array{Cint}, len_ptr, n)
    row = unsafe_wrap(Array{Cint}, row_ptr, nnz[1])
    data = unsafe_wrap(Array{Cdouble}, data_ptr, nnz[1])
    err += id_data.J(n, nnz[1], x, col, len, row, data)
    nnz[1] = sum(len)
    return err
end

"""
    MCP_Interface

A storage struct that is used to pass problem-specific functions to PATH.
"""
mutable struct MCP_Interface
    interface_data::Ptr{Cvoid}
    problem_size::Ptr{Cvoid}
    bounds::Ptr{Cvoid}
    function_evaluation::Ptr{Cvoid}
    jacobian_evaluation::Ptr{Cvoid}
    start::Ptr{Cvoid}
    finish::Ptr{Cvoid}
    variable_name::Ptr{Cvoid}
    constraint_name::Ptr{Cvoid}
    basis::Ptr{Cvoid}

    function MCP_Interface(interface_data::InterfaceData)
        return new(
            pointer_from_objref(interface_data),
            interface_data.c_problem_size,
            interface_data.c_bounds,
            interface_data.c_function_eval,
            interface_data.c_jacobian_eval,
            C_NULL,
            C_NULL,
            C_NULL,
            C_NULL,
            C_NULL
        )
    end
end

mutable struct MCP
    n::Int
    ptr::Ptr{Cvoid}
    id_data::Union{Nothing, InterfaceData}
    function MCP(n::Int, ptr::Ptr{Cvoid})
        m = new(n, ptr, nothing)
        finalizer(c_api_MCP_Destroy, m)
        return m
    end
end

function c_api_MCP_Create(n::Int, nnz::Int)
    ptr = @c_api(MCP_Create, Ptr{Cvoid}, (Cint, Cint), n, nnz)
    return MCP(n, ptr)
end

function c_api_MCP_Destroy(m::MCP)
    @c_api(MCP_Destroy, Cvoid, (Ptr{Cvoid},), m.ptr)
    return
end

function c_api_MCP_SetInterface(m::MCP, interface::MCP_Interface)
    @c_api(
        MCP_SetInterface,
        Cvoid,
        (Ptr{Cvoid}, Ref{MCP_Interface}),
        m.ptr, interface
    )
    return
end

function c_api_MCP_GetX(m::MCP)
    ptr = @c_api(MCP_GetX, Ptr{Cdouble}, (Ptr{Cvoid},), m.ptr)
    return copy(unsafe_wrap(Array, ptr, m.n))
end

###
### Types.h
###

@enum(
    MCP_Termination,
    MCP_Solved = 1,
    MCP_NoProgress,
    MCP_MajorIterationLimit,
    MCP_MinorIterationLimit,
    MCP_TimeLimit,
    MCP_UserInterrupt,
    MCP_BoundError,
    MCP_DomainError,
    MCP_Infeasible,
    MCP_Error,
    MCP_LicenseError,
    MCP_OK
)

mutable struct Information
    # Double residual;	     /* Value of residual at final point             */
    residual::Cdouble
    # Double distance;	     /* Distance between initial and final point     */
    distance::Cdouble
    # Double steplength;	     /* Steplength taken                             */
    steplength::Cdouble
    # Double total_time;	     /* Amount of time spent in the code             */
    total_time::Cdouble

    # Double maximum_distance;   /* Maximum distance from init point allowed     */
    maximum_distance::Cdouble

    # Int major_iterations;	     /* Major iterations taken                       */
    major_iterations::Cint
    # Int minor_iterations;	     /* Minor iterations taken                       */
    mainor_iterations::Cint
    # Int crash_iterations;	     /* Crash iterations taken                       */
    crash_iterations::Cint
    # Int function_evaluations;  /* Function evaluations performed               */
    function_evaluations::Cint
    # Int jacobian_evaluations;  /* Jacobian evaluations performed               */
    jacobian_evaluations::Cint
    # Int gradient_steps;	     /* Gradient steps taken                         */
    gradient_steps::Cint
    # Int restarts;		     /* Restarts used                                */
    restarts::Cint

    # Int generate_output;       /* Mask where output can be displayed.          */
    generate_output::Cint
    # Int generated_output;      /* Mask where output displayed.                 */
    generated_output::Cint

    # Boolean forward;	     /* Move forward?                                */
    forward::Bool
    # Boolean backtrace;	     /* Back track?                                  */
    backtrace::Bool
    # Boolean gradient;	     /* Take gradient step?                          */
    gradient::Bool

    # Boolean use_start;         /* Use the starting point provided?             */
    use_start::Bool
    # Boolean use_basics;        /* Use the basis provided?                      */
    use_basics::Bool

    # Boolean used_start;        /* Was the starting point given used?           */
    used_start::Bool
    # Boolean used_basics;       /* Was the initial basis given used?            */
    used_basics::Bool

    function Information(;
        use_start::Bool = true,
    )
        return new(
            0.0, 0.0, 0.0, 0.0, 0.0,
            0, 0, 0, 0, 0, 0, 0,
            0, 0,
            false, false, false,
            use_start, false,
            false, false
        )
    end
end

###
### Path.h
###

"""
    c_api_Path_CheckLicense(n::Int, nnz::Int)

Check that the current license (stored in the environment variable
`PATH_LICENSE_STRING` if present) is valid for problems with `n` variables and
`nnz` non-zeros in the Jacobian.

Returns a nonzero value on successful completion, and a zero value on failure.
"""
function c_api_Path_CheckLicense(n::Int, nnz::Int)
    return @c_api(Path_CheckLicense, Cint, (Cint, Cint), n, nnz)
end

"""
    c_api_Path_Version()

Return a string of the PATH version.

This function is unsafe! It assumes that the string has the form `Path X.Y.ZZ`.
"""
function c_api_Path_Version()
    ptr = @c_api(Path_Version, Ptr{Cchar}, ())
    return unsafe_string(ptr)
end

"""
    c_api_Path_Solve(m::MCP, info::Information)

Returns a MCP_Termination status
"""
function c_api_Path_Solve(m::MCP, info::Information)
    return @c_api(Path_Solve, Cint, (Ptr{Cvoid}, Ref{Information}), m.ptr, info)
end

###
### Standalone interface
###

"""
    solve_mcp(;
        z::Vector{Cdouble},
        lb::Vector{Cdouble},
        ub::Vector{Cdouble},
        F::Function,
        J::Function,
        option_file::String = "",
        nnz::Int = length(lb)^2
    )

Mathematically, the mixed complementarity problem is to find an x such that
for each i, at least one of the following hold:

   1.  F_i(x) = 0, lb_i <= (x)_i <= ub_i
   2.  F_i(x) > 0, (x)_i = lb_i
   3.  F_i(x) < 0, (x)_i = ub_i

where F is a given function from R^n to R^n, and lb and ub are prescribed
lower and upper bounds.

`z` is an initial starting point for the search.

`F` is a function `F(n::Cint, x::Vector{Cdouble}, f::Vector{Cdouble})` that
should calculate the function F(x) and store the result in `f`.

If `option_file` is provided, PATH will read the options from that file.
"""
function solve_mcp(;
    lb::Vector{Cdouble},
    ub::Vector{Cdouble},
    z::Vector{Cdouble},
    F::Function,
    J::Function,
    option_file::String = "",
    nnz::Int = length(lb)^2
)
    n = length(z)
    @assert  length(z) == length(lb) == length(ub)
    if n == 0
        return MCP_Solved, nothing, nothing
    end

    # Convert `Int` to floating point for check.
    dnnz = min(1.0 * nnz, 1.0 * n^2)
    if dnnz > typemax(Cint)
        return MCP_Error, nothing, nothing
    end
    nnz = Int(dnnz + 1)

    o = c_api_Options_Create()
    c_api_Path_AddOptions(o)
    c_api_Options_Default(o)

    m = c_api_MCP_Create(n, nnz)

    m.id_data = InterfaceData(
        Cint(n),
        Cint(nnz),
        z,
        lb,
        ub,
        F,
        J,
        @cfunction(
            _c_problem_size,
            Cvoid,
            (Ptr{Cvoid}, Ptr{Cint}, Ptr{Cint})
        ),
        @cfunction(
            _c_bounds,
            Cvoid,
            (Ptr{Cvoid}, Cint, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble})
        ),
        @cfunction(
            _c_function_evaluation,
            Cint,
            (Ptr{Cvoid}, Cint, Ptr{Cdouble}, Ptr{Cdouble})
        ),
        @cfunction(
            _c_jacobian_evaluation,
            Cint,
            (
                Ptr{Cvoid}, Cint, Ptr{Cdouble}, Cint, Ptr{Cdouble},
                Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}
            )
        )
    )

    m_interface = MCP_Interface(m.id_data)
    c_api_MCP_SetInterface(m, m_interface)

    if option_file != ""
        c_api_Options_Read(o, option_file)
    end
    c_api_Options_Display(o)

    info = Information(use_start = true)

    status = c_api_Path_Solve(m, info)

    X = c_api_MCP_GetX(m)
    return MCP_Termination(status), X, info
end
