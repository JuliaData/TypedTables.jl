module TypedTables

using NullableArrays

export Field, DefaultKey, FieldIndex, Cell, Column, Row, Table, DenseTable, KeyTable, DenseKeyTable

export rename, name, eltypes, field, index, key, keyname, ncol, nrow, join, head, tail, samefield, samefields

export  @field, @index, @cell, @row, @column, @table

import Base.(==)

# TODO overload == for rows, tables and indices where they are simply reordered
# TODO similarly to ==, need to push! a reorederd row onto a table. Currently seems to cause an infinite loop. (Think about vcat, too? Or a nice way of matching orderings?)
# TODO Figure out namespace issues for head and tail
# TODO Missing methods: vcat and hcat for tables, unshift!,
# TODO Indexing by number of a Table/Row could give a Column/Cell (a bit confusing for table... maybe like table[:,1] vs table[1,:])
# TODO fix TableKey so it always references the length of the current table, not its parent
# TODO possibly implement subtable (with no ability to push! or change rows, though can setindex!)
# TODO join for row, join for table, somehow make sense of the key mess
# TODO sub for generating a sub-table (i.e. simply a table with different StorageTypes)
# TODO other DataFrames things like unique!
# TODO finish DenseTable
# TODO implement KeyTable ?
# TODO implement DenseKeyTable ?
# TODO other types of computed joins, map, do, etc


include("Field.jl")
include("Cell.jl")
include("Column.jl")
include("FieldIndex.jl")
include("Row.jl")
include("Table.jl")

include("join.jl")


end # module
