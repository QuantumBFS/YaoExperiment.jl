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

gatecount!(c::TrivilGate, storage::AbstractDict) = storage
gatetime(::Val, d::Wait) = d.t
gatetime(::Val{:Sym}, d::Wait) = d.t
print_block(io::IO, d::Wait) = print(io, "Wait → $(d.t)")
