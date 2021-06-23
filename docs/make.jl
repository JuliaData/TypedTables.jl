using Documenter, TypedTables

makedocs(;
    modules=[TypedTables],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
        "Quick start tutorial" => "man/tutorial.md",
        "Table types" => [
            "Table" => "man/table.md",
            "FlexTable " => "man/flextable.md",
        ],
        "Data storage" => [
            "Data representation" => "man/data.md",
            "Input and output" => "man/io.md",
        ],
        "Basic data manipulation" => [
            "Mapping data" => "man/map.md",
            "Finding data" => "man/filter.md",
            "Reducing data" => "man/reduce.md",
        ],
        "Grouping and joining data" => [
            "Grouping data" => "man/group.md",
            "Joining data" => "man/join.md",
        ],
        "Accelerations" => [
            "Acceleration indices" => "man/acceleratedarrays.md",
        ],
        "API reference" => "man/reference.md"
    ],
    repo="https://github.com/JuliaData/TypedTables.jl/blob/{commit}{path}#L{line}",
    sitename="TypedTables.jl",
)

deploydocs(;
    repo="github.com/JuliaData/TypedTables.jl",
    devbranch = "main"
)
