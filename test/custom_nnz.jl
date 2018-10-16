@testset "custom nnz (number of non-zeros)" begin

    using Calculus

    L = 3
    N = 2*L

    X1 = [n*l for n=1:N, l=1:L]
    X2 = [n*l for n=1:N, l=1:L]
    β1 = range(-1., stop=1., length=L)
    β2 = ones(L)

    # equation depends on β2 only if β1 is positive, so jacobian will have varying number of elements depending on β1
    y = X1*β1 + X2 * ((β1.>0) .* β2)

    function resid(par)
        return y - (X1*par[1:L] + X2 * ((par[1:L].>0) .* par[L+1:end]))
    end
    lower = -500*ones(L*2)
    upper = 500*ones(L*2)
    guess = -300*ones(L*2)

    # number of non-zero elements in Jacobian for negative/positive guess
    nnz1 = PATHSolver.count_nonzeros(Calculus.jacobian(resid, -ones(L*2), :central))
    nnz2 = PATHSolver.count_nonzeros(Calculus.jacobian(resid, ones(L*2), :central))
    @test nnz2>nnz1

    jac(par) = Calculus.jacobian(resid, par, :central)
    # Calculus jacobian used
    status, zero, f_zero = solveMCP(resid, jac, lower, upper, guess; nnz=length(lower)^2)
    @test status == :Solved

    # ForwardDiff jacobian
    status, zero, f_zero = solveMCP(resid, lower, upper, guess; nnz=length(lower)^2)
    @test status == :Solved

end
