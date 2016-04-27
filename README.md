# PATHSolver.jl

[![Build Status](https://travis-ci.org/chkwon/PATHSolver.jl.svg?branch=master)](https://travis-ci.org/chkwon/PATHSolver.jl)
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


# OS X only

This package currently supports Mac OS X only.

I need help for Linux and Windows. The installation process basically downloads `libpath47.dylib` from [ampl/pathlib](https://github.com/ampl/pathlib) and `libpath47julia.dylb` from [PathJulia](https://github.com/chkwon/PathJulia), copies `libgfortran.3.dylib` from PathJulia, and places them in `~/.julia/v0.4/PATH/deps/usr/lib/`. Hopefully, the installation procedure can be simplified. I think for Windows and Linux, similar processes can be used.


# Installation


To install PATHSolver.jl, follow the instructions given below:

**Step 1.** Edit your `.bash_profile` file. For example, if you have `Atom` editor:
```bash
atom ~/.bash_profile
```
and add the following two lines:
```bash
export PATH_LICENSE_STRING="---------------------------------------------------------------"
export DYLD_LIBRARY_PATH=${DYLD_LIBRARY_PATH}:"/Users/chkwon/.julia/v0.4/PATH/deps/usr/lib/"
```
You can obtain the most recent `PATH_LICENSE_STRING` from [the website of the PATH Solver](http://pages.cs.wisc.edu/~ferris/path/LICENSE). In the above, change `chkwon` to your user name. To reflect the change:
```bash
source ~/.bash_profile
```

**Step 2.** Run `julia` and install the package:
```julia
julia> Pkg.clone("https://github.com/chkwon/PATHSolver.jl.git")
julia> Pkg.build("PATHSolver")
```
It should run without any problem. If the installation process fails, check your `DYLD_LIBRARY_PATH` again, and then build the package again.
```julia
julia> Pkg.build("PATHSolver")
```

**Step 3.** Test the installation:
```julia
julia> Pkg.test("PATHSolver")
```


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

path_options(   "convergence_tolerance 1e-2",
                "output yes",
                "time_limit 3600"      )

z, f = solveMCP(myfunc, lb, ub)
```

You can also supply a function for Jacobian:
```julia
myjac(x) = M
z, f = solveMCP(myfunc, myjac, lb, ub)
```
When the Jacobian function is not supplied, it uses the automatic differentiation functionality of [ForwardDiff.jl](https://github.com/JuliaDiff/ForwardDiff.jl).

The result is:
```
Path 4.7.03: Standalone-C Link
4 row/cols, 12 non-zeros, 75.00% dense.

Could not open options file: path.opt
Using defaults.
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
Inf-Norm of Minimum Map . . . .  4.4409e-16 eqn: (f[    3])
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
Basis Time. . . . . . . 0.000026
Total Time. . . . . . . 0.470323
Residual. . . . . . . . 4.440892e-16
Residual of 4.44089e-16 is OK
z = [2.8,0.0,0.8,1.2]
f = [0.0,0.40000000000000013,4.440892098500626e-16,0.0]
```
