# TypedTables.jl

*Simple, column-based storage*

[![Build Status](https://travis-ci.org/JuliaData/SplitApplyCombine.jl.svg?branch=master)](https://travis-ci.org/JuliaData/SplitApplyCombine.jl)
[![Coverage Status](https://coveralls.io/repos/github/JuliaData/SplitApplyCombine.jl/badge.svg?branch=master)](https://coveralls.io/github/JuliaData/SplitApplyCombine.jl?branch=master)
[![codecov.io](http://codecov.io/github/JuliaData/SplitApplyCombine.jl/coverage.svg?branch=master)](http://codecov.io/github/JuliaData/SplitApplyCombine.jl?branch=master)

*TypedTables.jl* provides two column-based storage container `Table` and `FlexTable`, which
represent an array of `NamedTuple`s. This package is designed to be lightweight,
easy-to-use and fast, and presents a very minimal new interface to learn.

Data manipulation is possible throught the tools built into Julia (such as `map`, `filter`,
and `reduce`) and those provide by [SplitApplyCombine.jl](https://github.com/JuliaData/SplitApplyCombine.jl)
(like `group` and `innerjoin`). The package is integrated the *Tables.jl* interface and therefore the rest of
the data ecosystem such as *Query.jl*.

## Quick Start

It's simple to get started and create a table!

```julia
julia> using TypedTables

julia> t = Table(a=[1, 2, 3], b = [2.0, 4.0, 6.0])
3-element Table{NamedTuple{(:a, :b),Tuple{Int64,Float64}},1,NamedTuple{(:a, :b),Tuple{Array{Int64,1},Array{Float64,1}}}}:
 (a = 1, b = 2.0)
 (a = 2, b = 4.0)
 (a = 3, b = 6.0)

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

This rewrite of *TypedTables.jl* is still quite young, and more functionality will be added
over time. Be assured that the current provided interface is fully stabilized as it is
simply the interface provided by an `AbstractVector{<:NamedTuple}`.
