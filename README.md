# PATH.jl

A Julia interface to the [PATH solver](http://pages.cs.wisc.edu/~ferris/path.html).

## Example usage

```julia
using JuMP, PATH

model = Model(with_optimizer(PATH.Optimizer))
@variable(model, x >= 0)
@constraint(model, [x + 2, x] in PATH.Complements())
optimize!(model)
value(x)
termination_status(model)
```

```julia
using JuMP, PATH

M = [
    0  0 -1 -1
    0  0  1 -2
    1 -1  2 -2
    1  2 -2  4
]

q = [2, 2, -2, -6]

model = Model(with_optimizer(PATH.Optimizer))
@variable(model, x[1:4] >= 0)
@constraint(model, [M * x .+ q; x] in PATH.Complements(4))
optimize!(model)
value.(x)
termination_status(model)
```
