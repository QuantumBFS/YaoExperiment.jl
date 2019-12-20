using YaoExperiment
using Yao, Yao.ConstGate, YaoExtensions
using Test

# x, y, z, h, s, sdag, t, tdag
@testset "basic gates" begin
    for G in [:X, :Y, :Z, :H, :S, :Sdag, :T, :Tdag]
        g = string(G)
        @eval @test quil($G) == "$($(g))"
        @eval @test quil(put(3,1=>$G)) == "$($g) 0"
    end

    for G in [:SWAP, :CNOT]
        g = string(G)
        @eval @test quil($G) == "$($(g))"
        @eval @test quil(put(3,(2,1)=>$G)) == "$($g) 1 0"
    end
end
# id
@test quil(put(4, 2=>I2)) == "I 1"

# cx, cy, cz, ch, ct
# ccx, ccy, ccz, cch, cct
@testset "basic controled gates" begin
    for G in [:X, :Y, :Z, :H, :T]
        g = G == :X ? "NOT" : string(G)
        @eval @test quil(control(3, 1, 2=>$G)) == "C$($g) 0 1"
        @eval @test quil(control(3, -1, 2=>$G)) == "¬C$($g) 0 1"
        @eval @test quil(control(7, (1,3), 2=>$G)) == "CC$($g) 0 2 1"
    end
end

# rx, ry, rz
# crz, crx, cry
@testset "(controled) rotation gates" begin
    for G in [:X, :Y, :Z]
        g = string(G)
        @eval @test quil(control(3, 1, 2=>rot($G, 0.3))) == "CR$($g)(0.3) 0 1"
        @eval @test quil(rot($G, 0.3)) == "R$($g)(0.3)"
        @eval @test quil(put(3, 2=>rot($G, 0.3))) == "R$($g)(0.3) 1"
    end
    @test quil(rot(SWAP, 0.3)) == "PSWAP(0.3)"
    @test quil(put(3, (3,1)=>rot(SWAP, 0.3))) == "PSWAP(0.3) 2 0"
end

# measure
@testset "measure" begin
    @test quil(Measure(3), YaoExperiment.QuilAddress([1,4,3])) == "MEASURE 0 3 2"
end

@testset "composite" begin
    # kron
    @test quil(kron(5, 2=>X, 4=>T)) == "X 1\nT 3"
    @test quil(PauliString(I2, I2, X, X)) == "X 2\nX 3"
    # chain
    @test quil(chain(put(3,1=>Z), put(3, 2=>X))) == "Z 0\nX 1"
    # Concentrator
    @test quil(subroutine(5, put(3,1=>Z), [3,4,1])) == "Z 2"
    # cache and diff
    @test quil(kron(5, 2=>X, 4=>T) |> cache) == "X 1\nT 3"
    @test quil(rot(X, 0.3)) == "RX(0.3)"
end

@testset "show" begin
    # show
    @test repr(MIME("quil"), control(3, 2, 1=>X)) |> String == "CNOT 1 0\n"
end

@testset "system test" begin
    circuit = chain(qft_circuit(4), Measure())
    println(quil(circuit))
end
