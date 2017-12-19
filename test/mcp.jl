@testset "mixed complementarity problem" begin
    M = [0  0 -1 -1 ;
         0  0  1 -2 ;
         1 -1  2 -2 ;
         1  2 -2  4 ]

    q = [2; 2; -2; -6]

    myfunc(x) = M*x + q

    n = 4
    lb = zeros(n)
    ub = 100*ones(n)

    status, z, f = solveMCP(myfunc, lb, ub)
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
    ub = 100*ones(n)

    var_name = ["first var", "second var", "third var", "fourth var"]
    con_name = ["func 1", "func 2", "func 3", "func 4"]

    options(convergence_tolerance=1e-2, output=:yes, time_limit=3600)


    jacfunc(x) = M

    status, z, f = solveMCP(elemfunc, lb, ub)
    status, z, f = solveMCP(elemfunc, lb, ub, var_name)
    status, z, f = solveMCP(elemfunc, lb, ub, var_name, con_name)
    status, z, f = solveMCP(elemfunc, jacfunc, lb, ub)
    status, z, f = solveMCP(elemfunc, jacfunc, lb, ub, var_name)
    status, z, f = solveMCP(elemfunc, jacfunc, lb, ub, var_name, con_name)


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
