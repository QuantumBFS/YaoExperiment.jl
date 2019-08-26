using YaoExperiment
using Test

@testset "YaoExperiment.jl" begin
    include("timer.jl")
    include("ConditionBlock.jl")
    include("quil.jl")
end
