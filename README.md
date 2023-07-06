# TypedTables.jl

*Simple, fast, column-based storage for data analysis in Julia*

[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaData.github.io/TypedTables.jl/stable)
[![Documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://JuliaData.github.io/TypedTables.jl/dev)
[![CI](https://github.com/JuliaData/TypedTables.jl/workflows/CI/badge.svg)](https://github.com/JuliaData/TypedTables.jl/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/gh/JuliaData/TypedTables.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaData/TypedTables.jl)
[![deps](https://juliahub.com/docs/TypedTables/deps.svg)](https://juliahub.com/ui/Packages/TypedTables/NU69s?t=2)
[![version](https://juliahub.com/docs/TypedTables/version.svg)](https://juliahub.com/ui/Packages/TypedTables/NU69s)
[![pkgeval](https://juliahub.com/docs/TypedTables/pkgeval.svg)](https://juliahub.com/ui/Packages/TypedTables/NU69s)


*TypedTables.jl* provides two column-based storage containers: `Table` and `FlexTable`, both of which
represent an array of `NamedTuple`s. This package is designed to be lightweight,
easy-to-use and fast, and presents a very minimal new interface to learn.

Data manipulation is possible through the tools built into Julia (such as `map`, `filter`,
and `reduce`) and those provide by [SplitApplyCombine.jl](https://github.com/JuliaData/SplitApplyCombine.jl)
(like `group` and `innerjoin`). You can speed up data analysis tasks with acceleration indices, by using the [AcceleratedArrays.jl](https://github.com/andyferris/AcceleratedArrays.jl) package. This package is integrated the *Tables.jl* interface, and therefore the rest of
the data ecosystem such as *Query.jl*.

## Quick Start

It's simple to get started and create a table!

```julia
julia> using TypedTables

julia> t = Table(a = [1, 2, 3], b = [2.0, 4.0, 6.0])
Table with 2 columns and 3 rows:
     a  b
   ┌───────
 1 │ 1  2.0
 2 │ 2  4.0
 3 │ 3  6.0

julia> t[1]  # Get first row
(a = 1, b = 2.0)

julia> t.a  # Get column `a`
3-element Array{Int64,1}:
 1
 2
 3
```

The `Table` type is a simple `AbstractArray` where each element ("row") is a `NamedTuple`.
Upon construction, it retains references to it's columns rather than creating copies.
Strong typing means that you can iterate through the rows of the `Table` at blazing speed,
allowing you to write your own algorithms in native Julia. To achieve this, the outermost
`Table` structure is immutable and the names and types of the columns are fixed (while the
data itself can be mutated).

A more flexible table `FlexTable` is also provided. In a `FlexTable`, columns can be added, removed,
renamed or replaced. This comes at the cost of type-inferability - it will be slower to iterate the
rows of a `FlexTable` in a `for` loop. However, all the higher-level functions and queries will
still execute at full speed!

## Notes

This rewrite of *TypedTables.jl* is still young, and more functionality will be added
over time. Be assured that the current provided interface is fully stabilized as it is
simply the interface provided by an `AbstractVector{<:NamedTuple}`.
