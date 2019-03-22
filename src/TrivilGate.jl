abstract type TrivilGate{N} <: PrimitiveBlock{N, Bool} end

mat(d::TrivilGate{N}) where N = IMatrix{1<<N}()
apply!(reg::DefaultRegister, d::TrivilGate) = reg
Base.adjoint(g::TrivilGate) = g

"""
    Delay{N, T} <: TrivilGate{N}
    Delay{N}(t)

Delay the experimental signals for time `t` (empty run).
"""
struct Delay{N, T} <: TrivilGate{N}
    t::T
    Delay{N}(t::T) where {N,T} = new{N, T}(t)
end
