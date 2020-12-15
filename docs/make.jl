using Documenter, TypedTables

makedocs(;
    modules=[TypedTables],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/JuliaData/TypedTables.jl/blob/{commit}{path}#L{line}",
    sitename="TypedTables.jl",
    assets=String[],
)

deploydocs(;
    repo="github.com/JuliaData/TypedTables.jl",
)
