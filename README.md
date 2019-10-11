# PATH.jl

A Julia interface to the [PATH solver](http://pages.cs.wisc.edu/~ferris/path.html).

## Installation

To install PATH, obtain a copy of PATH and set the `PATH_JL_LOCATION`
environment variable.

## License

Without a license, the PATH Solver can solve problem instances up to with up
to 300 variables and 2000 non-zeros. For larger problems,
[this web page](http://pages.cs.wisc.edu/~ferris/path/LICENSE) provides a
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

julia> model = Model(with_optimizer(PATH.Optimizer, output = "no"))
A JuMP Model
Feasibility problem with:
Variables: 0
Model mode: AUTOMATIC
CachingOptimizer state: EMPTY_OPTIMIZER
Solver name: Path 5.0.00

julia> @variable(model, x[1:4] >= 0)
4-element Array{VariableRef,1}:
 x[1]
 x[2]
 x[3]
 x[4]

julia> @constraint(model, [M * x .+ q; x] in PATH.Complements(4))
[-x[3] - x[4] + 2, x[3] - 2 x[4] + 2, x[1] - x[2] + 2 x[3] - 2 x[4] - 2, x[1] + 2 x[2] - 2 x[3] + 4 x[4] - 6, x[1], x[2], x[3], x[4]] ∈ PATH.Complements(4)

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
