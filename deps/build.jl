import Libdl

function download_path()
    base_url = ENV["SECRET_URL_PATH_BINARIES"]
    platform_dependent_library = if Sys.islinux() &&  Sys.ARCH == :x86_64
        "libpath50.so"
    elseif Sys.isapple()
        "libpath50.dylib"
    else
        error("Unsupported operating system. Only 64-bit linux and OSX are supported.")
    end
    platform_dependent_url = joinpath(base_url, platform_dependent_library)
    local_filename = joinpath(@__DIR__, platform_dependent_library)
    download(platform_dependent_url, local_filename)
    return local_filename
end

function install_path()
    local_filename = get(ENV, "PATH_JL_LOCATION", nothing)
    if local_filename === nothing
        @info "`PATH_JL_LOCATION` not detected. Attempting to download."
        local_filename = download_path()
    end
    if Libdl.dlopen_e(local_filename) == C_NULL
        error(
            "The environment variable `PATH_JL_LOCATION` does not point to a " *
            "valid `libpath` library."
        )
    end
    @info "Installing PATH from $(local_filename)"
    open("deps.jl", "w") do io
        write(io, """
        const PATH_SOLVER = "$(escape_string(local_filename))"
        """)
    end
end

install_path()
