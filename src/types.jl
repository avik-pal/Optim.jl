type OptimizationState
    state::Any
    f_state::Float64
    iteration::Int64
    metadata::Dict
end
function OptimizationState(s::Any, f::Float64, i::Integer)
    OptimizationState(s, f, i, Dict())
end

type OptimizationTrace
    states::Vector{OptimizationState}
end
OptimizationTrace() = OptimizationTrace(Array(OptimizationState, 0))

type OptimizationResults
    method::String
    initial_x::Vector{Float64}
    minimum::Vector{Float64}
    f_minimum::Float64
    iterations::Int64
    f_converged::Bool
    gr_converged::Bool
    trace::OptimizationTrace
    f_calls::Int64
    g_calls::Int64
    f_values::Vector{Float64}
end

immutable DifferentiableFunction
    f::Function
    g!::Function
    fg!::Function
end

immutable TwiceDifferentiableFunction
    f::Function
    g!::Function
    fg!::Function
    h!::Function
end

function show(io::IO, o_trace::OptimizationState)
    print(io, "State of Optimization Algorithm\n")
    print(io, " * Iteration: $(o_trace.iteration)\n")
    print(io, " * State: $(o_trace.state)\n")
    print(io, " * f(State): $(o_trace.f_state)\n")
    print(io, " * Additional Information:\n")
    for (key, value) in o_trace.metadata
        @printf io "   * %s: %s\n" key value
    end
end
function push!(tr::OptimizationTrace, s::OptimizationState)
    push!(tr.states, s)
end
function getindex(tr::OptimizationTrace, i::Integer)
    getindex(tr.states, i)
end
function setindex!(tr::OptimizationTrace,
                   s::OptimizationState,
                   i::Integer)
    setindex!(tr.states, s, i)
end
function show(io::IO, o_trace::OptimizationTrace)
    for state in o_trace.states
        show(io, state)
    end
end

function show(io::IO, results::OptimizationResults)
    print(io, "Results of Optimization Algorithm\n")
    print(io, " * Algorithm: $(results.method)\n")
    print(io, " * Starting Point: $(results.initial_x)\n")
    print(io, " * Minimum: $(results.minimum)\n")
    print(io, " * Value of Function at Minimum: $(results.f_minimum)\n")
    print(io, " * Iterations: $(results.iterations)\n")
    print(io, " * Function Convergence: $(results.f_converged)\n")
    print(io, " * Gradient Convergence: $(results.gr_converged)\n")
    print(io, " * Objective Function Calls: $(results.f_calls)\n")
    print(io, " * Gradient Call: $(results.g_calls)")
end

function DifferentiableFunction(f::Function)
    function g!(x::Vector, storage::Vector)
        Calculus.finite_difference!(f, x, storage, :central)
        return
    end
    function fg!(x::Vector, storage::Vector)
        g!(x, storage)
        return f(x)
    end
    return DifferentiableFunction(f, g!, fg!)
end

function DifferentiableFunction(f::Function, g!::Function)
    function fg!(x::Vector, storage::Vector)
        g!(x, storage)
        return f(x)
    end
    return DifferentiableFunction(f, g!, fg!)
end

function TwiceDifferentiableFunction(f::Function)
    function g!(x::Vector, storage::Vector)
        Calculus.finite_difference!(f, x, storage, :central)
        return
    end
    function fg!(x::Vector, storage::Vector)
        g!(x, storage)
        return f(x)
    end
    function h!(x::Vector, storage::Matrix)
        Calculus.finite_difference_hessian!(f, x, storage)
        return
    end
    return TwiceDifferentiableFunction(f, g!, fg!, h!)
end

function TwiceDifferentiableFunction(f::Function,
                                     g!::Function,
                                     h!::Function)
    function fg!(x::Vector, storage::Vector)
        g!(x, storage)
        return f(x)
    end
    return TwiceDifferentiableFunction(f, g!, fg!, h!)
end

# A cache for results from line search methods (to avoid recomputation)
type LineSearchResults{T}
    alpha::Vector{T}
    value::Vector{T}
    slope::Vector{T}
    nfailures::Int
end
LineSearchResults{T}(::Type{T}) = LineSearchResults(T[], T[], T[], 0)

Base.length(lsr::LineSearchResults) = length(lsr.alpha)
function Base.push!{T}(lsr::LineSearchResults{T}, a::T, v::T, d::T)
    push!(lsr.alpha, a)
    push!(lsr.value, v)
    push!(lsr.slope, d)
end
function clear!(lsr::LineSearchResults)
    N = length(lsr.alpha)
    delete!(lsr.alpha, 1:N)
    delete!(lsr.value, 1:N)
    delete!(lsr.slope, 1:N)
    # nfailures is deliberately not set to 0
end
