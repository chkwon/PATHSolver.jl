# A PATH.jl implementation of the GAMS model transmcp.gms: transporation model
# as equilibrium problem.
#
# https://www.gams.com/latest/gamslib_ml/libhtml/gamslib_transmcp.html
#
# Transportation model as equilibrium problem (TRANSMCP,SEQ=126)
#
#    Dantzig's original transportation model (TRNSPORT) is
#    reformulated as a linear complementarity problem.  We first
#    solve the model with fixed demand and supply quantities, and
#    then we incorporate price-responsiveness on both sides of the
#    market.
#
# Dantzig, G B, Chapter 3.3. In Linear Programming and Extensions.
# Princeton University Press, Princeton, New Jersey, 1963.

using JuMP
using PATH
using Test

capacity = Dict(
    "seattle"   => 350,
    "san-diego" => 600
)

demand = Dict(
    "new-york" => 325,
    "chicago"  => 300,
    "topeka"   => 275
)

distance = Dict(
    ("seattle" => "new-york")   => 2.5,
    ("seattle" => "chicago")    => 1.7,
    ("seattle" => "topeka")     => 1.8,
    ("san-diego" => "new-york") => 2.5,
    ("san-diego" => "chicago")  => 1.8,
    ("san-diego" => "topeka")   => 1.4
)

plants = collect(keys(capacity))
markets = collect(keys(demand))

model = Model(with_optimizer(PATH.Optimizer))

@variables(model, begin
    w[i in plants] >= 0
    p[j in markets] >= 0
    x[i in plants, j in markets] >= 0
end)

@expressions(model, begin
    profit[i in plants, j in markets], w[i] + 90 * distance[i => j] / 1000 - p[j]
    supply[i in plants], capacity[i] - sum(x[i, j] for j in markets)
    fxdemand[j in markets], sum(x[i, j] for i in plants) - demand[j]
end)

@constraints(model, begin
    profit ⟂ x
    supply ⟂ w
    fxdemand ⟂ p
end)

optimize!(model)

@test value(p["new-york"]) ≈ 0.225 atol=1e-3
@test value(p["chicago"])  ≈ 0.153 atol=1e-3
@test value(p["topeka"])   ≈ 0.126 atol=1e-3
