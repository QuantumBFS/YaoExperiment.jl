module YaoExperiment
using Yao
using Yao.Blocks
import Yao.Blocks: subblocks, chsubblocks, apply!, mat, print_block, print_subblocks, usedbits, print_prefix, print_tree
using LuxurySparse

using Symbolics

export gatecount, gatetime, ConditionBlock, TrivilGate, Delay, condition
include("YaoPatch.jl")
include("TrivilGate.jl")
include("timer.jl")
include("ConditionBlock.jl")

end # module
