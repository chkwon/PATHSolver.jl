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
```
