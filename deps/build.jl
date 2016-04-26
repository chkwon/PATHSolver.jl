using BinDeps
@BinDeps.setup

dl_dir = joinpath(dirname(dirname(@__FILE__)), "deps", "downloads")
deps_dir = joinpath(dirname(dirname(@__FILE__)), "deps")
lib_dir = joinpath(deps_dir, "usr", "lib")

# # Check the dependency of libgfortran (should be available from the Julia installation)
# libgfortran = library_dependency("libgfortran", aliases=["libgfortran", "libgfortran.3"])
# libgfortran_dylib = ""
# for (k,v) in BinDeps._find_library(libgfortran)
#     libgfortran_dylib = v
#     println(libgfortran_dylib)
# end


# The main dependency
libpath47julia = library_dependency("libpath47julia")
libpath47_dylib = joinpath(deps_dir, "pathlib-master", "lib", "osx", "libpath47.dylib")
libpath47julia_dylib = joinpath(deps_dir, "PathJulia-0.0.2", "lib", "osx", "libpath47julia.dylib")
libgfortran_dylib = joinpath(deps_dir, "PathJulia-0.0.2", "lib", "osx", "libgfortran.3.dylib")

provides(BuildProcess,
    (@build_steps begin
        CreateDirectory(lib_dir, true)
        @build_steps begin
            FileDownloader("https://github.com/ampl/pathlib/archive/master.zip",
                            joinpath(deps_dir, "downloads", "pathlib.zip"))
            FileUnpacker(joinpath(deps_dir, "downloads", "pathlib.zip"), deps_dir, libpath47_dylib)
            `cp $libpath47_dylib $lib_dir`
        end
        @build_steps begin
            FileDownloader("https://github.com/chkwon/PathJulia/archive/0.0.2.tar.gz",
                            joinpath(deps_dir, "downloads", "pathjulia.tar.gz"))
            FileUnpacker(joinpath(deps_dir, "downloads", "pathjulia.tar.gz"), deps_dir, libpath47julia_dylib)
            `cp $libpath47julia_dylib $lib_dir`
            `cp $libgfortran_dylib $lib_dir`
        end
    end), libpath47julia, os = :Darwin)



try
    @BinDeps.install Dict(:libpath47julia => :libpath47julia)




catch e
    info("===================================================================")
    info(" When the package installation fails, add the following directory  ")
    info("    $lib_dir                       ")
    info(" to 'DYLD_LIBRARY_PATH' in your '.bash_profile' by                 ")
    info("    export DYLD_LIBRARY_PATH=\$DYLD_LIBRARY_PATH:\"$lib_dir\"")
    info(" then close the terminal, reopen, and build the package again:     ")
    info("    julia> Pkg.build(\"PATHSolver\")            ")
    info(" Read https://github.com/chkwon/PATHSolver.jl for further information.")
    info("===================================================================")
    throw(e)
end


















# libgfortran = library_dependency("libgfortran", aliases=["libgfortran", "libgfortran.3"])
# libpath47 = library_dependency("libpath47")

# Libdl.dlopen("/opt/homebrew-cask/Caskroom/julia/0.4.5/Julia-0.4.5.app/Contents/Resources/julia/lib/julia/libgfortran.3.dylib")
# provides(Binaries, URI("https://github.com/ampl/pathlib/archive/master.zip"), libpath47, unpacked_dir = "pathlib-master/lib/osx/", os = :Darwin)
# @BinDeps.install Dict(:libpath47 => :libpath47)
#
#
# Libdl.dlopen("/Users/chkwon/.julia/v0.4/PATH/deps/pathlib-master/lib/osx/libpath47.dylib")
#
#
#
#
# provides(Homebrew.HB, "gcc", libgfortran, os = :Darwin)
#
# # Libdl.dlopen("/opt/homebrew-cask/Caskroom/julia/0.4.5/Julia-0.4.5.app/Contents/Resources/julia/lib/julia/libgfortran.3.dylib", Libdl.RTLD_GLOBAL)
#
# libpath47 = library_dependency("libpath47")
# provides(Binaries, URI("https://github.com/ampl/pathlib/archive/master.zip"), libpath47, unpacked_dir = "pathlib-master/lib/osx/", os = :Darwin)
# @BinDeps.install Dict(:libpath47 => :libpath47)
#
# Libdl.dlopen("/Users/chkwon/.julia/v0.4/PATH/deps/pathlib-master/lib/osx/libpath47.dylib", Libdl.RTLD_GLOBAL)
#
# libpath47julia = library_dependency("libpath47julia")
# provides(Binaries, URI("https://github.com/chkwon/PathJulia/archive/0.0.1.tar.gz"), libpath47julia, unpacked_dir = "PathJulia-0.0.1/lib/osx/", os = :Darwin)
# @BinDeps.install Dict(:libpath47julia => :libpath47julia)

#
# @osx_only begin
#     # provides(Binaries, URI("https://github.com/ampl/pathlib/raw/master/lib/osx/libpath47.dylib"), libpath47, unpacked_dir="libpath/binary/", os = :Darwin)
#
#     # https://github.com/ampl/pathlib/archive/master.zip
#
#     provides(Binaries, URI("https://github.com/ampl/pathlib/archive/master.zip"), libpath47, unpacked_dir = "pathlib-master/lib/osx/", os = :Darwin)
#
#     # provides(Binaries, URI("https://github.com/chkwon/PathJulia/raw/master/zip/pathjulia.zip"), libpath47, os = :Darwin)
#
#     provides(Binaries, URI("https://github.com/chkwon/PathJulia/archive/master.zip"), libpath47julia, unpacked_dir = "pathjulia-master/lib/osx/", os = :Darwin)
#     # provides(Binaries, URI("https://github.com/chkwon/PathJulia/raw/master/lib/osx/libgfortran.3.dylib"), libgfortran, os = :Darwin)
# end
# #
# @BinDeps.install Dict(:libpath47 => :libpath47)
# # @BinDeps.install Dict(:libpath47julia => :libpath47julia)
# # @BinDeps.install Dict(:libgfortran => :libgfortran)
