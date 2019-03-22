using QuAlgorithmZoo
using YaoExperiment
using Yao, Symbolics
using Test

@testset "gate count, time" begin
    qc = QFTCircuit(3)
    @test qc |> gatecount |> length == 2
    @test qc |> gatecount |> values |> sum == 6
    @sym T1 T2
    ex = chain(qc, Delay{3}(0.1)) |> gatetime
    @test ex(T1=>1)(T2=>10) |> simplify == 33.1
end
