@testset "CheckLicense" begin
    @test PATH.c_api_Path_CheckLicense(1, 1) > 0
end

@testset "PathVersion" begin
    s = PATH.c_api_Path_Version()
    @test match(r"Path [0-9]\.[0-9]\.[0-9][0-9]", s) !== nothing
end

GC.enable(false)

@testset "Example" begin
    M = [
        0  0 -1 -1;
        0  0  1 -2;
        1 -1  2 -2;
        1  2 -2  4
    ]
    q = [2; 2; -2; -6]

    function F(n::Cint, x::Vector{Cdouble}, f::Vector{Cdouble})
        @assert n == length(x) == length(f) == 4
        f .= M * x .+ q
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
        # @assert nnz == length(row) == length(data)
        i = 0
        for c in 1:n
            col[c] = i + 1
            len[c] = 0
            for r in 1:n
                if !iszero(M[r, c])
                    i += 1
                    data[i] = M[r, c]
                    row[i] = r
                    len[c] += 1
                end
            end
        end
        return Cint(0)
    end

    status, z, info = PATH.c_api_pathMain(
        z = fill(0.0, 4),
        lb = fill(0.0, 4),
        ub = fill(PATH.INFINITY, 4),
        F = F,
        J = J
    )
    @test status == PATH.MCP_Solved
    @test isapprox(z, [2.8, 0.0, 0.8, 1.2])
end

GC.enable(true)
