using Documenter, PowerModelsDSSE

makedocs(;
    modules=[PowerModelsDSSE],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/timmyfaraday/PowerModelsDSSE.jl/blob/{commit}{path}#L{line}",
    sitename="PowerModelsDSSE.jl",
    authors="Tom Van Acker, Marta Vanin",
    assets=String[],
)

deploydocs(;
    repo="github.com/timmyfaraday/PowerModelsDSSE.jl",
)
