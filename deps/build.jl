using BinDeps
@BinDeps.setup

dl_dir = joinpath(dirname(dirname(@__FILE__)), "deps", "downloads")
deps_dir = joinpath(dirname(dirname(@__FILE__)), "deps")
lib_dir = joinpath(deps_dir, "usr", "lib")
src_dir = joinpath(deps_dir, "src")

bit = (Int==Int32) ? "32" : "64"

# Verions of libraries
pathlib_v = "4.7.03"
pathjulia_v = "0.1.1"

# The main dependency
libpath47julia = library_dependency("libpath47julia")

# File paths for linux
libpath47_so = joinpath(src_dir, "pathlib-$pathlib_v", "lib", "linux$bit", "libpath47.so")
path47julia_c = joinpath(src_dir, "PathJulia-$pathjulia_v", "src", "pathjulia.c")

# File paths for windows
libpath47_dll = joinpath(src_dir, "pathlib-$pathlib_v", "lib", "win$bit", "path47.dll")
libpath47_lib = joinpath(src_dir, "pathlib-$pathlib_v", "lib", "win$bit", "path47.lib")
libpath47julia_dll = joinpath(src_dir, "PathJulia-$pathjulia_v", "lib", "win$bit", "libpath47julia.dll")


# Mac OS X
provides(Binaries, URI("https://github.com/chkwon/PathJulia/archive/$pathjulia_v.zip"),
         libpath47julia, unpacked_dir="PathJulia-$pathjulia_v/lib/osx", os = :Darwin)

# Linux 32/64
provides(BuildProcess,
    (@build_steps begin
        `rm -rf $lib_dir`
        `rm -rf $src_dir`
        CreateDirectory(lib_dir, true)
        CreateDirectory(src_dir, true)
        @build_steps begin
            ChangeDirectory(src_dir)
            FileDownloader("https://github.com/ampl/pathlib/archive/$pathlib_v.tar.gz", joinpath(dl_dir, "pathlib.tar.gz"))
            FileUnpacker(joinpath(dl_dir, "pathlib.tar.gz"), src_dir, libpath47_so)
        end
        @build_steps begin
            FileDownloader("https://github.com/chkwon/PathJulia/archive/$pathjulia_v.tar.gz", joinpath(dl_dir, "PathJulia.tar.gz"))
            FileUnpacker(joinpath(dl_dir, "PathJulia.tar.gz"), src_dir, path47julia_c)
        end
        @build_steps begin
            ChangeDirectory(src_dir)
            `rm -rf pathlib`
            `rm -rf PathJulia`
            `mv pathlib-$pathlib_v pathlib`
            `mv PathJulia-$pathjulia_v PathJulia`
        end
        @build_steps begin
            ChangeDirectory(joinpath(src_dir, "PathJulia", "src"))
            `make linux$bit`
            `cp -f ../lib/linux$bit/libpath47julia.so $lib_dir`
        end
    end), libpath47julia, os = :Linux)


# Windows 32/64
provides(BuildProcess,
    (@build_steps begin
        `powershell -NoProfile -Command "Remove-Item $lib_dir -Force -Recurse"`
        `powershell -NoProfile -Command "Remove-Item $src_dir -Force -Recurse"`
        CreateDirectory(lib_dir, true)
        CreateDirectory(src_dir, true)
        @build_steps begin
            ChangeDirectory(src_dir)
            FileDownloader("https://github.com/ampl/pathlib/archive/$pathlib_v.zip", joinpath(dl_dir, "pathlib.zip"))
            FileUnpacker(joinpath(dl_dir, "pathlib.zip"), src_dir, libpath47_dll)
            `powershell -NoProfile -Command "Copy-Item -Path $libpath47_dll -Destination $lib_dir -force"`
            `powershell -NoProfile -Command "Copy-Item -Path $libpath47_lib -Destination $lib_dir -force"`
        end
        @build_steps begin
            FileDownloader("https://github.com/chkwon/PathJulia/archive/$pathjulia_v.zip", joinpath(dl_dir, "PathJulia.zip"))
            FileUnpacker(joinpath(dl_dir, "PathJulia.zip"), src_dir, libpath47julia_dll)
            `powershell -NoProfile -Command "Copy-Item -Path $libpath47julia_dll -Destination $lib_dir -force"`
        end
    end), libpath47julia, os = :Windows)



@static if is_windows()
    push!(BinDeps.defaults, BuildProcess)
end

@BinDeps.install Dict(:libpath47julia => :libpath47julia)

@static if is_windows()
    pop!(BinDeps.defaults)
end
