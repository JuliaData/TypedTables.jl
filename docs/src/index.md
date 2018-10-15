# TypedTables.jl

*Simple, column-based storage for data analysis in Julia.*

## Introduction

*TypedTables.jl* provides two column-based storage containers: `Table` and `FlexTable`, both of which
represent an array of `NamedTuple`s. This package is designed to be lightweight,
easy-to-use and fast, and presents a very minimal new interface to learn.

Data manipulation is possible throught the tools built into Julia (such as `map`, `filter`,
and `reduce`) and those provide by [SplitApplyCombine.jl](https://github.com/JuliaData/SplitApplyCombine.jl)
(like `group` and `innerjoin`). You can speed up data analysis tasks with acceleration indices, by using the [AcceleratedArrays.jl](https://github.com/andyferris/AcceleratedArrays.jl) package. This package is integrated the *Tables.jl* interface, and therefore the rest of the data ecosystem such as *Query.jl*. This documentation includes examples on how to integrate with these packages for a complete data analysis workflow.

## Installation

Start Julia 1.0, and press `]` to enter "package" mode. Then type:

```julia
pkg> add TypedTables
```

That's it!

## User guide

```@contents
Pages = [
    "man/table.md",
    "man/flextable.md",
]
Depth = 1
```
