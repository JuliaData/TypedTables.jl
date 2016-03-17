module TypedTables

using NullableArrays

export Field, DefaultKey, FieldIndex, Cell, Column, Row, Table, DenseTable, KeyTable, DenseKeyTable

export rename, name, eltypes, field, index, key, keyname, ncol, nrow, join, head, tail, samefield, samefields

export  @field, @index, @cell, @row, @column, @table

import Base.(==)

# TODO similarly to ==, push!, etc think about vcat, too, for matching orderings? At the moment there is a difference between how vcat and a potential `append()` function would behave...
# TODO Figure out namespace issues for head and tail (maybe both are in Base for Julia 0.5?)
# TODO sub for generating a sub-table (i.e. simply a table with different StorageTypes)
# TODO possibly implement subtable type (with no ability to push! or change rows, though can setindex!) - is this only necessary for Row?
# TODO fix TableKey so it always references the length of the current table, not its parent
# TODO Somehow make sense of the key mess for joins
# TODO Set opertations like unique/unique! and union, intersect, setdiff
# TODO Unary relational operations like select, project, etc (see dplyr for inspiration)
# TODO Binary relational operations like left_join, etc.
# TODO other types of computed joins, map, do, etc
# TODO finish DenseTable
# TODO implement KeyTable ?
# TODO implement DenseKeyTable ?


include("Field.jl")
include("Cell.jl")
include("Column.jl")
include("FieldIndex.jl")
include("Row.jl")
include("Table.jl")

include("algorithms.jl")
include("join.jl")


end # module
