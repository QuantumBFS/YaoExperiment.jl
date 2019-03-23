using Yao
using Yao.Blocks

# NOTE: give up support to roller

mutable struct QuilInfo{VT<:Vector}
    address_map::VT
end

Base.copy(info::QuilInfo) = QuilInfo(info.address_map)

function Base.show(io::IO, ::MIME"quil", blk::AbstractBlock)
    qcode = quil(blk)
    println(io, qcode)
end
quil(blk::AbstractBlock, N::Union{Nothing, Int}=nothing) = quil(blk, QuilInfo(collect(1:(N isa Nothing ? nqubits(blk) : N))))
quil(blk::Union{AbstractDiff, CachedBlock}, info::QuilInfo) = quil(blk |> parent, info)

######################## Basic Buiding Blocks ########################
const BASIC_GATES = [:X, :Y, :Z, :H, :S, :Sdag, :T, :Tdag, :SWAP, :CNOT]

locs2str(locs) = join(["$(i-1)" for i in locs], " ")
floats2str(params) = join(["$p" for p in params], ", ")
args2str(pcounts) = join(["p$i" for i=pcounts], ", ")
# place an operator on some location
import Base: >, /
>(gate::String, locs) = gate * " " * locs2str(locs)
/(locs, info::QuilInfo) = [info.address_map[loc] for loc in locs]

quil(blk::Measure, info::QuilInfo) = "MEASURE" > info.address_map
quil(blk::MeasureAndRemove, info::QuilInfo) = "MEASURE" > info.address_map
quil(blk::MeasureAndReset, info::QuilInfo) = "MEASURE_AND_RESET($(blk.val))" > info.address_map
quil(blk::PutBlock, info::QuilInfo) = quil(blk.block, info) > blk.addrs/info
function quil(blk::Union{KronBlock, PauliString}, info::QuilInfo)
    qs = String[]
    for (g, loc) in zip(blk.blocks, blk |> addrs)
        if !(g isa I2Gate)
            push!(qs, quil(g, info) > loc/info)
        end
    end
    join(qs, "\n")
end
quil(blk::RepeatedBlock, info::QuilInfo) = join([quil(blk.block, info) > loc/info for loc in blk.addrs], "\n")

for G in BASIC_GATES
    GT = Symbol(G, :Gate)
    g = G |> String
    @eval quil(blk::$GT, info::QuilInfo) = "$($g)"
end
quil(blk::I2Gate, info::QuilInfo) = "I"

quil(blk::RotationGate, info::QuilInfo) = "R$(quil(blk.block, info))($(blk.theta))"
quil(blk::ControlBlock, info::QuilInfo) = "C"^length(blk.ctrl_qubits) * quil(blk.block, info) > (blk.ctrl_qubits..., blk.addrs...)/info
function quil(blk::Concentrator, info::QuilInfo)
    info = copy(info)
    info.address_map = info.address_map[blk.usedbits]
    quil(blk.block, info)
end

function quil(blk::Union{ChainBlock, Sequential}, info::QuilInfo)
    join([quil(b, info) for b in subblocks(blk)], "\n")
end

# TODO:
# Basic Elemental Gates
# u1 == z
# u3, u2,
# cu1, cu3
# if statement
