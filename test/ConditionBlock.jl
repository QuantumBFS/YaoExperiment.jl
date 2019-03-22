using YaoExperiment
using Yao
using Test

@testset "condition, t1, t2" begin
    m = Measure()
    reg = register(ComplexF64[0,1])
    c = condition(m, X, nothing)
    @test_throws UndefRefError reg |> c
    reg |> m
    @test (measure(reg |> c; nshot=10) .== 0) |> all
end
