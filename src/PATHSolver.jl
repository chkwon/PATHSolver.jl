module PATHSolver

import MathOptInterface
import SparseArrays

include(joinpath(dirname(@__DIR__), "deps", "deps.jl"))

include("C_API.jl")
include("MOI_wrapper.jl")

end
