using PATH, Test

using MathOptInterface
const MOI = MathOptInterface

@testset "MOI.Name" begin
    model = PATH.Optimizer()
    @test MOI.get(model, MOI.SolverName()) == PATH.c_api_Path_Version()
end

@testset "MOI.AbstractOptimizer" begin
    @test PATH.Optimizer() isa MOI.AbstractOptimizer
end

@testset "RawParameter" begin
    model = PATH.Optimizer()
    @test MOI.get(model, MOI.RawParameter("output")) === nothing
    MOI.set(model, MOI.RawParameter("output"), "no")
    @test MOI.get(model, MOI.RawParameter("output")) == "no"
end

@testset "Invalid models" begin
    @testset "Infeasible" begin
        model = PATH.Optimizer()
        x = MOI.add_variable(model)
        MOI.add_constraint(model, MOI.SingleVariable(x), MOI.Interval(0.0, -1.0))
        MOI.optimize!(model)
        @test MOI.get(model, MOI.TerminationStatus()) == MOI.INVALID_MODEL
        @test MOI.get(model, MOI.RawStatusString()) == "Problem has a bound error"
        @test MOI.get(model, MOI.PrimalStatus()) == MOI.UNKNOWN_RESULT_STATUS
    end
    @testset "Binary" begin
        model = PATH.Optimizer()
        x = MOI.add_variable(model)
        @test_throws(
            MOI.UnsupportedConstraint,
            MOI.add_constraint(model, MOI.SingleVariable(x), MOI.ZeroOne())
        )
    end
    @testset "wrong dimension" begin
        model = PATH.Optimizer()
        x = MOI.add_variable(model)
        MOI.add_constraint(
            model,
            MOI.VectorAffineFunction(
                MOI.VectorAffineTerm{Float64}[],
                [0.0]
            ),
            MOI.Complements(1)
        )
        @test_throws(
            ErrorException(
                "Dimension of constant vector 1 does not match the required dimension of " *
                "the complementarity set 2."
            ),
            MOI.optimize!(model)
        )
    end
    @testset "non-zero variable offset" begin
        model = PATH.Optimizer()
        x = MOI.add_variable(model)
        MOI.add_constraint(
            model,
            MOI.VectorAffineFunction(
                [
                    MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, x)),
                    MOI.VectorAffineTerm(2, MOI.ScalarAffineTerm(1.0, x))
                ],
                [0.0, 1.0]
            ),
            MOI.Complements(1)
        )
        @test_throws(
            ErrorException(
                "VectorAffineFunction malformed: a constant associated with a " *
                "complemented variable is not zero: [1.0]."
            ),
            MOI.optimize!(model)
        )
    end
    @testset "output dimension too large" begin
        model = PATH.Optimizer()
        x = MOI.add_variable(model)
        MOI.add_constraint(
            model,
            MOI.VectorAffineFunction(
                [
                    MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, x)),
                    MOI.VectorAffineTerm(3, MOI.ScalarAffineTerm(1.0, x))
                ],
                [0.0, 0.0]
            ),
            MOI.Complements(1)
        )
        @test_throws(
            ErrorException("VectorAffineFunction malformed: output_index 3 is too large."),
            MOI.optimize!(model)
        )
    end
    @testset "missing complement variable" begin
        model = PATH.Optimizer()
        x = MOI.add_variable(model)
        MOI.add_constraint(
            model,
            MOI.VectorAffineFunction(
                [
                    MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, x))
                ],
                [0.0, 0.0]
            ),
            MOI.Complements(1)
        )
        @test_throws(
            ErrorException("VectorAffineFunction malformed: expected variable in row 2."),
            MOI.optimize!(model)
        )
    end
    @testset "output dimension too large" begin
        model = PATH.Optimizer()
        x = MOI.add_variable(model)
        MOI.add_constraint(
            model,
            MOI.VectorAffineFunction(
                [
                    MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, x)),
                    MOI.VectorAffineTerm(2, MOI.ScalarAffineTerm(2.0, x))
                ],
                [0.0, 0.0]
            ),
            MOI.Complements(1)
        )
        @test_throws(
            ErrorException(
                "VectorAffineFunction malformed: variable $(x) has a coefficient that is " *
                "not 1 in row 2 of the VectorAffineFunction."
            ),
            MOI.optimize!(model)
        )
    end
    @testset "variable in multiple constraints" begin
        model = PATH.Optimizer()
        x = MOI.add_variable(model)
        MOI.add_constraint(
            model,
            MOI.VectorAffineFunction(
                [
                    MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, x)),
                    MOI.VectorAffineTerm(2, MOI.ScalarAffineTerm(1.0, x)),
                    MOI.VectorAffineTerm(3, MOI.ScalarAffineTerm(1.0, x)),
                    MOI.VectorAffineTerm(4, MOI.ScalarAffineTerm(1.0, x))
                ],
                [0.0, 0.0, 0.0, 0.0]
            ),
            MOI.Complements(2)
        )
        @test_throws(
            ErrorException(
                "The variable $(x) appears in more than one complementarity constraint."
            ),
            MOI.optimize!(model)
        )
    end
end

@testset "Example 1" begin
    model = PATH.Optimizer()
    MOI.set(model, MOI.RawParameter("time_limit"), 60)
    @test MOI.supports(model, MOI.Silent()) == true
    @test MOI.get(model, MOI.Silent()) == false
    MOI.set(model, MOI.Silent(), true)
    @test MOI.get(model, MOI.Silent()) == true
    x = MOI.add_variables(model, 4)
    @test MOI.get(model, MOI.VariablePrimalStart(), x[1]) === nothing
    MOI.add_constraint.(model, MOI.SingleVariable.(x), MOI.Interval(0.0, 10.0))
    MOI.set.(model, MOI.VariablePrimalStart(), x, 0.0)
    M = Float64[
        0  0 -1 -1;
        0  0  1 -2;
        1 -1  2 -2;
        1  2 -2  4
    ]
    q = [2; 2; -2; -6]
    for i in 1:4
        terms = [
            MOI.VectorAffineTerm(2, MOI.ScalarAffineTerm(1.0, x[i]))
        ]
        for j in 1:4
            iszero(M[i, j]) && continue
            push!(
                terms,
                MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(M[i, j], x[j]))
            )
        end
        MOI.add_constraint(
            model,
            MOI.VectorAffineFunction(terms, [q[i], 0.0]),
            MOI.Complements(1)
        )
    end
    @test MOI.get(model, MOI.TerminationStatus()) == MOI.OPTIMIZE_NOT_CALLED
    @test MOI.get(model, MOI.PrimalStatus()) == MOI.NO_SOLUTION
    @test MOI.get(model, MOI.RawStatusString()) == "MOI.optimize! was not called yet"
    MOI.optimize!(model)
    @test MOI.get(model, MOI.TerminationStatus()) == MOI.LOCALLY_SOLVED
    @test MOI.get(model, MOI.PrimalStatus()) == MOI.FEASIBLE_POINT
    @test MOI.get(model, MOI.RawStatusString()) == "The problem was solved"
    x_val = MOI.get.(model, MOI.VariablePrimal(), x)
    @test isapprox(x_val, [2.8, 0.0, 0.8, 1.2])
end
