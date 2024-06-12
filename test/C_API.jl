# Copyright (c) 2016 Changhyun Kwon, Oscar Dowson, and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module TestCAPI

using Test

import PATHSolver
import SparseArrays

function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
    return
end

function _check_info_sanity(info)
    @test info.residual < 1e-5
    @test iszero(info.restarts)
    @test info.function_evaluations > 0
    return
end

function test_License_SetString()
    @test PATHSolver.c_api_License_SetString("bad_license") != 0
    return
end

function test_CheckLicense()
    out_io = IOBuffer()
    output_data = PATHSolver.OutputData(out_io)
    output_interface = PATHSolver.OutputInterface(output_data)
    GC.@preserve output_data output_interface begin
        # The output_interface needs to be set before calling CheckLicense
        PATHSolver.c_api_Output_SetInterface(output_interface)
        @test PATHSolver.c_api_Path_CheckLicense(1, 1) == 1
        @test PATHSolver.c_api_Path_CheckLicense(1_000, 1_000) == 0
    end
    n = 1_000
    M = zeros(n, n)
    for i in 1:n
        M[i, i] = 1.0
    end
    ret = PATHSolver.solve_mcp(
        SparseArrays.SparseMatrixCSC{Float64,Int32}(M),
        ones(n),    # q
        zeros(n),   # lb
        ones(n),    # ub
        ones(n),    # z
    )
    @test ret == (PATHSolver.MCP_LicenseError, nothing, nothing)
    return
end

function test_PathVersion()
    s = PATHSolver.c_api_Path_Version()
    @test match(r"Path [0-9]\.[0-9]\.[0-9][0-9]", s) !== nothing
    return
end

function test_Example()
    M = convert(
        SparseArrays.SparseMatrixCSC{Cdouble,Cint},
        SparseArrays.sparse([
            0 0 -1 -1
            0 0 1 -2
            1 -1 2 -2
            1 2 -2 4
        ]),
    )
    status, z, info = PATHSolver.solve_mcp(
        M,
        Float64[2, 2, -2, -6],
        fill(0.0, 4),
        fill(10.0, 4),
        [0.0, 0.0, 0.0, 0.0];
        output = "yes",
    )
    @test status == PATHSolver.MCP_Solved
    @test isapprox(z, [2.8, 0.0, 0.8, 1.2])
    _check_info_sanity(info)
    return
end

function test_M_not_square()
    M = convert(
        SparseArrays.SparseMatrixCSC{Cdouble,Cint},
        SparseArrays.sparse([
            1 -1 2 -2
            1 2 -2 4
        ]),
    )
    err = ErrorException("M not square! size = $(size(M))")
    @test_throws err PATHSolver.solve_mcp(
        M,
        Float64[2, 2],
        fill(0.0, 4),
        fill(10.0, 4),
        [0.0, 0.0, 0.0, 0.0];
        output = "yes",
    )
    return
end

function test_q_wrong_shape()
    M = convert(
        SparseArrays.SparseMatrixCSC{Cdouble,Cint},
        SparseArrays.sparse([
            0 0 -1 -1
            0 0 1 -2
            1 -1 2 -2
            1 2 -2 4
        ]),
    )
    q = [2.0, 2.0]
    err = ErrorException(
        "q is wrong shape. Expected $(size(M, 1)), got $(length(q)).",
    )
    @test_throws err PATHSolver.solve_mcp(
        M,
        q,
        fill(0.0, 4),
        fill(10.0, 4),
        [0.0, 0.0, 0.0, 0.0];
        output = "yes",
    )
    return
end

function test_Example_LUSOL()
    M = convert(
        SparseArrays.SparseMatrixCSC{Cdouble,Cint},
        SparseArrays.sparse([
            0 0 -1 -1
            0 0 1 -2
            1 -1 2 -2
            1 2 -2 4
        ]),
    )
    status, z, info = PATHSolver.solve_mcp(
        M,
        Float64[2, 2, -2, -6],
        fill(0.0, 4),
        fill(10.0, 4),
        [0.0, 0.0, 0.0, 0.0];
        output = "yes",
        # TODO(odow): when enabled, I get segfaults :(
        factorization_method = "blu_lusol",
        factorization_library_name = PATHSolver.LUSOL_LIBRARY_PATH,
    )
    @test status == PATHSolver.MCP_Solved
    @test isapprox(z, [2.8, 0.0, 0.8, 1.2])
    _check_info_sanity(info)
    return
