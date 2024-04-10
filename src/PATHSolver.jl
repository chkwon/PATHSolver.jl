# Copyright (c) 2016 Changhyun Kwon, Oscar Dowson, and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module PATHSolver

import LazyArtifacts
import MathOptInterface as MOI
import SparseArrays

function _get_artifact_path(filename)
    root = LazyArtifacts.artifact"PATHSolver"
    if Sys.iswindows()
        return joinpath(root, "x86_64-w64-mingw32", "$filename.dll")
    elseif Sys.isapple()
        return joinpath(root, "$(Sys.ARCH)-apple-darwin", "$filename.dylib")
    elseif Sys.islinux()
        return joinpath(root, "x86_64-linux-gnu", "$filename.so")
    else
        error("Unsupported platform.")
    end
end

function __init__()
    if haskey(ENV, "PATH_JL_LOCATION")
        global PATH_SOLVER = ENV["PATH_JL_LOCATION"]
        global LUSOL_LIBRARY_PATH = ""
    else
        global PATH_SOLVER = _get_artifact_path("libpath")
        global LUSOL_LIBRARY_PATH = _get_artifact_path("liblusol")
    end
    return
end

include("C_API.jl")
include("MOI_wrapper.jl")

end
