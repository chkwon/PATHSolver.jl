# Copyright (c) 2016 Changhyun Kwon, Oscar Dowson, and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module PATHSolver

import DataDeps
import MathOptInterface as MOI
import SparseArrays

function __init__()
    platform = if Sys.iswindows()
        "windows"
    elseif Sys.isapple()
        "macos"
    elseif Sys.islinux()
        "linux"
    else
        error("Unsupported platform.")
    end
    libpath = Dict(
        "windows" => (
            "path50.dll",
            "e227d19109f56628fccfdfedd7ecbdfd1667a3c975dd1d16a160a69d374d5474",
        ),
        "macos" => (
            "libpath50.dylib",
            "8787de93d21f49a46146ebe2ef5844d1c20a80f934a85f60164f9ddc670412f8",
        ),
        "linux" => (
            "libpath50.so",
            "8c36baaea0952729788ec8d964253305b04b0289a1d74ca5606862c9ddb8f2fd",
        ),
    )
    libpath_filename, libpath_sha256 = libpath[platform]
    DataDeps.register(
        DataDeps.DataDep(
            "libpath50",
            "The libpath50 binary from http://pages.cs.wisc.edu/~ferris",
            "http://pages.cs.wisc.edu/~ferris/path/julia/$(libpath_filename)",
            libpath_sha256,
        ),
    )
    lusol = Dict(
        "windows" => (
            "lusol.dll",
            "2e1f0ed17914ddcf1b833898731ff4b85afab0cf914e0707dcff9e4e995cebd8",
        ),
        "macos" => (
            "liblusol.dylib",
            "52d631fd3d753581c62d5b4b636e9cb3f8cc822738fe34c6879443d5b5092f12",
        ),
        "linux" => (
            "liblusol.so",
            "ca87167853cdac9d4697a51a588d13ed9a7c093219743efa1d250cb62ac3dcb7",
        ),
    )
    liblusol_filename, liblusol_sha256 = lusol[platform]
    DataDeps.register(
        DataDeps.DataDep(
            "liblusol",
            "The lusol binary for use with PATH from http://pages.cs.wisc.edu/~ferris",
            "http://pages.cs.wisc.edu/~ferris/path/julia/$(liblusol_filename)",
            liblusol_sha256,
        ),
    )
    if haskey(ENV, "PATH_JL_LOCATION")
        global PATH_SOLVER = ENV["PATH_JL_LOCATION"]
        global LUSOL_LIBRARY_PATH = ""
    else
        current = get(ENV, "DATADEPS_ALWAYS_ACCEPT", "false")
        ENV["DATADEPS_ALWAYS_ACCEPT"] = "true"
        global PATH_SOLVER =
            joinpath(DataDeps.datadep"libpath50", libpath_filename)
        global LUSOL_LIBRARY_PATH =
            joinpath(DataDeps.datadep"liblusol", liblusol_filename)
        ENV["DATADEPS_ALWAYS_ACCEPT"] = current
    end
    return
end

include("C_API.jl")
include("MOI_wrapper.jl")

end
