# PATH uses the Float64 value 1e20 to represent +infinity.
const INFINITY = 1e20

###
### License.h
###

function c_api_License_SetString(license::String)
    return ccall((:License_SetString, PATH_SOLVER), Cint, (Ptr{Cchar},), license)
end

###
### Output_Interface.h
###

const c_api_Output_Log     = Cint(1 << 0)
const c_api_Output_Status  = Cint(1 << 1)
const c_api_Output_Listing = Cint(1 << 2)

mutable struct OutputInterface
    output_data::Ptr{Cvoid}
    print::Ptr{Cvoid}
    flush::Ptr{Cvoid}
end

function _c_flush(data::Ptr{Cvoid}, mode::Cint)
    io = unsafe_pointer_to_objref(data)::IO
    flush(io)
    return
end

function _c_print(data::Ptr{Cvoid}, mode::Cint, msg::Ptr{Cchar})
    if (
        mode & c_api_Output_Log == c_api_Output_Log ||
        # TODO(odow): decide whether to print the Output_Status. It has a lot of
        # information...
        # mode & c_api_Output_Status == c_api_Output_Status ||
        mode & c_api_Output_Listing == c_api_Output_Listing
    )
        io = unsafe_pointer_to_objref(data)::IO
        print(io, unsafe_string(msg))
    end
    return
end

function OutputInterface(io)
    _C_PRINT = @cfunction(_c_print, Cvoid, (Ptr{Cvoid}, Cint, Ptr{Cchar}))
    _C_FLUSH = @cfunction(_c_flush, Cvoid, (Ptr{Cvoid}, Cint))
    return OutputInterface(pointer_from_objref(io), _C_PRINT, _C_FLUSH)
end

function c_api_Output_SetInterface(o::OutputInterface)
    return ccall(
        (:Output_SetInterface, PATH_SOLVER), Cvoid, (Ref{OutputInterface},), o
    )
end

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

Base.cconvert(::Type{Ptr{Cvoid}}, x::Options) = x
Base.unsafe_convert(::Type{Ptr{Cvoid}}, x::Options) = x.ptr


function c_api_Options_Create()
    ptr = ccall((:Options_Create, PATH_SOLVER), Ptr{Cvoid}, ())
    return Options(ptr)
end

function c_api_Options_Destroy(o::Options)
    return ccall((:Options_Destroy, PATH_SOLVER), Cvoid, (Ptr{Cvoid},), o)
end

function c_api_Options_Default(o::Options)
    return ccall((:Options_Default, PATH_SOLVER), Cvoid, (Ptr{Cvoid},), o)
end

function c_api_Options_Display(o::Options)
    return ccall((:Options_Display, PATH_SOLVER), Cvoid, (Ptr{Cvoid},), o)
end

function c_api_Options_Read(o::Options, filename::String)
    return ccall(
        (:Options_Read, PATH_SOLVER), Cvoid, (Ptr{Cvoid}, Ptr{Cchar}), o, filename
    )
end

function c_api_Path_AddOptions(o::Options)
    return ccall((:Path_AddOptions, PATH_SOLVER), Cvoid, (Ptr{Cvoid},), o)
end

###
### MCP_Interface.h
###

