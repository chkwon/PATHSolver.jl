import Libdl

function download_path()
    if !haskey(ENV, "SECRET_URL_PATH_BINARIES")
        error(
            "Unable to download PATH. Set the environment variable " *
            "`SECRET_URL_PATH_BINARIES`, or install a copy of `libpath50.xx` manually " *
            "and set the environment variable `PATH_JL_LOCATION` to point to the libpath " *
            "location."
        )
    end
    base_url = ENV["SECRET_URL_PATH_BINARIES"]
    libpath, libgfortran = if Sys.islinux() &&  Sys.ARCH == :x86_64
        "libpath50.so", "libgfortran.so.4.0.0"
    elseif Sys.isapple()
        "libpath50.dylib", "libgfortran.4.dylib"
    elseif Sys.iswindows()
        "libpath50.dll", "libgfortran-4.dll"
    else
        error(
            "Unsupported operating system. Only 64-bit linux, OSX, and Windows are supported."
        )
    end
    ENV["PATH_JL_LOCATION"] = joinpath(@__DIR__, libpath)
    download(joinpath(base_url, libpath), ENV["PATH_JL_LOCATION"])
    download(joinpath(base_url, libgfortran), joinpath(@__DIR__, libgfortran))
    return
end

function install_path()
    if !haskey(ENV, "PATH_JL_LOCATION")
        download_path()
    end
    local_filename = get(ENV, "PATH_JL_LOCATION", nothing)
    if local_filename === nothing
        error("Environment variable `PATH_JL_LOCATION` not found.")
    elseif Libdl.dlopen_e(local_filename) == C_NULL
        error("Unable to open the path library $(local_filename).")
    end
    open("deps.jl", "w") do io
        write(io, "const PATH_SOLVER = \"$(escape_string(local_filename))\"")
    end
end

install_path()
