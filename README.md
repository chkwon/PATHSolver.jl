# PATHSolver.jl

[![PATHSolver](http://pkg.julialang.org/badges/PATHSolver_0.4.svg)](http://pkg.julialang.org/?pkg=PATHSolver)
[![PATHSolver](http://pkg.julialang.org/badges/PATHSolver_0.5.svg)](http://pkg.julialang.org/?pkg=PATHSolver)
[![PATHSolver](http://pkg.julialang.org/badges/PATHSolver_0.6.svg)](http://pkg.julialang.org/?pkg=PATHSolver)

[![Build Status](https://travis-ci.org/chkwon/PATHSolver.jl.svg?branch=master)](https://travis-ci.org/chkwon/PATHSolver.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/ul9rb8v2rsxm445d?svg=true)](https://ci.appveyor.com/project/chkwon/pathsolver-jl)
[![Coverage Status](https://coveralls.io/repos/github/chkwon/PATHSolver.jl/badge.svg?branch=master)](https://coveralls.io/github/chkwon/PATHSolver.jl?branch=master)



This package provides a Julia wrapper of [the PATH Solver](http://pages.cs.wisc.edu/~ferris/path.html) for solving [Mixed Complementarity Problems (MCP)](https://en.wikipedia.org/wiki/Mixed_complementarity_problem). This package requires compiled libraries available in [ampl/pathlib](https://github.com/ampl/pathlib) and [PathJulia](https://github.com/chkwon/PathJulia).

This package (well the PATH Solver) solves the MCP of the following form:
```
lb ≤ x ≤ ub ⟂ F(x)
```
which means
- `x = lb`, then `F(x) ≥ 0`
- `lb < x < ub`, then `F(x) = 0`
- `x = ub`, then `F(x) ≤ 0`


# License

Without a license, the PATH Solver can solve problem instances up to with up to 300 variables and 2000 non-zeros. For larger problems, the web page of the PATH Solver provides a temporary license that is valid for a year. A new license is provided each year in the web page. Visit the [license page](http://pages.cs.wisc.edu/~ferris/path/LICENSE) of the PATH Solver.

For example, in Mac OS X: Edit your `.bash_profile` file. For example, if you have `Atom` editor:
```bash
atom ~/.bash_profile
```
and add the following two lines:
```bash
export PATH_LICENSE_STRING="---------------------------------------------------------------"
```
You can obtain the most recent `PATH_LICENSE_STRING` from [the website of the PATH Solver](http://pages.cs.wisc.edu/~ferris/path/LICENSE). To reflect the change:
```bash
source ~/.bash_profile
```


# Installation

To install,
```julia
Pkg.add("PATHSolver")
```
and to test if it works,
```julia
Pkg.test("PATHSolver")
```

To use algebraic modeling language for MCP, install and use the [Complementarity.jl](https://github.com/chkwon/Complementarity.jl) package.


# Example

This example solves a Linear Complementarity Problem (LCP) in the form of:

```
0 ≤ x ⟂ F(x) ≥ 0
```

or

```
F(x)' x = 0
F(x) ≥ 0
x ≥ 0
```
when `F(x) = Mx + q`.

```julia
using PATHSolver

M = [0  0 -1 -1 ;
     0  0  1 -2 ;
     1 -1  2 -2 ;
     1  2 -2  4 ]

q = [2; 2; -2; -6]

myfunc(x) = M*x + q

n = 4
lb = zeros(n)
ub = 100*ones(n)

options(convergence_tolerance=1e-2, output=:yes, time_limit=3600)


z, f = solveMCP(myfunc, lb, ub)
```

You can also supply a function for Jacobian:
```julia
myjac(x) = M
z, f = solveMCP(myfunc, myjac, lb, ub)
```
When the Jacobian function is not supplied, it uses the automatic differentiation functionality of [ForwardDiff.jl](https://github.com/JuliaDiff/ForwardDiff.jl).


When the problem is a **linear** complementarity problem (LCP), one can use `solveLCP`:
```julia
z, f = solveLCP(myfunc, lb, ub)
```
To supply the Jacobian matrix:
```julia
z, f = solveLCP(myfunc, M, lb, ub)
```
These `solveLCP` functions do not evaluate the derivatives during iterations.


The result is:
```
Path 4.7.03: Standalone-C Link
4 row/cols, 12 non-zeros, 75.00% dense.
Reading options file path.opt
 > convergence_tolerance 1e-2
 > output yes
 > time_limit 3600
Read of options file complete.
Path 4.7.03 (Thu Jan 24 15:44:03 2013)
Written by Todd Munson, Steven Dirkse, and Michael Ferris
INITIAL POINT STATISTICS
Maximum of X. . . . . . . . . .  0.0000e+00 var: (x[    1])
Maximum of F. . . . . . . . . .  6.0000e+00 eqn: (f[    4])
Maximum of Grad F . . . . . . .  4.0000e+00 eqn: (f[    4])
                                            var: (x[    4])
INITIAL JACOBIAN NORM STATISTICS
Maximum Row Norm. . . . . . . .  9.0000e+00 eqn: (f[    4])
Minimum Row Norm. . . . . . . .  2.0000e+00 eqn: (f[    1])
Maximum Column Norm . . . . . .  9.0000e+00 var: (x[    4])
Minimum Column Norm . . . . . .  2.0000e+00 var: (x[    1])
Crash Log
major  func  diff  size  residual    step       prox   (label)
    0     0             1.2295e+01             0.0e+00 (f[    4])
    1     2     4     2 1.0267e+01  8.0e-01    0.0e+00 (f[    1])
    2     3     2     4 8.4839e-01  1.0e+00    0.0e+00 (f[    4])
    3     4     0     3 4.4409e-16  1.0e+00    0.0e+00 (f[    3])
pn_search terminated: no basis change.
Major Iteration Log
major minor  func  grad  residual    step  type prox    inorm  (label)
    0     0     5     4 4.4409e-16           I 0.0e+00 4.4e-16 (f[    3])
FINAL STATISTICS
Inf-Norm of Complementarity . .  3.5527e-16 eqn: (f[    3])
Inf-Norm of Normal Map. . . . .  4.4409e-16 eqn: (f[    3])
Inf-Norm of Fischer Function. .  4.4409e-16 eqn: (f[    3])
Inf-Norm of Grad Fischer Fcn. .  8.8818e-16 eqn: (f[    3])
Two-Norm of Grad Fischer Fcn. .  1.4043e-15
FINAL POINT STATISTICS
Maximum of X. . . . . . . . . .  2.8000e+00 var: (x[    1])
Maximum of F. . . . . . . . . .  4.0000e-01 eqn: (f[    2])
Maximum of Grad F . . . . . . .  4.0000e+00 eqn: (f[    4])
                                            var: (x[    4])
 ** EXIT - solution found.
Major Iterations. . . . 0
Minor Iterations. . . . 0
Restarts. . . . . . . . 0
Crash Iterations. . . . 3
Gradient Steps. . . . . 0
Function Evaluations. . 5
Gradient Evaluations. . 4
Basis Time. . . . . . . 0.000046
Total Time. . . . . . . 0.060200
Residual. . . . . . . . 4.440892e-16
Residual of 4.44089e-16 is OK
z = [2.8,0.0,0.8,1.2]
f = [0.0,0.40000000000000013,4.440892098500626e-16,0.0]
```

# Labels

In the above output, the variable and function names are given as `x` and `f` automatically by the solver. If you want to give own names, you can do it as follows:
```julia
var_name = ["first var", "second var", "third var", "fourth var"]
con_name = ["func 1", "func 2", "func 3", "func 4"]

status, z, f = solveMCP(myfunc, lb, ub)
status, z, f = solveMCP(myfunc, lb, ub, var_name)
status, z, f = solveMCP(myfunc, lb, ub, var_name, con_name)
status, z, f = solveMCP(myfunc, myjac, lb, ub)
status, z, f = solveMCP(myfunc, myjac, lb, ub, var_name)
status, z, f = solveMCP(myfunc, myjac, lb, ub, var_name, con_name)
```

# Solver Options
Before solving the problem, you can set the solver options; for example:
```julia
options(convergence_tolerance=1e-2, output=:yes, time_limit=3600, lemke_start=:first, nms_searchtype=:line)
```
The full list of options is available at: http://pages.cs.wisc.edu/~ferris/path/options.pdf