mutable struct InterfaceData
    n::Cint
    nnz::Cint
    F::Function
    J::Function
    lb::Vector{Cdouble}
    ub::Vector{Cdouble}
    z::Vector{Cdouble}
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
    z = unsafe_wrap(Array{Cdouble}, z_ptr, n)
    lb = unsafe_wrap(Array{Cdouble}, lb_ptr, n)
    ub = unsafe_wrap(Array{Cdouble}, ub_ptr, n)
    for i = 1:n
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
    x = unsafe_wrap(Array{Cdouble}, x_ptr, n)
    f = unsafe_wrap(Array{Cdouble}, f_ptr, n)
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
    # TODO(odow): the .h files I have don't include the hessian evaluation in
    #             MCP_Interface, but Standalone_Path.c includes it. Ask M.
    #             Ferris to look at the source.
    # Answer: there is an #ifdef to turn it on or off. In the GAMS builds it
    #         appears to be on, but we should be careful when updating PATH
    #         versions.
    hessian_evaluation::Ptr{Cvoid}
    start::Ptr{Cvoid}
    finish::Ptr{Cvoid}
    variable_name::Ptr{Cvoid}
    constraint_name::Ptr{Cvoid}
    basis::Ptr{Cvoid}

    function MCP_Interface(interface_data::InterfaceData)
        _C_PROBLEM_SIZE = @cfunction(
            _c_problem_size,
            Cvoid,
            (Ptr{Cvoid}, Ptr{Cint}, Ptr{Cint})
        )
        _C_BOUNDS = @cfunction(
            _c_bounds,
            Cvoid,
            (Ptr{Cvoid}, Cint, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble})
        )
        _C_FUNCTION_EVALUATION = @cfunction(
            _c_function_evaluation,
            Cint,
            (Ptr{Cvoid}, Cint, Ptr{Cdouble}, Ptr{Cdouble})
        )
        _C_JACOBIAN_EVALUATION = @cfunction(
            _c_jacobian_evaluation,
            Cint,
            (
                Ptr{Cvoid}, Cint, Ptr{Cdouble}, Cint, Ptr{Cdouble},
                Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}
            )
        )

        return new(
            pointer_from_objref(interface_data),
            _C_PROBLEM_SIZE,
            _C_BOUNDS,
            _C_FUNCTION_EVALUATION,
            _C_JACOBIAN_EVALUATION,
            C_NULL,
            C_NULL,  # See TODO note in definition of fields above.
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

Base.cconvert(::Type{Ptr{Cvoid}}, x::MCP) = x
Base.unsafe_convert(::Type{Ptr{Cvoid}}, x::MCP) = x.ptr

function c_api_MCP_Create(n::Int, nnz::Int)
    ptr = ccall((:MCP_Create, PATH_SOLVER), Ptr{Cvoid}, (Cint, Cint), n, nnz)
    return MCP(n, ptr)
end

function c_api_MCP_Destroy(m::MCP)
    if m.ptr === C_NULL
        return
    end
    ccall((:MCP_Destroy, PATH_SOLVER), Cvoid, (Ptr{Cvoid},), m)
    return
end

function c_api_MCP_SetInterface(m::MCP, interface::MCP_Interface)
    ccall(
        (:MCP_SetInterface, PATH_SOLVER),
        Cvoid,
        (Ptr{Cvoid}, Ref{MCP_Interface}),
        m, interface
    )
    return
end

function c_api_MCP_GetX(m::MCP)
    ptr = ccall((:MCP_GetX, PATH_SOLVER), Ptr{Cdouble}, (Ptr{Cvoid},), m)
    return copy(unsafe_wrap(Array{Cdouble}, ptr, m.n))
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
    return ccall((:Path_CheckLicense, PATH_SOLVER), Cint, (Cint, Cint), n, nnz)
end

"""
    c_api_Path_Version()

Return a string of the PATH version.
"""
function c_api_Path_Version()
    ptr = ccall((:Path_Version, PATH_SOLVER), Ptr{Cchar}, ())
    return unsafe_string(ptr)
end

"""
    c_api_Path_Solve(m::MCP, info::Information)

Returns a MCP_Termination status.
"""
function c_api_Path_Solve(m::MCP, info::Information)
    return ccall(
        (:Path_Solve, PATH_SOLVER), Cint, (Ptr{Cvoid}, Ref{Information}), m, info
    )
end

###
### Standalone interface
###

"""
    solve_mcp(
        F::Function,
        J::Function
        lb::Vector{Cdouble},
        ub::Vector{Cdouble},
        z::Vector{Cdouble};
        nnz::Int = length(lb)^2,
        silent::Bool = false,
        kwargs...
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
"""
function solve_mcp(
    F::Function,
    J::Function,
    lb::Vector{Cdouble},
    ub::Vector{Cdouble},
    z::Vector{Cdouble};
    nnz::Int = length(lb)^2,
    silent::Bool = false,
    kwargs...
)
    @assert length(z) == length(lb) == length(ub)

    out_io = silent ? IOBuffer() : stdout
    GC.@preserve out_io begin
    c_api_Output_SetInterface(OutputInterface(out_io))

    n = length(z)
    if n == 0
        return MCP_Solved, nothing, nothing
    end

    # Convert `Int` to `Float64` for check to avoid overflow.
    dnnz = min(1.0 * nnz, 1.0 * n^2)
    if dnnz > typemax(Cint)
        return MCP_Error, nothing, nothing
    end
    nnz = Int(dnnz + 1)

    o = c_api_Options_Create()
    c_api_Path_AddOptions(o)
    c_api_Options_Default(o)
    m = c_api_MCP_Create(n, nnz)
    m.id_data = InterfaceData(Cint(n), Cint(nnz), F, J, lb, ub, z)
    m_interface = MCP_Interface(m.id_data)
    c_api_MCP_SetInterface(m, m_interface)
    if length(kwargs) > 0
        mktemp() do path, io
            println(io, "* Automatically generated by PATH.jl. Do not edit.")
            for (key, val) in kwargs
                println(io, key, " ", val)
            end
            close(io)
            c_api_Options_Read(o, path)
        end
    end
    c_api_Options_Display(o)
    info = Information(use_start = true)
    status = c_api_Path_Solve(m, info)
    end  # GC.@preserve
    X = c_api_MCP_GetX(m)
    # TODO(odow): I don't know why, but manually calling MCP_Destroy was
    # necessary to avoid a segfault on Julia 1.0 when using LUSOL. I guess it's
    # something to do with the timing of when things need to get freed on the
    # PATH side? i.e., MCP_Destroy before other things?
    c_api_MCP_Destroy(m)
    m.ptr = C_NULL
    return MCP_Termination(status), X, info
end

function _linear_function(M::AbstractMatrix, q::Vector)
    if size(M, 1) != size(M, 2)
        error("M not square! size = $(size(M))")
    elseif size(M, 1) != length(q)
        error("q is wrong shape. Expected $(size(M, 1)), got $(length(q)).")
    end
    return (n::Cint, x::Vector{Cdouble}, f::Vector{Cdouble}) -> begin
        f .= M * x .+ q
        return Cint(0)
    end
end

function _linear_jacobian(M::SparseArrays.SparseMatrixCSC{Cdouble, Cint})
    if size(M, 1) != size(M, 2)
        error("M not square! size = $(size(M))")
    end
    return (
        n::Cint,
        nnz::Cint,
        x::Vector{Cdouble},
        col::Vector{Cint},
        len::Vector{Cint},
        row::Vector{Cint},
        data::Vector{Cdouble}
    ) -> begin
        @assert n == length(x) == length(col) == length(len) == size(M, 1)
        @assert nnz == length(row) == length(data)
        @assert nnz >= SparseArrays.nnz(M)
        for i = 1:n
            col[i] = M.colptr[i]
            len[i] = M.colptr[i + 1] - M.colptr[i]
        end
        for (i, v) in enumerate(SparseArrays.rowvals(M))
            row[i] = v
        end
        for (i, v) in enumerate(SparseArrays.nonzeros(M))
            data[i] = v
        end
        return Cint(0)
    end
end

"""
    solve_mcp(;
        M::SparseArrays.CompressedSparseMatrixCSC{Cdouble, Cint},
        q::Vector{Cdouble},
        lb::Vector{Cdouble},
        ub::Vector{Cdouble},
        z::Vector{Cdouble};
        kwargs...
    )

Mathematically, the mixed complementarity problem is to find an x such that
for each i, at least one of the following hold:

   1.  F_i(x) = 0, lb_i <= (x)_i <= ub_i
   2.  F_i(x) > 0, (x)_i = lb_i
   3.  F_i(x) < 0, (x)_i = ub_i

where F is a function `F(x) = M * x + q` from R^n to R^n, and lb and ub are
prescribed lower and upper bounds.

`z` is an initial starting point for the search.
"""
function solve_mcp(
    M::SparseArrays.SparseMatrixCSC{Cdouble, Cint},
    q::Vector{Cdouble},
    lb::Vector{Cdouble},
    ub::Vector{Cdouble},
    z::Vector{Cdouble};
    silent::Bool = false,
    kwargs...
)
    return solve_mcp(
        _linear_function(M, q),
        _linear_jacobian(M),
        lb,
        ub,
        z;
        nnz = SparseArrays.nnz(M),
        silent = silent,
        kwargs...
    )
end
