function download_path()
    @info "Beginning to build PATH"
    base_url = "https://github.com/ampl/pathlib/raw/4.7.03/lib/"

    platform_dependent_library = if Sys.iswindows()
        Sys.ARCH == :x86_64 ? "win64/path47.dll" : "win32/path47.dll"
    elseif Sys.islinux()
        Sys.ARCH == :x86_64 ? "linux64/libpath47.so" : "linux32/libpath47.so"
    elseif Sys.isapple()
        "osx/libpath47.dylib"
    else
        error("Unsupported operating system. Only Windows, linux, and OSX are supported.")
    end

    platform_dependent_url = joinpath(base_url, platform_dependent_library)
    local_filename = joinpath(@__DIR__, split(platform_dependent_library, "/")[2])

    @info "Attempting to download: $(platform_dependent_url)"
    download(platform_dependent_url, local_filename)
    @info "Download successful. Writing deps.jl"
    open("deps.jl", "w") do io
        write(io, """
        const PATH_SOLVER = "$(escape_string(local_filename))"
        """)
    end
end

download_path()
