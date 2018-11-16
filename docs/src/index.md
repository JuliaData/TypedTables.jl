# TypedTables.jl

*Simple, fast, column-based storage for data analysis in Julia.*

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

## Quick start

Here's a table:

```julia
julia> using TypedTables

julia> t = Table(a = [1, 2, 3], b = [2.0, 4.0, 6.0])
Table with 2 columns and 3 rows:
     a  b
   ┌───────
 1 │ 1  2.0
 2 │ 2  4.0
 3 │ 3  6.0
```

Now you can read [the **tutorial**](man/tutorial.md) to find out what to do with it.
