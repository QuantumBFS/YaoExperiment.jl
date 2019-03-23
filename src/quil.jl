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
quil(blk::RotationGate{<:Any, <:Any, <:SWAPGate}, info::QuilInfo) = "P$(quil(blk.block, info))($(blk.theta))"  # @
quil(blk::ShiftGate, info::QuilInfo) = "PHASE($(blk.theta))"
_cstring(blk::ControlBlock) = prod(v==1 ? "C" : "¬C" for v in blk.vals)
function quil(blk::ControlBlock, info::QuilInfo)
    _cstring(blk) * quil(blk.block, info) > (blk.ctrl_qubits..., blk.addrs...)/info
end
quil(blk::ControlBlock{<:Any, <:XGate}, info::QuilInfo) = _cstring(blk) * "NOT" > (blk.ctrl_qubits..., blk.addrs...)/info  # @
function quil(blk::Concentrator, info::QuilInfo)
    info = copy(info)
    info.address_map = info.address_map[blk.usedbits]
    quil(blk.block, info)
end

function quil(blk::Union{ChainBlock, Sequential}, info::QuilInfo)
    join([quil(b, info) for b in subblocks(blk)], "\n")
end

# TODO:
#
# QUIL: https://github.com/rigetti/pyquil/blob/master/pyquil/gates.py
# Quantum ->
# CPHASE00 -> diag([exp(1j*phi), 1, 1, 1])
# CPHASE01 -> diag([1, exp(1j*phi), 1, 1])
# CPHASE10 -> diag([1, 1, exp(1j*phi), 1])
# ISWAP -> [1000; 00i0; 0i00; 0001]
#
# CLASSICAL ->
# WAIT, NOP, HALT, RESET
# TRUE, FALSE, NEG, NOT, AND, OR, IOR, XOR, MOVE, EXCHANGE, LOAD, STORE, CONVERT, ADD, SUB, MUL, DIV, EQ, LT, LE, GT, GE
#
# if statement

# NOTE: give up support to roller
