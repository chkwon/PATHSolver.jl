# PATH.jl

A Julia interface to the [PATH solver](http://pages.cs.wisc.edu/~ferris/path.html).

[![][travis-img]][travis-url]

[travis-img]: https://api.travis-ci.com/odow/PATH.jl.svg?branch=master
[travis-url]: https://travis-ci.com/odow/PATH.jl

## Installation

`PATH.jl` is not registered yet, so you will need to add it like so:
```julia
] add https://github.com/odow/PATH.jl
```
By default, `PATH.jl` will download a copy of the underlying PATH solver. To use
a different version of PATH, see the Manual Installation section below.

## License

Without a license, the PATH Solver can solve problem instances up to with up
to 300 variables and 2000 non-zeros. For larger problems,
[this web page](http://pages.cs.wisc.edu/~ferris/path/julia/LICENSE) provides a
temporary license that is valid for a year.

You can either store the license in the `PATH_LICENSE_STRING` environment
variable, or you can use the `PATH.c_api_License_SetString` function immediately
after importing the `PATH` package:
```julia
using PATH
PATH.c_api_License_SetString("<LICENSE STRING>")
```
where `<LICENSE STRING>` is replaced by the current license string.

## Example usage

```julia
julia> using JuMP, PATH

julia> M = [
           0  0 -1 -1
           0  0  1 -2
           1 -1  2 -2
           1  2 -2  4
       ]
4×4 Array{Int64,2}:
 0   0  -1  -1
 0   0   1  -2
 1  -1   2  -2
 1   2  -2   4

julia> q = [2, 2, -2, -6]
4-element Array{Int64,1}:
  2
  2
 -2
 -6

julia> model = Model(PATH.Optimizer)
A JuMP Model
Feasibility problem with:
Variables: 0
Model mode: AUTOMATIC
CachingOptimizer state: EMPTY_OPTIMIZER
Solver name: Path 5.0.00

julia> set_optimizer_attribute(model, "output", "no")

julia> @variable(model, x[1:4] >= 0)
4-element Array{VariableRef,1}:
 x[1]
 x[2]
 x[3]
 x[4]

julia> @constraint(model, M * x .+ q ⟂ x)
[-x[3] - x[4] + 2, x[3] - 2 x[4] + 2, x[1] - x[2] + 2 x[3] - 2 x[4] - 2, x[1] + 2 x[2] - 2 x[3] + 4 x[4] - 6, x[1], x[2], x[3], x[4]] ∈ MOI.Complements(4)

julia> optimize!(model)
Reading options file /var/folders/bg/dzq_hhvx1dxgy6gb5510pxj80000gn/T/tmpiSsCRO
Read of options file complete.

Path 5.0.00 (Mon Aug 19 10:57:18 2019)
Written by Todd Munson, Steven Dirkse, Youngdae Kim, and Michael Ferris

julia> value.(x)
4-element Array{Float64,1}:
 2.8
 0.0
 0.7999999999999998
 1.2

julia> termination_status(model)
LOCALLY_SOLVED::TerminationStatusCode = 4
```

## Factorization methods

By default, `PATH.jl` will download the [LUSOL](https://web.stanford.edu/group/SOL/software/lusol/)
shared library. To use LUSOL, set the following options:
```julia
model = Model(PATH.Optimizer)
set_optimizer_attribute(model, "factorization_method", "blu_lusol")
set_optimizer_attribute(model, "factorization_library_name", PATH.LUSOL_LIBRARY_PATH)
```

To use `factorization_method umfpack` you will need the umfpack shared lib that
is available directly from the [developers of that code for academic use](http://faculty.cse.tamu.edu/davis/suitesparse.html).

## Manual installation

By default `PATH.jl` will download a copy of the `libpath` library. If you
already have one installed and want to use that, set the `PATH_JL_LOCATION`
environment variable to point to the `libpath50.xx` library, then run
`Pkg.build("PATH")`.
