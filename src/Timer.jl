using Yao
using Yao.Blocks
import Yao.Blocks: subblocks, chsubblocks, apply!, mat, print_block, print_subblocks, usedbits
using Yao.Blocks: print_prefix, print_tree, print_block
using LuxurySparse

using QuAlgorithmZoo
using Symbolics

# patch identity bits
usedbits(::I2Gate) = []
usedbits(p::PutBlock) = [p.addrs[usedbits(p.block)]...]

const GROUPA = Union{ChainBlock, PutBlock, Concentrator, AbstractDiff, CachedBlock}
const GROUPB = Union{Roller, KronBlock, PauliString}
gatetime(::Val, c::GROUPA) = sum(gatetime, c |> subblocks)
gatetime(::Val, c::GROUPB) = maximum(gatetime, c |> subblocks)
#gatetime(s::Val{:Sym}, c::GROUPA) = invoke(gatetime, Tuple{Val, GROUPA}, s, c)
#gatetime(s::Val{:Sym}, c::GROUPB) = invoke(gatetime, Tuple{Val, GROUPB}, s, c)

gatetime(::Val{:Sym}, c::Union{ControlBlock, Daggered, PrimitiveBlock}) where N = Sym(Symbol(:T,usedbits(c) |> length))
gatetime(s::Val{:Sym}, c::Union{AddBlock, AbstractScale}) = throw(MethodError(gatetime, (s, c)))
gatetime(::Val{:Sym}, c::AbstractMeasure) = Sym(:Tm)
gatetime(::Val{:Sym}, c::MeasureAndReset) = Sym(:Tm) + Sym(:Treset)
gatetime(c::AbstractBlock) = gatetime(Val(:Sym), c)

gatecount(blk::AbstractBlock) = gatecount!(blk, Dict{Type{<:AbstractBlock}, Int}())
gatecount!(c::Union{ChainBlock, KronBlock, Roller, PauliString, PutBlock, Concentrator, AbstractDiff, CachedBlock}, storage::AbstractDict) = (gatecount!.(c |> subblocks, Ref(storage)); storage)
function gatecount!(c::RepeatedBlock, storage::AbstractDict)
    k = typeof(c.block)
    n = length(c.addrs)
    if haskey(storage, k)
        storage[k] += n
    else
        storage[k] = n
    end
    storage
end

function gatecount!(c::Union{PrimitiveBlock, Daggered, ControlBlock}, storage::AbstractDict)
    k = typeof(c)
    if haskey(storage, k)
        storage[k] += 1
    else
        storage[k] = 1
    end
    storage
end

struct Delay{N, T} <: PrimitiveBlock{N, Bool}
    t::T
    Delay{N}(t::T) where {N,T} = new{N, T}(t)
end

mat(d::Delay{N}) where N = IMatrix{1<<N}()
apply!(reg::DefaultRegister, d::Delay) = reg
gatecount!(c::Delay, storage::AbstractDict) = storage
gatetime(::Val, d::Delay) = d.t
gatetime(::Val{:Sym}, d::Delay) = d.t
print_block(io::IO, d::Delay) = print(io, "Delay → $(d.t)")

using Test
@testset "gate count, time" begin
    qc = QFTCircuit(3)
    @test qc |> gatecount |> length == 2
    @test qc |> gatecount |> values |> sum == 6
    @sym T1 T2
    ex = chain(qc, Delay{3}(0.1)) |> gatetime
    @test ex(T1=>1)(T2=>10) |> simplify == 33.1
end
