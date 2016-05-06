using PATHSolver
using Base.Test

M = [0  0 -1 -1 ;
     0  0  1 -2 ;
     1 -1  2 -2 ;
     1  2 -2  4 ]

q = [2; 2; -2; -6]

myfunc(x) = M*x + q

n = 4
lb = zeros(n)
ub = 100*ones(n)

path_options(   "convergence_tolerance 1e-2",
                "output yes",
                "time_limit 3600"      )

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

path_options(   "convergence_tolerance 1e-2",
                "output no",
                "time_limit 3600"      )

status, z, f = solveMCP(myfunc, lb, ub)

@show status
@show z
@show f

@test isapprox(z, [2.8, 0.0, 0.8, 1.2])
@test status == :Solved
