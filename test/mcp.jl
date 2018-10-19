@testset "mixed complementarity problem" begin
    M = [0  0 -1 -1 ;
         0  0  1 -2 ;
         1 -1  2 -2 ;
         1  2 -2  4 ]

    q = [2; 2; -2; -6]

    function myfunc(x)
        val = similar(x)
        val[1] = -x[3]^2 - x[4] + q[1]
        val[2] =  x[3]^3 - 2x[4]^2 + q[2]
        val[3] = x[1]^5 - x[2] + 2x[3] - 2x[4] + q[3]
        val[4] = x[1] + 2x[2]^3 - 2x[3] + 4x[4] + q[4]
        return val
    end

    function myjac(x)
        A = [       0       0     -2x[3]      -1 ;
                    0       0    3x[3]^2  -4x[4] ;
              5x[1]^4      -1          2      -2 ;
                    1   6x[2]         -2       4 ]
        return A
    end

    n = 4
    lb = zeros(n)
    ub = 100*ones(n)

    status, z, f = solveMCP(myfunc, lb, ub)
    @show status
    @show z
    @show f

    @test isapprox(z, [1.28475, 0.972916, 0.909376, 1.17304], atol=1e-4)
    @test status == :Solved

    var_name = ["var one", "var two", "var three", "var four"]
    con_name = ["func hana", "func dool", "func set", "func net"]

    z0 = -1 .* copy(lb)

    status, z, f = solveMCP(myfunc, lb, ub)
    status, z, f = solveMCP(myfunc, lb, ub, var_name)
    status, z, f = solveMCP(myfunc, lb, ub, var_name, con_name)
    status, z, f = solveMCP(myfunc, lb, ub, z0)
    status, z, f = solveMCP(myfunc, lb, ub, z0, var_name)
    status, z, f = solveMCP(myfunc, lb, ub, z0, var_name, con_name)

    status, z, f = solveMCP(myfunc, myjac, lb, ub)
    status, z, f = solveMCP(myfunc, myjac, lb, ub, var_name)
    status, z, f = solveMCP(myfunc, myjac, lb, ub, var_name, con_name)
    status, z, f = solveMCP(myfunc, myjac, lb, ub, z0)
    status, z, f = solveMCP(myfunc, myjac, lb, ub, z0, var_name)
    status, z, f = solveMCP(myfunc, myjac, lb, ub, z0, var_name, con_name)


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

    status, z, f = solveMCP(myfunc, lb, ub)

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
    ub = 100 .* ones(n)
    z0 = 2 .* copy(ub)

    var_name = ["first var", "second var", "third var", "fourth var"]
    con_name = ["func 1", "func 2", "func 3", "func 4"]

    options(convergence_tolerance=1e-2, output=:yes, time_limit=3600)


    jacfunc(x) = M

    status, z, f = solveMCP(elemfunc, lb, ub)
    status, z, f = solveMCP(elemfunc, lb, ub, var_name)
    status, z, f = solveMCP(elemfunc, lb, ub, var_name, con_name)
    status, z, f = solveMCP(elemfunc, lb, ub, z0)
    status, z, f = solveMCP(elemfunc, lb, ub, z0, var_name)
    status, z, f = solveMCP(elemfunc, lb, ub, z0, var_name, con_name)

    status, z, f = solveMCP(elemfunc, jacfunc, lb, ub)
    status, z, f = solveMCP(elemfunc, jacfunc, lb, ub, var_name)
    status, z, f = solveMCP(elemfunc, jacfunc, lb, ub, var_name, con_name)
    status, z, f = solveMCP(elemfunc, jacfunc, lb, ub, z0)
    status, z, f = solveMCP(elemfunc, jacfunc, lb, ub, z0, var_name)
    status, z, f = solveMCP(elemfunc, jacfunc, lb, ub, z0, var_name, con_name)

    @show status
    @show z
    @show f


    @test isapprox(z, [2.8, 0.0, 0.8, 1.2])
    @test status == :Solved

    function test_in_local_scope()
        # Verify that we can solve MCPs in local scope. Surprisingly, this is
        # is relevant because it affects the way closures are generated. To be
        # specific, you can do the following in global scope:
        #
        # julia> y = [1]
        # julia> cfunction(x -> x + y[1], Int, (Int,))
        #
        # but running the same code inside a function will fail with:
        #   ERROR: closures are not yet c-callable

        M = [0  0 -1 -1 ;
             0  0  1 -2 ;
             1 -1  2 -2 ;
             1  2 -2  4 ]

        q = [2; 2; -2; -6]

        myfunc(x) = M*x + q

        n = 4
        lb = zeros(n)
        ub = 100*ones(n)

        options(convergence_tolerance=1e-2, output=:yes, time_limit=3600, lemke_start=:first, nms_searchtype=:line)

        status, z, f = solveMCP(myfunc, lb, ub)

        @show status
        @show z
        @show f

        @test isapprox(z, [2.8, 0.0, 0.8, 1.2])
        @test status == :Solved
    end

    test_in_local_scope()
end
