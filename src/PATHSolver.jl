# Copyright (c) 2016 Changhyun Kwon, Oscar Dowson, and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module PATHSolver

import LazyArtifacts
import MathOptInterface as MOI
import SparseArrays

function _get_artifact_path(file)
    root = LazyArtifacts.artifact"PATHSolver"
    if Sys.iswindows()  # There's a permission error with the artifact
        chmod(root, 0o755; recursive = true)
    end
    triplet = join(split(Base.BUILD_TRIPLET, "-")[1:3], "-")
    ext = ifelse(Sys.iswindows(), "dll", ifelse(Sys.isapple(), "dylib", "so"))
    filename = joinpath(root, triplet, "$file.$ext")
    if !isfile(filename)
        error("Unsupported platform: $triplet")
    end
    return filename
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
