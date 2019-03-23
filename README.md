# YaoExperiment
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://GiggleLiu.github.io/YaoExperiment.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://GiggleLiu.github.io/YaoExperiment.jl/dev)
[![Build Status](https://travis-ci.com/GiggleLiu/YaoExperiment.jl.svg?branch=master)](https://travis-ci.com/GiggleLiu/YaoExperiment.jl)
[![Codecov](https://codecov.io/gh/GiggleLiu/YaoExperiment.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/GiggleLiu/YaoExperiment.jl)


![#f03c15](https://placehold.it/15/f03c15/000000?text=+)![#f03c15](https://placehold.it/15/f03c15/000000?text=+)![#f03c15](https://placehold.it/15/f03c15/000000?text=+) Work in progress ![#f03c15](https://placehold.it/15/f03c15/000000?text=+)![#f03c15](https://placehold.it/15/f03c15/000000?text=+)![#f03c15](https://placehold.it/15/f03c15/000000?text=+)

Experimental utilities
* Gate Count
* Time Estimation
* Compiling to QUIL
* Web Communication

Possiblly will support
* Wave Editing (for Quantum Control)

## Examples
#### 1. count gates and estimate experimental run time
For timing, gates in `KronBlock`s can be parallelized, while gates in `ChainBlock`s are sequentially excuted. `T1` and `T2` are symbolic time for 1-qubit gate and 2-qubit gate. Please use dispatch to time gates more accurately.

```julia console
julia> using QuAlgorithmZoo, YaoExperiment, Yao, Symbolics

julia> qc = QFTCircuit(3)
Total: 3, DataType: Complex{Float64}
chain
├─ chain
│  ├─ kron
│  │  └─ 1=>H gate
│  ├─ control(2)
│  │  └─ (1,)=>Phase Shift Gate:1.5707963267948966
│  └─ control(3)
│     └─ (1,)=>Phase Shift Gate:0.7853981633974483
├─ chain
│  ├─ kron
│  │  └─ 2=>H gate
│  └─ control(3)
│     └─ (2,)=>Phase Shift Gate:1.5707963267948966
└─ chain
   └─ kron
      └─ 3=>H gate


julia> qc |> gatecount
Dict{Type{#s12} where #s12<:Yao.Blocks.AbstractBlock,Int64} with 2 entries:
  ControlBlock{3,ShiftGate{Float64},1,1,Complex{Float64}} => 3
  HGate{Complex{Float64}}                                 => 3

julia> ex = chain(qc, Wait{3}(0.1)) |> gatetime
(T1 + T2) * 2 + T2 + T1 + 0.1

julia> @sym T1 T2
T2

julia> ex(T1=>1)(T2=>10) |> simplify
33.1

julia> qc |> quil |> print
H 0
CPHASE(1.5707963267948966) 1 0
CPHASE(0.7853981633974483) 2 0
H 1
CPHASE(1.5707963267948966) 2 1
H 2
```

For web communication part, see `web/`.

## TODO
* Decode QUIL for Porting Real Device.
* Optimize Appearence of Symbolic Calculation.
Symbolic calculations are based on [Symbolics](https://github.com/MasonProtter/Symbolics.jl), fixing this [issue](https://github.com/MasonProtter/Symbolics.jl/issues/17) may give better appearence of formulas

