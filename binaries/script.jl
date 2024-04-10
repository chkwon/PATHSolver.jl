# Copyright (c) 2024 Oscar Dowson, and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

using Tar, Inflate, SHA, TOML

function get_artifact(data)
    dir = "$(data.arch)-$(data.platform)"
    filename = "$(dir).tar.bz2"
    run(`tar -cjf $filename $dir`)
    url = "https://github.com/chkwon/PATHSolver.jl/releases/download/v5.0.3-path-binaries/$filename"
    ret = Dict(
        "git-tree-sha1" => Tar.tree_hash(`gzcat $filename`),
        "arch" => data.arch,
        "os" => data.os,
        "download" => Any[
            Dict("sha256" => bytes2hex(open(sha256, filename)), "url" => url),
        ]
    )
    return ret
end

function main()
    platforms = [
        (os = "linux", arch = "x86_64", platform = "linux-gnu"),
        (os = "macos", arch = "x86_64", platform = "apple-darwin"),
        (os = "macos", arch = "aarch64", platform = "apple-darwin"),
        (os = "windows", arch = "x86_64", platform = "w64-mingw32"),
    ]
    output = Dict("PATHSolver" => get_artifact.(platforms))
    open(joinpath(dirname(@__DIR__), "Artifacts.toml"), "w") do io
        return TOML.print(io, output)
    end
    return
end

#   julia --project=scripts scripts/update_artifacts.jl
#
# Update the Artifacts.toml file.
main()
