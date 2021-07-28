using Dictionaries
using Tables
using Test
using TypedTables
using SplitApplyCombine
using Adapt
using Tables

# Here because Julia v1.0 doesn't allow type definitions inside of testsets:
struct TestArrayConverter end
Adapt.adapt_storage(::TestArrayConverter, xs::AbstractArray) = convert(Array, xs)

include("properties.jl")
include("Table.jl")
include("FlexTable.jl")
include("DictTable.jl")