end

function test_Example_II()
    M = [
        0 0 -1 -1
        0 0 1 -2
        1 -1 2 -2
        1 2 -2 4
    ]
    q = [2; 2; -2; -6]
    function F(n::Cint, x::Vector{Cdouble}, f::Vector{Cdouble})
        @assert n == length(x) == length(f) == 4
        f[1] = -x[3]^2 - x[4] + q[1]
        f[2] = x[3]^3 - 2x[4]^2 + q[2]
        f[3] = x[1]^5 - x[2] + 2x[3] - 2x[4] + q[3]
        f[4] = x[1] + 2x[2]^3 - 2x[3] + 4x[4] + q[4]
        return Cint(0)
    end
    function J(
        n::Cint,
        nnz::Cint,
        x::Vector{Cdouble},
        col::Vector{Cint},
        len::Vector{Cint},
        row::Vector{Cint},
        data::Vector{Cdouble},
    )
        JAC = [
            0 0 -2x[3] -1
            0 0 3x[3]^2 -4x[4]
            5x[1]^4 -1 2 -2
            1 6x[2] -2 4
        ]
        @assert n == length(x) == length(col) == length(len) == 4
        @assert nnz == length(row) == length(data)
        i = 1
        for c in 1:n
            col[c] = i
            len[c] = 0
            for r in 1:n
                if !iszero(JAC[r, c])
                    data[i] = JAC[r, c]
                    row[i] = r
                    len[c] += 1
                    i += 1
                end
            end
        end
        @test sum(len) == nnz
        return Cint(0)
    end
    status, z, info = PATHSolver.solve_mcp(
        F,
        J,
        fill(0.0, 4),
        fill(10.0, 4),
        [1.0, 1.0, 1.0, 1.0];
        output = "yes",
        nnz = 12,
    )
    @test status == PATHSolver.MCP_Solved
    @test isapprox(z, [1.28475, 0.972916, 0.909376, 1.17304], atol = 1e-4)
    _check_info_sanity(info)
    return
end

function test_Name()
    M = convert(
        SparseArrays.SparseMatrixCSC{Cdouble,Cint},
        SparseArrays.sparse([
            0 0 -1 -1
            0 0 1 -2
            1 -1 2 -2
            1 2 -2 4
        ]),
    )
    z0 = [-10.0, 10.0, -5.0, 5.0]
    status, z, info = PATHSolver.solve_mcp(
        M,
        Float64[2, 2, -2, -6],
        fill(0.0, 4),
        fill(10.0, 4),
        z0;
        variable_names = ["x1", "x2", "x3", "x4"],
        constraint_names = ["F1", "F2", "F3", "F4"],
        output = "yes",
    )
    @test status == PATHSolver.MCP_Solved
    @test isapprox(z, [2.8, 0.0, 0.8, 1.2])
    _check_info_sanity(info)
    status, z, info = PATHSolver.solve_mcp(
        M,
        Float64[2, 2, -2, -6],
        fill(0.0, 4),
        fill(10.0, 4),
        z0;
        variable_names = ["x1", "x2", "x3", "x4"],
        constraint_names = [
            "A2345678901234567890",
            "B23456789012345678901234567",
            "C234567890",
            "D234567890",
        ],
        output = "yes",
    )
    @test status == PATHSolver.MCP_Solved
    @test isapprox(z, [2.8, 0.0, 0.8, 1.2])
    _check_info_sanity(info)
    status, z, info = PATHSolver.solve_mcp(
        M,
        Float64[2, 2, -2, -6],
        fill(0.0, 4),
        fill(10.0, 4),
        z0;
        variable_names = ["x1", "x2", "x3", "x4"],
        constraint_names = [
            "A2345678901234567890",
            "B23456789012345678901234567",
            "C🤖λ⚽️⚽️⚽️⚽️🏸⚽️⚽️⚽️⚽️🏸",
            "D도레미파솔",
        ],
        output = "yes",
    )
    @test status == PATHSolver.MCP_Solved
    @test isapprox(z, [2.8, 0.0, 0.8, 1.2])
    _check_info_sanity(info)
    return
end

end

TestCAPI.runtests()
