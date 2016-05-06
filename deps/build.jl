using BinDeps
@BinDeps.setup

dl_dir = joinpath(dirname(dirname(@__FILE__)), "deps", "downloads")
deps_dir = joinpath(dirname(dirname(@__FILE__)), "deps")
lib_dir = joinpath(deps_dir, "usr", "lib")
src_dir = joinpath(deps_dir, "src")

bit = "64"
if Int == Int32
  bit = "32"
elseif Int ==Int64
  bit = "64"
end


gfortran_osx = filter(x -> endswith(x, "libgfortran.3.dylib"), Libdl.dllist())
libgfortran_path = isempty(gfortran_osx) ? "" : gfortran_osx[1]


# Verions of libraries
# pathlib_v = "a11966f36875748820583e41455800470c971171"
pathlib_v = "4.7.03"
pathjulia_v = "0.0.7"

# The main dependency
libpath47julia = library_dependency("libpath47julia")

libpath47_dylib = joinpath(src_dir, "pathlib-$pathlib_v", "lib", "osx", "libpath47.dylib")
libpath47julia_dylib = joinpath(src_dir, "PathJulia-$pathjulia_v", "lib", "osx", "libpath47julia.dylib")

libpath47_so = joinpath(src_dir, "pathlib-$pathlib_v", "lib", "linux$bit", "libpath47.so")
path47julia_c = joinpath(src_dir, "PathJulia-$pathjulia_v", "src", "pathjulia.c")

libpath47_dll = joinpath(src_dir, "pathlib-$pathlib_v", "lib", "win$bit", "path47.dll")
libpath47_lib = joinpath(src_dir, "pathlib-$pathlib_v", "lib", "win$bit", "path47.lib")
libpath47julia_dll = joinpath(src_dir, "PathJulia-$pathjulia_v", "lib", "win$bit", "libpath47julia.dll")
libpath47julia_lib = joinpath(src_dir, "PathJulia-$pathjulia_v", "lib", "win$bit", "libpath47julia.lib")



provides(BuildProcess,
    (@build_steps begin
        CreateDirectory(lib_dir, true)
        @build_steps begin
            FileDownloader("https://github.com/chkwon/PathJulia/archive/$pathjulia_v.zip", joinpath(dl_dir, "PathJulia.zip"))
            FileUnpacker(joinpath(dl_dir, "PathJulia.zip"), src_dir, libpath47julia_dylib)
            `cp -f $libpath47julia_dylib $lib_dir`
        end
        # Clean-up only.
        @build_steps begin
            ChangeDirectory(src_dir)
            `rm -rf PathJulia`
            `mv PathJulia-$pathjulia_v PathJulia`
        end
    end), libpath47julia, os = :Darwin)

provides(BuildProcess,
    (@build_steps begin
        CreateDirectory(lib_dir, true)
        CreateDirectory(src_dir, true)
        @build_steps begin
            ChangeDirectory(src_dir)
            FileDownloader("https://github.com/ampl/pathlib/archive/$pathlib_v.tar.gz", joinpath(dl_dir, "pathlib.tar.gz"))
            FileUnpacker(joinpath(dl_dir, "pathlib.tar.gz"), src_dir, libpath47_so)
            # `cp -i $libpath47_so $lib_dir`
        end
        @build_steps begin
            FileDownloader("https://github.com/chkwon/PathJulia/archive/$pathjulia_v.tar.gz", joinpath(dl_dir, "PathJulia.tar.gz"))
            FileUnpacker(joinpath(dl_dir, "PathJulia.tar.gz"), src_dir, path47julia_c)
            # `cp -i $libpath47julia_so $lib_dir`
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

provides(BuildProcess,
    (@build_steps begin
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
            # `powershell -NoProfile -Command "Copy-Item -Path $libpath47julia_lib -Destination $lib_dir -force"`
        end
        # @build_steps begin
            # ChangeDirectory(src_dir)
            # `powershell -Command "Remove-Item pathlib"`
            # `powershell -Command "Remove-Item PathJulia"`
            # `powershell -Command "mv pathlib-$pathlib_v pathlib"`
            # `powershell -Command "mv PathJulia-$pathjulia_v PathJulia"`
        # end
    end), libpath47julia, os = :Windows)

@windows_only push!(BinDeps.defaults, BuildProcess)

@BinDeps.install Dict(:libpath47julia => :libpath47julia)

@windows_only pop!(BinDeps.defaults)
