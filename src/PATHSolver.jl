module PATHSolver

using ForwardDiff

if isfile(joinpath(dirname(dirname(@__FILE__)), "deps", "deps.jl"))
    include(joinpath(dirname(dirname(@__FILE__)), "deps", "deps.jl"))
else
    error("PATHSolver not properly installed. Please run Pkg.build(\"PATHSolver\")")
end




export solveMCP


function solveMCP(f_eval::Function, lb::Vector, ub::Vector)
    j_eval = ForwardDiff.jacobian(f_eval)
    return solveMCP(f_eval, j_eval, lb, ub)
end

function solveMCP(f_eval::Function, j_eval::Function, lb::Vector, ub::Vector)

    global user_f = f_eval
    global user_j = j_eval

    f_user_cb = cfunction(f_user_wrap, Cint, (Cint, Ptr{Cdouble}, Ptr{Cdouble}))
    j_user_cb = cfunction(j_user_wrap, Cint, (Cint, Cint, Ptr{Cdouble}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}))

    n = length(lb)
    z = copy(lb)
    f = zeros(n)

    J0 = j_eval(z)
    s_col, s_len, s_row, s_data = sparse_matrix(J0)
    nnz = length(s_data)

    t = ccall( (:path_solver, "libpath47julia"), Cint,
                (Cint, Cint,
                 Ptr{Cdouble}, Ptr{Cdouble},
                 Ptr{Cdouble}, Ptr{Cdouble},
                 Ptr{Void},Ptr{Void}),
                 n, nnz, z, f, lb, ub, f_user_cb, j_user_cb)

    return z, f

end




###############################################################################
# wrappers for callback functions
###############################################################################
# static int (*f_eval)(int n, double *z, double *f);
# static int (*j_eval)(int n, int nnz, double *z, int *col_start, int *col_len,
            # int *row, double *data);

function f_user_wrap(n::Cint, z::Ptr{Cdouble}, f::Ptr{Cdouble})
    F = user_f(pointer_to_array(z, Int(n)))
    unsafe_store_vector!(f, F)
    return Cint(0)
end

function j_user_wrap(n::Cint, nnz::Cint, z::Ptr{Cdouble},
    col_start::Ptr{Cint}, col_len::Ptr{Cint}, row::Ptr{Cint}, data::Ptr{Cdouble})

    J = user_j(pointer_to_array(z, Int(n)) )

    s_col, s_len, s_row, s_data = sparse_matrix(J)

    unsafe_store_vector!(col_start, s_col)
    unsafe_store_vector!(col_len, s_len)
    unsafe_store_vector!(row, s_row)
    unsafe_store_vector!(data, s_data)

    return Cint(0)
end
###############################################################################




###############################################################################
# Converting the Jacobian matrix to the sparse matrix format of the PATH Solver
###############################################################################
function sparse_matrix(A::AbstractSparseArray)
    m, n = size(A)
    @assert m==n

    col_start = Array{Int}(n)
    col_len = Array{Int}(n)
    row = Array{Int}(0)
    data = Array{Float64}(0)
    for j in 1:n
        if j==1
            col_start[j] = 1
        else
            col_start[j] = col_start[j-1] + col_len[j-1]
        end

        col_len[j] = 0
        for i in 1:n
            if A[i,j] != 0.0
                col_len[j] += 1
                push!(row, i)
                push!(data, A[i,j])
            end
        end
    end

    return col_start, col_len, row, data
end

function sparse_matrix(A::Matrix)
    return sparse_matrix(sparse(A))
    # m, n = size(A)
    # @assert m==n
    #
    # col_start = Array{Int}(n)
    # col_len = Array{Int}(n)
    # row = Array{Int}(0)
    # data = Array{Float64}(0)
    # for j in 1:n
    #     if j==1
    #         col_start[j] = 1
    #     else
    #         col_start[j] = col_start[j-1] + col_len[j-1]
    #     end
    #
    #     col_len[j] = 0
    #     for i in 1:n
    #         if A[i,j] != 0.0
    #             col_len[j] += 1
    #             push!(row, i)
    #             push!(data, A[i,j])
    #         end
    #     end
    # end
    #
    # return col_start, col_len, row, data
end
###############################################################################






function unsafe_store_vector!(x_ptr::Ptr{Cint}, x_val::Vector)
    for i in 1:length(x_val)
        unsafe_store!(x_ptr, x_val[i], i)
    end
    return
end

function unsafe_store_vector!(x_ptr::Ptr{Cdouble}, x_val::Vector)
    for i in 1:length(x_val)
        unsafe_store!(x_ptr, x_val[i], i)
    end
    return
end



end # Module
