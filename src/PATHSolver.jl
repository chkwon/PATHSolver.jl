module PATHSolver

include("FunctionWrappersQuickFix.jl")

using ForwardDiff
using .FunctionWrappersQuickFix: FunctionWrapper
using SparseArrays
using Random
using LinearAlgebra

const depsfile = joinpath(@__DIR__, "..", "deps", "deps.jl")
if isfile(depsfile)
    include(depsfile)
else
    error("PATHSolver not properly installed. Please re-build PATHSolver.")
end

export solveMCP, solveLCP, options

# Global function pointers for the user-supplied function and jacobian evaluators.
const user_f = Ref(FunctionWrapper{Vector{Cdouble}, Tuple{Vector{Cdouble}}}(identity))
# The annotated SparseMatrixCSC return type will automatically convert the
# jacobian into the correct sparse form for PATH
const user_j = Ref(FunctionWrapper{SparseMatrixCSC{Cdouble, Cint}, Tuple{Vector{Cdouble}}}(identity))

const cached_J = [convert(SparseMatrixCSC{Cdouble, Cint}, zeros(0, 0))]
const cached_J_filled = Ref(false)

const status =
   [  :Solved,                          # 1 - solved
      :StationaryPointFound,            # 2 - stationary point found
      :MajorIterationLimit,             # 3 - major iteration limit
      :CumulativeMinorIterationLimit,   # 4 - cumulative minor iteration limit
      :TimeLimit,                       # 5 - time limit
      :UserInterrupt,                   # 6 - user interrupt
      :BoundError,                      # 7 - bound error (lb is not less than ub)
      :DomainError,                     # 8 - domain error (could not find a starting point)
      :InternalError                    # 9 - internal error
  ]

count_nonzeros(M::AbstractSparseMatrix) = nnz(M)
count_nonzeros(M::AbstractMatrix) = count(x -> x != 0, M) # fallback for dense matrices



###############################################################################
# wrappers for callback functions
###############################################################################
# static int (*f_eval)(int n, double *z, double *f);
# static int (*j_eval)(int n, int nnz, double *z, int *col_start, int *col_len,
      # int *row, double *data);
function f_user_wrap(n::Cint, z_ptr::Ptr{Cdouble}, f_ptr::Ptr{Cdouble})
  z = unsafe_wrap(Array{Cdouble}, z_ptr, Int(n), own=false)
  f = unsafe_wrap(Array{Cdouble}, f_ptr, Int(n), own=false)
  f .= user_f[](z)
  return Cint(0)
end

function j_user_wrap(n::Cint, expected_nnz::Cint, z_ptr::Ptr{Cdouble},
                     col_start_ptr::Ptr{Cint}, col_len_ptr::Ptr{Cint},
                     row_ptr::Ptr{Cint}, data_ptr::Ptr{Cdouble})

  z = unsafe_wrap(Array{Cdouble}, z_ptr, Int(n), own=false)
  J::SparseMatrixCSC{Cdouble, Cint} = user_j[](z)
  if nnz(J) > expected_nnz
    println("nnz(J) = ", nnz(J))
    println("expected_nnz = ", expected_nnz)
    error("Evaluated jacobian has more nonzero entries than were initially provided in solveMCP(). Try solveMCP(..., nnz=n^2).")
  end
  load_sparse_matrix(J, n, expected_nnz, col_start_ptr, col_len_ptr, row_ptr, data_ptr)
  return Cint(0)
end

function cached_j_user_wrap(n::Cint, expected_nnz::Cint, z_ptr::Ptr{Cdouble},
                     col_start_ptr::Ptr{Cint}, col_len_ptr::Ptr{Cint},
                     row_ptr::Ptr{Cint}, data_ptr::Ptr{Cdouble})
  if !(cached_J_filled[])
    load_sparse_matrix(cached_J[], n, expected_nnz, col_start_ptr, col_len_ptr, row_ptr, data_ptr)
    cached_J_filled[] = true
  end
  return Cint(0)
end

