using Yao
using Yao.Blocks

# NOTE: give up support to roller

mutable struct QASMInfo{VT<:Vector}
    address_map::VT
end

Base.copy(info::QASMInfo) = QASMInfo(info.address_map)

function Base.show(io::IO, ::MIME"qasm/quil", blk::AbstractBlock)
    qcode = qasm(blk)
    println(io, qcode)
end
qasm(blk::MatrixBlock{N}) where N = qasm(blk, QASMInfo(collect(1:N)))

######################## Basic Buiding Blocks ########################
const BASIC_1GATES = [:X, :Y, :Z, :H, :S, :Sdag, :T, :Tdag]

locs2str(locs) = join(["$i" for i in locs], " ")
floats2str(params) = join(["$p" for p in params], ", ")
args2str(pcounts) = join(["p$i" for i=pcounts], ", ")
# place an operator on some location
>>(gate::String, locs) = gate * " " * locs2str(locs)

qasm(blk::Measure, info) = "MEASURE" >> info.address_map
qasm(blk::MeasureAndRemove, info) = "MEASURE" >> info.address_map
qasm(blk::MeasureAndReset, info) = "MEASURE_AND_RESET($(blk.val))" >> info.address_map
qasm(blk::PutBlock, info) = qasm(blk.block, info) >> info.address_map[blk.addrs]
qasm(blk::KronBlock, info) = join([qasm(g, info) >> loc for (g, loc) in zip(blk.blocks, blk.addrs)], "\n")
qasm(blk::RepeatedBlock, info) = join([qasm(blk.block, info) >> info.address_map[loc] for loc in blk.addrs], "\n")

for G in BASIC_1GATES
    GT = Symbol(G, :Gate)
    g = G |> String
    @eval qasm(blk::$GT, info) = "$($g)"
    @eval qasm(blk::PutBlock{<:Any, <:Any, <:$GT}, info) where N = "$($g) " * locs2str(blk.addrs)
end
qasm(blk::I2Gate, info) = ""
qasm(blk::PutBlock{<:Any, <:Any, <:I2Gate}, info) = ""

qasm(blk::RotationGate, info) = "R$(qasm(blk.block, info))($(blk.theta))"
qasm(blk::ControlBlock, info) = "C"^length(blk.ctrl_qubits) * qasm(blk.block, info) >> (blk.ctrl_qubits..., blk.addrs...)
function qasm(blk::Concentrator, info)
    info = copy(info)
    info.address_map = info.address_map[blk.usedbits]
    qasm(blk.block, info)
end

function qasm(blk::ChainBlock, info)
    join([qasm(b, info) for b in subblocks(blk)], "\n")
end

using Test
# x, y, z, h, s, sdag, t, tdag
@testset "basic single gates" begin
    for G in [:X, :Y, :Z, :H, :S, :Sdag, :T, :Tdag]
        g = string(G)
        @eval @test qasm($G) == "$($(g))"
        @eval @test qasm(put(3,1=>$G)) == "$($g) 1"
    end
end
# id
@test qasm(I2) == qasm(put(4, 2=>I2)) == ""

# cx, cy, cz, ch, ct
# ccx, ccy, ccz, cch, cct
@testset "basic controled gates" begin
    for G in [:X, :Y, :Z, :H, :T]
        g = string(G)
        @eval @test qasm(control(3, 1, 2=>$G)) == "C$($g) 1 2"
        @eval @test qasm(control(7, (1,3), 2=>$G)) == "CC$($g) 1 3 2"
    end
end

# rx, ry, rz
# crz, crx, cry
@testset "(controled) rotation gates" begin
    for G in [:X, :Y, :Z]
        g = string(G)
        @eval @test qasm(control(3, 1, 2=>rot($G, 0.3))) == "CR$($g)(0.3) 1 2"
        @eval @test qasm(rot($G, 0.3)) == "R$($g)(0.3)"
        @eval @test qasm(put(3, 2=>rot($G, 0.3))) == "R$($g)(0.3) 2"
    end
end

# measure
@eval @test qasm(MEASURE, QASMInfo([1,4,3])) == "MEASURE 1 4 3"
@eval @test qasm(MEASURE_REMOVE, QASMInfo([1,4,3])) == "MEASURE 1 4 3"
@eval @test qasm(MEASURE_RESET, QASMInfo([1,4,3])) == "MEASURE_AND_RESET(0) 1 4 3"

# kron
@test qasm(kron(5, 2=>X, 4=>T)) == "X 2\nT 4"
# chain
@test qasm(chain(put(3,1=>Z), put(3, 2=>X))) == "Z 1\nX 2"
# Concentrator
@test qasm(concentrate(5, put(3,1=>Z), [3,4,1])) == "Z 3"

# show
@test repr(MIME("qasm/quil"), control(3, 2, 1=>X)) |> String == "CX 2 1\n"

# TODO:
# Basic Elemental Gates
# u1 == z
# u3, u2,
# cu1, cu3
# if statement
