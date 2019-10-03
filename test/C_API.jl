@testset "CheckLicense" begin
    @test PATH.c_api_Path_CheckLicense(1, 1) > 0
end

@testset "PathVersion" begin
    s = PATH.c_api_Path_Version()
    @test match(r"Path [0-9]\.[0-9]\.[0-9][0-9]", s) !== nothing
end

@testset "Example" begin
    M = [
        0  0 -1 -1;
        0  0  1 -2;
        1 -1  2 -2;
        1  2 -2  4
    ]
    q = [2; 2; -2; -6]
    my_func(x) = M * x .+ q
    my_jac(x) = M

    function F(n::Cint, x::Vector{Cdouble}, f::Vector{Cdouble})
        f .= my_func(x)
        return Cint(0)
    end

    function J(
        n::Cint,
        nnz::Cint,
        x::Vector{Cdouble},
        col::Vector{Cint},
        len::Vector{Cint},
        row::Vector{Cint},
        data::Vector{Cdouble}
    )
        @assert n == length(x) == length(col) == length(len) == 4
        @assert nnz == length(row) == length(data)
        jac = my_jac(x)
        i = 1
        for c in 1:n
            col[c] = i
            len[c] = 0
            for r in 1:n
                if !iszero(M[r, c])
                    data[i] = jac[r, c]
                    row[i] = r
                    len[c] += 1
                    i += 1
                end
            end
        end
        return Cint(0)
    end

    status, z, info = PATH.solve_mcp(
        z = [0.0, 0.0, 0.0, 0.0],
        lb = fill(0.0, 4),
        ub = fill(10.0, 4),
        F = F,
        J = J
    )
    @test status == PATH.MCP_Solved
    @test isapprox(z, [2.8, 0.0, 0.8, 1.2])
end

@testset "Example II" begin
    M = [
        0  0 -1 -1;
        0  0  1 -2;
        1 -1  2 -2;
        1  2 -2  4
    ]

    q = [2; 2; -2; -6]

    function F(n::Cint, x::Vector{Cdouble}, f::Vector{Cdouble})
        @assert n == length(x) == length(f) == 4
        f[1] = -x[3]^2 - x[4] + q[1]
        f[2] =  x[3]^3 - 2x[4]^2 + q[2]
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
        data::Vector{Cdouble}
    )
        JAC = [
            0       0     -2x[3]      -1;
            0       0    3x[3]^2  -4x[4];
            5x[1]^4      -1          2      -2;
            1   6x[2]         -2       4
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
        return Cint(0)
    end

    status, z, info = PATH.solve_mcp(
        z = [1.0, 1.0, 1.0, 1.0],
        lb = fill(0.0, 4),
        ub = fill(10.0, 4),
        F = F,
        J = J,
        output = "yes"
    )
    @test status == PATH.MCP_Solved
    @test isapprox(z, [1.28475, 0.972916, 0.909376, 1.17304], atol=1e-4)
end
