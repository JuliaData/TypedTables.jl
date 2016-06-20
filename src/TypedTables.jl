module TypedTables

using NullableArrays

export DefaultKey, Cell, Column, Row, Table, DenseTable, KeyTable, DenseKeyTable

export rename, name, eltypes, permutecols, ncol, nrow, head, tail, storagetype, storagetypes

export join, unique!

export readtable, readtable!, writetable

export @Cell, @Row, @Column, @Table
export @select, @filter, @filter!, @filter_mask

import Base.(==)

# TODO Do we need a unique table? It could keep a persistent hash. (Perhaps a multi-column key table with no value columns?)
# TODO union!, intersect! and setdiff!
# TODO dplyr funcitons (should we use same names or julia interfaces or both??)
#      - arrange (sorting)
#      - select/rename (combination of rename with indexing)
#      - distinct (currently unique and is already O(N log N))
#      - mutate (perhaps compute or computecol or something, given mutate has a meaning in julia)
#      - summarize
#      - sample_n and sample_frac (could use rand() interface I think)
#      - left_join, right_join, full_join (aka outer_join), semi_join, anti_join
#      - think about group_by (generates something similar to KeyTable of Tables?)
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

# Julia 0.5 agenda:
# TODO Use generalized comprehensions in @select (user specified data structure)
#      and @filter (BitArray)
# TODO Use @pure functions where beneficial


include("Cell.jl")
include("Column.jl")
include("Row.jl")
include("Table.jl")

include("show.jl")
include("datamacros.jl")
include("setalgorithms.jl")
#include("join.jl")
include("IO.jl")


end # module
