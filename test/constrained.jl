import Optim
using Base.Test

# Quadratic objective function
# For (A*x-b)^2/2
function quadratic!(x, g, AtA, Atb, tmp)
    calc_grad = !(g === nothing)
    A_mul_B!(tmp, AtA, x)
    v = dot(x,tmp)/2 + dot(Atb,x)
    if calc_grad
        for i = 1:length(g)
            g[i] = tmp[i] + Atb[i]
        end
    end
    return v
end

N = 8
boxl = 2.0
outbox = false
# Generate a problem where the bounds-free solution lies outside of the chosen box
global objective
while !outbox
    A = randn(N,N)
    AtA = A'*A
    b = randn(N)
    x0 = randn(N)
    tmp = similar(x0)
    func = (x, g) -> quadratic!(x, g, AtA, A'*b, tmp)
    objective = Optim.DifferentiableFunction(x->func(x, nothing), (x,g)->func(x,g), func)
    results = Optim.cg(objective, x0)
    results = Optim.cg(objective, results.minimum)  # restart to ensure high-precision convergence
    @test Optim.converged(results)
    g = similar(x0)
    @test func(results.minimum, g) + dot(b,b)/2 < 1e-8
    @test norm(g) < 1e-4
    outbox = any(abs(results.minimum) .> boxl)
end

# fminbox
l = fill(-boxl, N)
u = fill(boxl, N)
x0 = (rand(N)-0.5)*boxl
results = Optim.fminbox(objective, x0, l, u)
@test Optim.converged(results)
g = similar(x0)
objective.fg!(results.minimum, g)
for i = 1:N
    @test abs(g[i]) < 3e-3 || (results.minimum[i] < -boxl+1e-3 && g[i] > 0) || (results.minimum[i] > boxl-1e-3 && g[i] < 0)
end

# nnls
A = [1.0 2.0; 3.0 4.0]
b = [1.0,1.0]
results = Optim.nnls(A, b)
@test norm(results.minimum - [0,0.3]) < 1e-6
