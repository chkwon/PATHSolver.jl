module PATHSolver

using ForwardDiff
using FunctionWrappers: FunctionWrapper

if isfile(joinpath(dirname(dirname(@__FILE__)), "deps", "deps.jl"))
  include(joinpath(dirname(dirname(@__FILE__)), "deps", "deps.jl"))
else
  error("PATHSolver not properly installed. Please run Pkg.build(\"PATHSolver\")")
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

function solveMCP(f_eval::Function, lb::Vector, ub::Vector, z::Vector, var_name=C_NULL, con_name=C_NULL)
  return solveMCP(f_eval, lb, ub, var_name, con_name, z)
end

function solveMCP(f_eval::Function, j_eval::Function, lb::Vector, ub::Vector, z::Vector, var_name=C_NULL, con_name=C_NULL)
  return solveMCP(f_eval, j_eval, lb, ub, var_name, con_name, z)
end

function solveMCP(f_eval::Function, lb::Vector, ub::Vector, var_name=C_NULL, con_name=C_NULL, z::Vector=copy(lb))
  j_eval = x -> ForwardDiff.jacobian(f_eval, x)
  return solveMCP(f_eval, j_eval, lb, ub, var_name, con_name, z)
end

function solveMCP(f_eval::Function, j_eval::Function, lb::Vector, ub::Vector, var_name=C_NULL, con_name=C_NULL, z::Vector=copy(lb))
  user_f[] = f_eval
  user_j[] = j_eval
  f_user_cb = cfunction(f_user_wrap, Cint, (Cint, Ptr{Cdouble}, Ptr{Cdouble}))
  j_user_cb = cfunction(j_user_wrap, Cint, (Cint, Cint, Ptr{Cdouble}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}))

  n = length(lb)
  z = copy(z)
  for i = 1:n
      if lb[i] > z[i]
        z[i] = lb[i]
    elseif ub[i] < z[i]
        z[i] = ub[i]
    end
  end
  f = zeros(n)

  J0 = j_eval(z)
  nnz = count_nonzeros(J0)

  t = ccall( (:path_main, "libpath47julia"), Cint,
          (Cint, Cint,
           Ptr{Cdouble}, Ptr{Cdouble},
           Ptr{Cdouble}, Ptr{Cdouble},
           Ptr{Ptr{Cchar}}, Ptr{Ptr{Cchar}},
           Ptr{Void}, Ptr{Void}),
           n, nnz, z, f, lb, ub, var_name, con_name, f_user_cb, j_user_cb)

  remove_option_file()
  return status[t], z, f
end

function solveLCP(f_eval::Function, lb::AbstractVector, ub::AbstractVector, z::AbstractVector=copy(lb), var_name=C_NULL, con_name=C_NULL; lcp_check=false,)
  return solveLCP(f_eval, lb, ub, var_name, con_name, z)
end

function solveLCP(f_eval::Function, M::AbstractMatrix, lb::AbstractVector, ub::AbstractVector, z::AbstractVector=copy(lb), var_name=C_NULL, con_name=C_NULL; lcp_check=false)
  return solveLCP(f_eval, M, lb, ub, var_name, con_name, z)
end

function solveLCP(f_eval::Function, lb::AbstractVector, ub::AbstractVector,
                  var_name=C_NULL, con_name=C_NULL, z::AbstractVector = copy(lb); lcp_check=false)
  J = ForwardDiff.jacobian(f_eval, lb)
  if lcp_check
      Jr = ForwardDiff.jacobian(f_eval, rand(size(lb)))
      if norm(J-Jr, 1) > 1e-8
          error("The problem does not seem linear. Use `solveMCP()` instead.")
      end
  end

  solveLCP(f_eval, J, lb, ub, var_name, con_name, z)
end

function solveLCP(f_eval::Function, M::AbstractMatrix,
                  lb::AbstractVector, ub::AbstractVector,
                  var_name=C_NULL, con_name=C_NULL, z::AbstractVector = copy(lb); lcp_check=false)

  if lcp_check
      J = ForwardDiff.jacobian(f_eval, lb)
      if norm(J-M, 1) > 1e-8
          # warn("The user supplied Jacobian does not match with the result by FowardDiff.jacobian(). It proceeds with the user supplied Jacobian.")
          error("The user supplied Jacobian does not match with the result by FowardDiff.jacobian().")
      end
  end

  user_f[] = f_eval
  cached_J[] = M
  cached_J_filled[] = false
  f_user_cb = cfunction(f_user_wrap, Cint, (Cint, Ptr{Cdouble}, Ptr{Cdouble}))
  j_user_cb = cfunction(cached_j_user_wrap, Cint, (Cint, Cint, Ptr{Cdouble}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}))

  n = length(lb)
  z = copy(z)
  for i = 1:n
      if lb[i] > z[i]
        z[i] = lb[i]
    elseif ub[i] < z[i]
        z[i] = ub[i]
    end
  end
  f = zeros(n)

  nnz = count_nonzeros(M)
  t = ccall( (:path_main, "libpath47julia"), Cint,
          (Cint, Cint,
           Ptr{Cdouble}, Ptr{Cdouble},
           Ptr{Cdouble}, Ptr{Cdouble},
           Ptr{Ptr{Cchar}}, Ptr{Ptr{Cchar}},
           Ptr{Void}, Ptr{Void}),
           n, nnz, z, f, lb, ub, var_name, con_name, f_user_cb, j_user_cb)
  remove_option_file()
  return status[t], z, f
end

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


###############################################################################
# wrappers for callback functions
###############################################################################
# static int (*f_eval)(int n, double *z, double *f);
# static int (*j_eval)(int n, int nnz, double *z, int *col_start, int *col_len,
      # int *row, double *data);
function f_user_wrap(n::Cint, z_ptr::Ptr{Cdouble}, f_ptr::Ptr{Cdouble})
  z = unsafe_wrap(Array{Cdouble}, z_ptr, Int(n), false)
  f = unsafe_wrap(Array{Cdouble}, f_ptr, Int(n), false)
  f .= user_f[](z)
  return Cint(0)
end

function j_user_wrap(n::Cint, expected_nnz::Cint, z_ptr::Ptr{Cdouble},
                     col_start_ptr::Ptr{Cint}, col_len_ptr::Ptr{Cint},
                     row_ptr::Ptr{Cint}, data_ptr::Ptr{Cdouble})

  z = unsafe_wrap(Array{Cdouble}, z_ptr, Int(n), false)
  J::SparseMatrixCSC{Cdouble, Cint} = user_j[](z)
  if nnz(J) > expected_nnz
    error("Evaluated jacobian has more nonzero entries than were initially provided in solveMCP()")
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
  col_start = unsafe_wrap(Array{Cint}, col_start_ptr, Int(n), false)
  # col_len in PATH corresponds to diff(J.colptr)
  col_len = unsafe_wrap(Array{Cint}, col_len_ptr, Int(n), false)
  # row in PATH corresponds to rowvals(J)
  row = unsafe_wrap(Array{Cint}, row_ptr, Int(expected_nnz), false)
  # data in PATH corresponds to nonzeros(J)
  data = unsafe_wrap(Array{Cdouble}, data_ptr, Int(expected_nnz), false)

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



end # Module
