@testset "linear complementarity problem" begin
    M = [0  0 -1 -1 ;
         0  0  1 -2 ;
         1 -1  2 -2 ;
         1  2 -2  4 ]

    q = [2; 2; -2; -6]

    myfunc(x) = M*x + q

    n = 4
    lb = zeros(n)
    ub = 100*ones(n)

    status, z, f = solveLCP(myfunc, M, lb, ub)
    @show status
    @show z
    @show f
    @test isapprox(z, [2.8, 0.0, 0.8, 1.2])
    @test status == :Solved

    status, z, f = solveLCP(myfunc, lb, ub)
    @show status
    @show z
    @show f
    @test isapprox(z, [2.8, 0.0, 0.8, 1.2])
    @test status == :Solved


    println("-------------------------------------------------------")


    M = [0  0 -1 -1 ;
         0  0  1 -2 ;
         1 -1  2 -2 ;
         1  2 -2  4 ]

    q = [2; 2; -2; -6]

    myfunc(x) = M*x + q

    n = 4
    lb = zeros(n)
    ub = 100*ones(n)

    options(convergence_tolerance=1e-2, output=:no, time_limit=3600)

    status, z, f = solveLCP(myfunc, M, lb, ub)
    @show status
    @show z
    @show f
    @test isapprox(z, [2.8, 0.0, 0.8, 1.2])
    @test status == :Solved

    status, z, f = solveLCP(myfunc, lb, ub)
    @show status
    @show z
    @show f
    @test isapprox(z, [2.8, 0.0, 0.8, 1.2])
    @test status == :Solved

    M = sparse(M)
    status, z, f = solveLCP(myfunc, lb, ub)
    @show status
    @show z
    @show f
    @test isapprox(z, [2.8, 0.0, 0.8, 1.2])
    @test status == :Solved


    println("-------------------------------------------------------")


    function elemfunc(x)
        val = similar(x)
        val[1] = -x[3]-x[4] + q[1]
        val[2] = x[3] -2x[4] + q[2]
        val[3] = x[1]-x[2]+2x[3]-2x[4] + q[3]
        val[4] = x[1]+2x[2]-2x[3]+4x[4] + q[4]
        return val
    end

    n = 4
    lb = zeros(n)
    ub = 100*ones(n)
    z0 = 2 * copy(ub)

    var_name = ["x1", "x2", "x3", "x4"]
    con_name = ["F1", "F2", "F3", "F4"]

    options(convergence_tolerance=1e-2, output=:yes, time_limit=3600)

    status, z, f = solveLCP(elemfunc, M, lb, ub)
    status, z, f = solveLCP(elemfunc, M, lb, ub, var_name)
    status, z, f = solveLCP(elemfunc, M, lb, ub, var_name, con_name)
    status, z, f = solveLCP(elemfunc, M, lb, ub, z0)
    status, z, f = solveLCP(elemfunc, M, lb, ub, z0, var_name)
    status, z, f = solveLCP(elemfunc, M, lb, ub, z0, var_name, con_name)

    status, z, f = solveLCP(elemfunc, lb, ub)
    status, z, f = solveLCP(elemfunc, lb, ub, var_name)
    status, z, f = solveLCP(elemfunc, lb, ub, var_name, con_name)
    status, z, f = solveLCP(elemfunc, lb, ub, z0)
    status, z, f = solveLCP(elemfunc, lb, ub, z0, var_name)
    status, z, f = solveLCP(elemfunc, lb, ub, z0, var_name, con_name)

    @show status
    @show z
    @show f


    @test isapprox(z, [2.8, 0.0, 0.8, 1.2])
    @test status == :Solved



    println("-------------------------------------------------------")


    function nl_func(x)
        val = similar(x)
        val[1] = -x[3]^3-x[4] + q[1]
        val[2] = x[3] -2x[4]^2 + q[2]
        val[3] = x[1]-x[2]+2x[3]^3-2x[4] + q[3]
        val[4] = x[1]+2x[2]^2-2x[3]+4x[4] + q[4]
        return val
    end

    n = 4
    lb = zeros(n)
    ub = 100*ones(n)

    @test_throws ErrorException solveLCP(nl_func, lb, ub, lcp_check=true)


    println("-------------------------------------------------------")


    M2 = rand(Float64, size(M))
    # @test_warn "does not match" solveLCP(elemfunc, M2, lb, ub, lcp_check=true)
    @test_throws ErrorException solveLCP(elemfunc, M2, lb, ub, lcp_check=true)
end
