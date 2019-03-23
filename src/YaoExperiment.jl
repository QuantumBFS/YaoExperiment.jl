module YaoExperiment
using Yao
using Yao.Blocks
import Yao.Blocks: subblocks, chsubblocks, apply!, mat, print_block, print_subblocks, usedbits, print_prefix, print_tree
using LuxurySparse

using Symbolics

export gatecount, gatetime, ConditionBlock, TrivilGate, Wait, condition
export quil, QuilInfo

include("YaoPatch.jl")
include("TrivilGate.jl")
include("timer.jl")
include("ConditionBlock.jl")
include("quil.jl")

end # module
