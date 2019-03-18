using Documenter, YaoWave

makedocs(;
    modules=[YaoWave],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/GiggleLiu/YaoWave.jl/blob/{commit}{path}#L{line}",
    sitename="YaoWave.jl",
    authors="JinGuo Liu",
    assets=[],
)

deploydocs(;
    repo="github.com/GiggleLiu/YaoWave.jl",
)
