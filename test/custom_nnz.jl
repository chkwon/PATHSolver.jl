@testset "custom nnz" begin

    # define functions to calculate residual
    function index(m, n, M,N)
        return (n-1)*M + m
    end

    function alln(m, M,N)
        return [index(m, n, M,N) for n = 1:N]
    end

    function allm(n, M,N)
        return [index(m, n, M,N) for m = 1:M]
    end

    function f(c,h,γ)
        return (c.^γ + h.^γ).^(1./γ)
    end

    function clearing(q, v, g, M, N)
        ret = zeros(eltype(q),N)
        for n = 1:N
            ret[n] = g[n] - sum(q[allm(n, M, N)].*v)
        end
        return ret
    end

    function wages(q, ch, ρ, γ, r, pc, M, N)
        w = zeros(eltype(q),M*N)
        Q = Qvec(q, M, N)
        yj = matchoutput(ch[:,2],ch[:,1],ρ, γ,r)
        kj = zeros(M*N)

         for m = 1:M
            for n = 1:N
                i = index(m, n, M,N)
                ip1 = index(m, n+1, M,N)
                if q[i] > 0.
                    w[i] = pc[m]*yj[i] - r*kj[i]
                    for nprime in 1:n-1
                        iprime = index(m, nprime, M,N)
                        iprimep1 = index(m, nprime+1, M,N)
                        w[i] -= exp(-(Q[iprimep1]-Q[i]))* (1-exp(-q[iprime])) * max(0., pc[m]*yj[iprime] - r*kj[iprime])
                    end
                    w[i] *= q[i]*exp(-q[i])/(1-exp(-q[i]))
                end
            end
        end
        return w
    end

    function expected_u(q, w, M, N)
        Q = Qvec(q, M, N)
        u = zeros(eltype(q),M*N)
        for m = 1:M
            for n = 1:N
                i = index(m, n, M,N)
                if n < N
                    ip1 = index(m, n+1, M,N)
                    u[i] = exp(-Q[ip1])  * w[i]
                else
                    u[i] =  w[i]
                end
                if q[i]>1e-9
                    u[i] = u[i]*(1-exp(-q[i]))/q[i]
                end
            end
        end
        return u
    end

    function allocation(q, ch, ρ, γ, v, g, r, σ, M, N)
        e = employment(q, v, M, N)
        yj = e.*matchoutput(ch[:,2],ch[:,1],ρ, γ,r)
        yc = [sum(yj[alln(m, M, N)]) for m = 1:M]
        yf = sum(yc.^((σ-1)/σ))^((σ/(σ-1)))
        pc = (yc./yf).^(-1/σ)

        w = wages(q, ch, ρ, γ, r, pc, M, N)
        u = expected_u(q, w, M, N)
        return w, u, pc, yc, yf, e
    end

    function matchoutput(h,c,ρ, γ,r)
        fj = f(c,h,γ)
        k = 0.
        return (fj.^ρ + k.^ρ).^(1./ρ)
    end

    function Qvec(q, M, N)
        Q = zeros(eltype(q),M*N)
        for m = 1:M
            for n=N:-1:1
                i = index(m, n, M,N)
                if n == N
                    Q[i] = q[i]
                else
                    ip1 = index(m, n+1, M,N)
                    Q[i] = Q[ip1] + q[i]
                end
            end
        end
        return Q
    end


    function employment(q, v, M, N)
        # employment
        Q = Qvec(q, M, N)
        e = zeros(eltype(q),M*N)
        qi = 0.
        Qp1 = 0.
        i = 0
        for m = 1:M
            for n=1:N
                i = index(m, n, M, N)
                if n < N
                    Qp1 = Q[index(m, n+1, M, N)]
                else
                    Qp1 = 0.
                end
                if q[i] > 0.
                    e[i] = v[m]*exp(-Qp1) * (1-exp(-q[i]))
                end
            end
        end
        return e
    end

    function resid(qu, N, M, ch, ρ, γ, v, g, r, σ)
        res = zeros(eltype(qu), size(qu))
        q = qu[1:end-N]
        umax = qu[end-N+1:end]
        w, u, pc, yc, yf, e = allocation(q, ch, ρ, γ, v, g, r, σ, M, N)
        res[1:end-N] = -[u[index(m,n, M, N)] - umax[n] for n=1:N, m=1:M][:]
        res[end-N+1:end] =  clearing(q, v, g, M, N)
        return res
    end

    # Set parameters
    # workers
    N = 5
    # jobs
    M = 5
    c = linspace(1.,2.,M)
    if N > 1
        h = linspace(0.0,2.,N)
    else
        h = [1.]
    end

    ch = hcat(repeat(c, outer=N), repeat(h, inner=M))
    γ = -.5
    r = .01
    σ = 2.

    qguess = ones(M*N)
    uguess = 1e-6*ones(N)
    quguess = vcat(qguess, uguess)
    ρ = ones(qguess)*0.5

    v = ones(M)
    g = ones(N)

    # wrapper to objective function obj(x) to be set to zero
    obj(x) = resid(x, N, M, ch, ρ, γ, v, g, r, σ)

    # set bounds for x
    lower = vcat(zeros(M*N), zeros(N))
    upper = 10000.*ones(M*N+N)

    status, zero, f_zero = solveMCP(obj, lower, upper, quguess; nnz=length(lower)^2)

end
