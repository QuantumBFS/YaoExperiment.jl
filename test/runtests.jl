using YaoExperiment
using Test

@testset "repl" begin
    include("repl.jl")
end

@testset "quil" begin
    include("quil.jl")
end