function load_sparse_matrix(J::SparseMatrixCSC, n::Cint, expected_nnz::Cint,
                            col_start_ptr::Ptr{Cint}, col_len_ptr::Ptr{Cint},
                            row_ptr::Ptr{Cint}, data_ptr::Ptr{Cdouble})
  # Transfer data from the computed jacobian into the sparse format that PATH
  # expects. Fortunately, PATH uses a compressed-sparse-column storage which
  # is compatible with Julia's default SparseMatrixCSC format.

  # col_start in PATH corresponds to J.colptr[1:end-1]
  col_start = unsafe_wrap(Array{Cint}, col_start_ptr, Int(n), own=false)
  # col_len in PATH corresponds to diff(J.colptr)
  col_len = unsafe_wrap(Array{Cint}, col_len_ptr, Int(n), own=false)
  # row in PATH corresponds to rowvals(J)
  row = unsafe_wrap(Array{Cint}, row_ptr, Int(expected_nnz), own=false)
  # data in PATH corresponds to nonzeros(J)
  data = unsafe_wrap(Array{Cdouble}, data_ptr, Int(expected_nnz), own=false)

  @inbounds for i in 1:n
    col_start[i] = J.colptr[i]
    col_len[i] = J.colptr[i + 1] - J.colptr[i]
  end

  rv = rowvals(J)
  nz = nonzeros(J)
  num_nonzeros = nnz(J)
  @inbounds for i in 1:num_nonzeros
    row[i] = rv[i]
    data[i] = nz[i]
  end
end





###############################################################################
# solveMCP
###############################################################################


# solveMCP without z0, without j_eval
function solveMCP(f_eval::Function,
                  lb::AbstractVector{T}, ub::AbstractVector{T},
                  var_name::AbstractVector{S}=String[],
                  con_name::AbstractVector{S}=String[];
                  nnz=-1) where {T <: Number, S <: String}

  z0 = (lb + ub) ./ 2
  return solveMCP(f_eval, lb, ub, z0, var_name, con_name; nnz=nnz)
end

# solveMCP without z0, with j_eval
function solveMCP(f_eval::Function, j_eval::Function,
                  lb::AbstractVector{T}, ub::AbstractVector{T},
                  var_name::AbstractVector{S}=String[],
                  con_name::AbstractVector{S}=String[];
                  nnz=-1) where {T <: Number, S <: String}

  z0 = (lb + ub) ./ 2
  return solveMCP(f_eval, j_eval, lb, ub, z0, var_name, con_name; nnz=nnz)
end


# solveMCP with z0, without j_eval
function solveMCP(f_eval::Function,
                  lb::AbstractVector{T}, ub::AbstractVector{T}, z0::AbstractVector{T},
                  var_name::AbstractVector{S}=String[],
                  con_name::AbstractVector{S}=String[];
                  nnz=-1) where {T <: Number, S <: String}

  j_eval = x -> ForwardDiff.jacobian(f_eval, x)
  return solveMCP(f_eval, j_eval, lb, ub, z0, var_name, con_name; nnz=nnz)
end


# Full implementation of solveMCP  / solveMCP with z0, with j_eval
function solveMCP(f_eval::Function, j_eval::Function,
                  lb::AbstractVector{T}, ub::AbstractVector{T}, z0::AbstractVector{T},
                  var_name::AbstractVector{S}=String[],
                  con_name::AbstractVector{S}=String[];
                  nnz=-1) where {T <: Number, S <: String}

  if length(var_name)==0
    var_name = C_NULL
  end

  if length(con_name)==0
    con_name = C_NULL
  end

  user_f[] = f_eval
  user_j[] = j_eval
  f_user_cb = @cfunction(f_user_wrap, Cint, (Cint, Ptr{Cdouble}, Ptr{Cdouble}))
  j_user_cb = @cfunction(j_user_wrap, Cint, (Cint, Cint, Ptr{Cdouble}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}))

  n = length(lb)
  z = max.(lb, min.(ub, z0))
  f = zeros(n)

  if nnz == -1
    # overestimating number of nonzeros in Jacobian
    nnz = max( count_nonzeros(j_eval(lb)), count_nonzeros(j_eval(ub)) )
    nnz = max( nnz, count_nonzeros(j_eval(z)) )
    for i in 1:2
      z_rand = max.(lb, min.(ub, rand(Float64, n)))
      nnz_rand = count_nonzeros(j_eval(z_rand))
      nnz = max( nnz, nnz_rand )
    end
    nnz = min( 2 * nnz, n * n )
  end

  t = ccall( (:path_main, libpath47julia), Cint,
          (Cint, Cint,
           Ptr{Cdouble}, Ptr{Cdouble},
           Ptr{Cdouble}, Ptr{Cdouble},
           Ptr{Ptr{Cchar}}, Ptr{Ptr{Cchar}},
           Ptr{Cvoid}, Ptr{Cvoid}),
           n, nnz, z, f, lb, ub, var_name, con_name, f_user_cb, j_user_cb)

  remove_option_file()
  return status[t], z, f
