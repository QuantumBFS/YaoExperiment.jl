using Documenter, YaoExperiment

makedocs(;
    modules=[YaoExperiment],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/GiggleLiu/YaoExperiment.jl/blob/{commit}{path}#L{line}",
    sitename="YaoExperiment.jl",
    authors="JinGuo Liu",
    assets=[],
)

deploydocs(;
    repo="github.com/GiggleLiu/YaoExperiment.jl",
)
