using Test
using YaoExperiment: yaorepl_parse, yaorepl_trans,  YaoREPLState

@testset "yaorepl_parse" begin
    @test yaorepl_parse("e op reg") == :(expect(op, reg))
    @test yaorepl_parse("e' op reg") == :(expect'(op, reg))
    @test yaorepl_parse("m! reg") == :(measure!(reg))
    @test yaorepl_parse("cr(x)") == :(cr(x))
    @test yaorepl_parse("3=>X") == :(3=>X)
    @test yaorepl_parse("reg |> X") == :(reg |>X)
end

@testset "yaorepl_trans" begin
    s = YaoREPLState()
    @test yaorepl_trans(:(expect(op, reg)), s) == :(expect(op, reg))
    @test yaorepl_trans(:(expect'(op, reg)), s) == :(expect'(op, reg))
    @test yaorepl_trans(:(measure!(reg)), s) == :(measure!(reg))
    @test yaorepl_trans(:(help()), s) == :(help())
    @test_throws ErrorException yaorepl_trans(:(code()), s) == :(code())
    @test_throws ErrorException yaorepl_trans(:(cr(x)), s)
    @test yaorepl_trans(:(reg = zero_state(5)), s) == :(reg = zero_state(5))
    @test yaorepl_trans(:(reg = zero_state(5, nbatch=10)), s) == :(reg = zero_state(5, nbatch=10))
    @test yaorepl_trans(:(reg |>X), s) == :(apply!(reg, X))
    @test yaorepl_trans(:(op = begin nqubits=3; 2=>X; end), s) == :(op = chain(3, [put(3,2=>X)]))
end