end






###############################################################################
# solveLCP, LCP functions
###############################################################################


# solveLCP without z, without M
function solveLCP(f_eval::Function,
                  lb::AbstractVector{T}, ub::AbstractVector{T},
                  var_name::AbstractVector{S}=String[],
                  con_name::AbstractVector{S}=String[];
                  lcp_check=false) where {T <: Number, S <: String}

    return solveLCP(f_eval, lb, ub, copy(lb), var_name, con_name, lcp_check=lcp_check)
end

# solveLCP with z0, without M
function solveLCP(f_eval::Function,
                  lb::AbstractVector{T}, ub::AbstractVector{T}, z0::AbstractVector{T},
                  var_name::AbstractVector{S}=String[],
                  con_name::AbstractVector{S}=String[];
                  lcp_check=false) where {T <: Number, S <: String}

  J = ForwardDiff.jacobian(f_eval, lb)
  if lcp_check
      Jr = ForwardDiff.jacobian(f_eval, rand(Float64, size(lb)))
      if opnorm(J-Jr, 1) > 1e-8
          error("The problem does not seem linear. Use `solveMCP()` instead.")
      end
  end

  return solveLCP(f_eval, J, lb, ub, z0, var_name, con_name)
end

# solveLCP without z, with M
function solveLCP(f_eval::Function, M::AbstractMatrix,
                  lb::AbstractVector{T}, ub::AbstractVector{T},
                  var_name::AbstractVector{S}=String[],
                  con_name::AbstractVector{S}=String[];
                  lcp_check=false) where {T <: Number, S <: String}

    return solveLCP(f_eval, M, lb, ub, copy(lb), var_name, con_name, lcp_check=lcp_check)
end


# Full implmentation of solveLCP / solveLCP with z0, with M
function solveLCP(f_eval::Function, M::AbstractMatrix,
                  lb::AbstractVector{T}, ub::AbstractVector{T}, z0::AbstractVector{T},
                  var_name::AbstractVector{S}=String[],
                  con_name::AbstractVector{S}=String[];
                  lcp_check=false) where {T <: Number, S <: String}

  if length(var_name)==0
      var_name = C_NULL
  end

  if length(con_name)==0
      con_name = C_NULL
  end

  if lcp_check
      J = ForwardDiff.jacobian(f_eval, lb)
      if opnorm(J-M, 1) > 1e-8
          # warn("The user supplied Jacobian does not match with the result by FowardDiff.jacobian(). It proceeds with the user supplied Jacobian.")
          error("The user supplied Jacobian does not match with the result by FowardDiff.jacobian().")
      end
  end

  user_f[] = f_eval
  cached_J[] = M
  cached_J_filled[] = false
  f_user_cb = @cfunction(f_user_wrap, Cint, (Cint, Ptr{Cdouble}, Ptr{Cdouble}))
  j_user_cb = @cfunction(cached_j_user_wrap, Cint, (Cint, Cint, Ptr{Cdouble}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}))

  n = length(lb)
  z = max.(lb, min.(ub, z0))
  f = zeros(n)

  nnzs = count_nonzeros(M)

  t = ccall( (:path_main, libpath47julia), Cint,
          (Cint, Cint,
           Ptr{Cdouble}, Ptr{Cdouble},
           Ptr{Cdouble}, Ptr{Cdouble},
           Ptr{Ptr{Cchar}}, Ptr{Ptr{Cchar}},
           Ptr{Cvoid}, Ptr{Cvoid}),
           n, nnzs, z, f, lb, ub, var_name, con_name, f_user_cb, j_user_cb)

  remove_option_file()
  return status[t], z, f
end







###############################################################################
# handling PATH options
###############################################################################

function remove_option_file()
  if isfile("path.opt")
    rm("path.opt")
  end
end

function options(;kwargs...)
  opt_file = open("path.opt", "w")
  println(opt_file, "* Generated by PATHSolver.jl. Do not edit.")
  for (key, value) in kwargs
    println(opt_file, key, " ", value)
  end
  close(opt_file)
end










end # Module
