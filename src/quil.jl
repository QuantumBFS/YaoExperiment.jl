mutable struct AddressInfo{VT<:Vector}
    address_map::VT
end

Base.copy(info::AddressInfo) = AddressInfo(info.address_map)

function Base.show(io::IO, ::MIME"quil", blk::AbstractBlock)
    qcode = quil(blk)
    println(io, qcode)
end
quil(blk::AbstractBlock, N::Union{Nothing, Int}=nothing) = quil(blk, AddressInfo(collect(1:(N isa Nothing ? nqubits(blk) : N))))
quil(blk::Union{Diff, CachedBlock}, info::AddressInfo) = quil(blk |> parent, info)

######################## Basic Buiding Blocks ########################
const BASIC_GATES = [:X, :Y, :Z, :H, :S, :Sdag, :T, :Tdag, :SWAP, :CNOT]

locs2str(locs) = join(["$(i-1)" for i in locs], " ")
floats2str(params) = join(["$p" for p in params], ", ")
args2str(pcounts) = join(["p$i" for i=pcounts], ", ")
# place an operator on some location
import Base: >, /
>(gate::String, locs) = gate * " " * locs2str(locs)
/(locs, info::AddressInfo) = [info.address_map[loc] for loc in locs]

function quil(blk::Measure{N,K,ComputationalBasis}, info::AddressInfo) where {N, K}
    if !(blk.collapseto isa Nothing)
        return "MEASURE_AND_RESET($(blk.val))" > info.address_map[blk.locations]
    elseif !(blk.remove)
        if N == K
            locs = 1:N
        else
            locs = blk.locations
        end
        return "MEASURE" > info.address_map[locs]
    else
        error("unable to parse $blk")
    end
end
quil(blk::PutBlock, info::AddressInfo) = quil(content(blk), info) > blk.locs/info
function quil(blk::Union{KronBlock, PauliString}, info::AddressInfo)
    locs = blk isa PauliString ? (1:nqubits(blk)) : blk.locs
    qs = String[]
    for (g, loc) in zip(subblocks(blk), locs)
        if !(g isa I2Gate)
            push!(qs, quil(g, info) > loc/info)
        end
    end
    join(qs, "\n")
end
quil(blk::RepeatedBlock, info::AddressInfo) = join([quil(content(blk), info) > loc/info for loc in blk.locs], "\n")

for G in BASIC_GATES
    GT = Symbol(G, :Gate)
    g = G |> String
    @eval quil(blk::$GT, info::AddressInfo) = "$($g)"
end
quil(blk::I2Gate, info::AddressInfo) = "I"

quil(blk::RotationGate{N,T}, info::AddressInfo) where {N,T} = "R$(quil(content(blk), info))($(blk.theta))"
quil(blk::RotationGate{N,T,G}, info::AddressInfo) where {N,T,G<:SWAPGate} = "P$(quil(content(blk), info))($(blk.theta))"  # @
quil(blk::ShiftGate, info::AddressInfo) = "PHASE($(blk.theta))"
_cstring(blk::ControlBlock) = prod(v==1 ? "C" : "¬C" for v in blk.ctrl_config)
function quil(blk::ControlBlock, info::AddressInfo)
    _cstring(blk) * quil(content(blk), info) > (blk.ctrl_locs..., blk.locs...)/info
end
quil(blk::ControlBlock{<:Any, <:XGate}, info::AddressInfo) = _cstring(blk) * "NOT" > (blk.ctrl_locs..., blk.locs...)/info  # @
function quil(blk::Concentrator, info::AddressInfo)
    info = copy(info)
    info.address_map = info.address_map[[blk.locs...]]
    quil(content(blk), info)
end

function quil(blk::Union{ChainBlock, Sequential}, info::AddressInfo)
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
