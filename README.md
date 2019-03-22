# YaoExperiment

Experimental utilities
* Gate Count
* Time Estimation
* QASM Compiling

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://GiggleLiu.github.io/YaoExperiment.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://GiggleLiu.github.io/YaoExperiment.jl/dev)
[![Build Status](https://travis-ci.com/GiggleLiu/YaoExperiment.jl.svg?branch=master)](https://travis-ci.com/GiggleLiu/YaoExperiment.jl)
[![Codecov](https://codecov.io/gh/GiggleLiu/YaoExperiment.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/GiggleLiu/YaoExperiment.jl)

## Examples
#### 1. count gates and estimate experimental run time
For timing, gates in `KronBlock`s can be parallelized, while gates in `ChainBlock`s are sequentially excuted. `T1` and `T2` are symbolic time for 1-qubit gate and 2-qubit gate. Please use dispatch to time gates more accurately.

```julia
using QuAlgorithmZoo
using YaoExperiment
using Yao, Symbolics

qc = QFTCircuit(3)
qc |> gatecount
ex = chain(qc, Delay{3}(0.1)) |> gatetime
@sym T1 T2
ex(T1=>1)(T2=>10) |> simplify
```

## TODO
#### Optimize Appearence of Symbolic Calculation
Symbolic calculations are based on the following package
https://github.com/MasonProtter/Symbolics.jl

Fixing the following issue may give better appearence of formulas
https://github.com/MasonProtter/Symbolics.jl/issues/17
