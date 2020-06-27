import Libdl

const DEFAULT_PATH_URL = "http://pages.cs.wisc.edu/~ferris/path/julia/"

function _prefix_suffix(str)
    if Sys.islinux() &&  Sys.ARCH == :x86_64
        return "lib$(str).so"
    elseif Sys.isapple()
        return "lib$(str).dylib"
    elseif Sys.iswindows()
        return "$(str).dll"
    end
    error(
        "Unsupported operating system. Only 64-bit linux, OSX, and Windows " *
        "are supported."
    )
end

function download_path()
    libpath = _prefix_suffix("path50")
    ENV["PATH_JL_LOCATION"] = joinpath(@__DIR__, libpath)
    download(joinpath(DEFAULT_PATH_URL, libpath), ENV["PATH_JL_LOCATION"])
    return
end

function install_path()
    if !haskey(ENV, "PATH_JL_LOCATION")
        download_path()
    end
    lusol = _prefix_suffix("lusol")
    lusol_filename = joinpath(@__DIR__, lusol)
    download(joinpath(DEFAULT_PATH_URL, lusol), lusol_filename)
    local_filename = get(ENV, "PATH_JL_LOCATION", nothing)
    if local_filename === nothing
        error("Environment variable `PATH_JL_LOCATION` not found.")
    elseif Libdl.dlopen(local_filename) == C_NULL
        error("Unable to open the path library $(local_filename).")
    end
    open("deps.jl", "w") do io
        write(io, "const PATH_SOLVER = \"$(escape_string(local_filename))\"\n")
        write(io, "const LUSOL_LIBRARY_PATH = \"$(escape_string(lusol_filename))\"\n")
    end
end

install_path()
