module TypedTables

using NullableArrays

export Field, DefaultKey, FieldIndex, Cell, Column, Row, Table, DenseTable, KeyTable, DenseKeyTable

export rename, name, eltypes, field, index, key, keyname, ncol, nrow, head, tail, samefield, samefields, storagetype, storagetypes

export join, unique!

export readtable, readtable!, writetable

export @field, @index, @cell, @row, @column, @table
export @select

import Base.(==)

# TODO union!, intersect! and setdiff!
# TODO dplyr funcitons (should we use same names or julia interfaces or both??)
#      - filter (slice is indexing)
#      - arrange (sorting)
#      - select/rename (combination of rename with indexing)
#      - district (currently unique and is already O(N log N))
#      - mutate (perhaps compute or computecol or something, given mutate has a meaning in julia)
#      - summarize
#      - sample_n and sample_frac (could use rand() interface I think)
#      - left_join, right_join, full_join (aka outer_join), semi_join, anti_join
# TODO Load from an object with a dataframe interface
# TODO Figure out namespace issues for head and tail (maybe both are in Base for Julia 0.5?)
# TODO sub/slice for generating a sub-table (i.e. simply a table with different StorageTypes)
# TODO possibly implement subtable type (with no ability to insert/delete rows, though can setindex!) - is this only necessary for Row?
# TODO fix TableKey so it always references the length of the current table, not its parent
# TODO Somehow make sense of the key mess for joins
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

include("datamacros.jl")
include("setalgorithms.jl")
include("join.jl")
include("IO.jl")


end # module
