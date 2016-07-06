# TypedTables

A generic yet type-safe system for implementing data tables (sometimes called
data frames, from R) in Julia.

[![Build Status](https://travis-ci.org/FugroRoames/TypedTables.jl.svg?branch=master)](https://travis-ci.org/FugroRoames/TypedTables.jl)
[![Coverage Status](https://coveralls.io/repos/github/FugroRoames/TypedTables.jl/badge.svg?branch=master)](https://coveralls.io/github/FugroRoames/TypedTables.jl?branch=master)

## Overview

Julia's dynamic-yet-statically-compilable type system is extremely powerful, but
presents some challenges to creating generic storage containers, like tables of
data where each column of the table might have different types. This package
attempts to present a fully-typed `Table` container, where elements (rows,
columns, cells, etc) can be extracted with their correct type annotation at zero
additional run-time overhead. The resulting data can then be manipulated without
any unboxing penalty, or the need to introduce unseemly function barriers,
unlike existing approaches like the popular DataFrames.jl package. Conformance
to the interface presented by DataFrames.jl as well as existing Julia standards,
like indexing and iteration has been maintained.

The main caveat of this approach is that it involves an extra layer of
complication for the package maintainers and compiler. While convenience of the
end-user has been taken into consideration, there is no getting around that the
approach relies heavily on generated functions and does involve additional
compile-time overhead.

## Quick usage

Convenience macros are defined to for constructing different table objects,
since their type-parameter list can become cumbersome. For example, we can
define a table as:

```
julia> t = @Table(A=[1,2,3], B=[2.0,4.0,6.0])
3-row × 2-column Table:
    ╔═══╤════════╗
Row ║ A │ B      ║
    ╟───┼────────╢
  1 ║ 1 │ 2.0000 ║
  2 ║ 2 │ 4.0000 ║
  3 ║ 3 │ 6.0000 ║
    ╚═══╧════════╝
```

This object stores a tuple of the two vectors as the `data` field, so that
`t.data == ([1,2,3], [2.0,4.0,6.0])`. One could access the data directly, or
one can get each row, column, or cell via indexing. One convenient way of
getting a column is with the `@col` macro, for example `@col(t, A)`

## Structure

A `Table` is a two-dimensional array of data with a header, or "index", defining
the names and types of the columns. Each column is constrained to contain only
one (possibly abstract) data-type and is stored in its own (user-definable) data
structure, like a `Vector` or `NullableVector`, and the columns making up a
table must have identical lengths.

The name of each column (sometimes called the field name) is a `Symbol`, stored
as a type parameter of the `Table` (as a tuple of `Symbol`s). The name `Symbol`s
are then used for things like indexing. However, so that Julia can determine the
type of the column(s) you wish yo extract, you need to index with a `Val` type.
Returning to our earlier example, we can extract the `:A`
column from `t` via `t[Val{:A}] == [1,2,3]`. For convenience, we recommend using
the `@col` macro, such as `@col(t, A)`, which is a nicer shortcut for the above.
Another possible workaround to avoid this notation is to define field name
objects as Julia variables for convenience (but of course this is not necessary):
```julia
A = Val{:A}
B = Val{:B}
t = @Table(A=[1,2,3], B=[2.0,4.0,6.0]) # "A" does not refer to the variable bound above - the macro converts it to a Symbol
...
t[A]
```

By default, indexing the columns of a table this way will return a view, not a
copy, of the data. If you don't want to modify your original table when you
mutate your extracted column, it is better to call `copy(t[Val{:A}])`

Indexing a table by an integer (or range, etc) will return a single `Row` of the
table (or a `Table` containing the indicated rows). The `Row` type retains the
information of the names and types of the fields.
You can access the row's data via the `row.data` field or via indexing with the
corresponding `Val{:name}`.

A single element of a table is called a `Cell`, and is essentially a decorated,
single piece of data, and can be constructed by the macro `@Cell`:
```julia
@Cell(A=1)
```

`Cell`s can be concatenated into `Column`s via `vcat` and `Row`s via `hcat`, and
similarly for building `Table`s out of `Column`s and/or `Row`s.

An empty table could be created with just it's names and types, e.g.
`t = Table{(:A,:B), Tuple{Vector{Int},Vector{Float64}}}()`. For example, you
might want to use `Vector`s for most data types to store the columns, or you
might choose to use `NullableVector`s for efficiency storage of columns which
may contain missing values. The user can build a table using any data storage
container, so long as they support the access methods used (more-or-less the
`AbstractVector` interface). For convenience, types can be annotated in the
macro invocation, e.g: `@Row(A::Int = 1, B::Float64 = 2)`, which will
automatically convert the second field to a `Float64` (similarly for `@Cell`,
`@Column` and `@Table`).

## Details

Feel free to skip this section, since the details are not necessarily important
for usage.

This package makes extensive use of Julia's type system to annotate a collection
with field names and types.
`Column`s and `Cell`s are annotated by a single `Symbol` and data type, so that
`@Cell(A::Int=1)` generates `Cell{:A,Int}(1)`.
Similarly, `@Column(A=[1,2,3])` will generate
`Column{:A, Vector{Int}}([1,2,3])`.

On the other hand, `Row`s and `Table`s are annotated by a tuple of `Symbol`s -
even in the case that there is a single column. The second type parameter of
`Row`s and `Table`s is a `Tuple{}` of the elements of the individual fields.
For `Table`, different storage containers can be used for different fields,
so long as they obey the same semantics with respect to iterating, indexing,
etc.

Finally, both `Column`s and `Table`s provide an extra field name called `:Row`
which corresponds to the row number of each field. We have that `table[Val{:Row}] = 1:nrow(table)`.

## Relational algebra

The relational algebra consists of a closed set of operations on `Table`s that
return a `Table`.

### Selecting columns (a.k.a. relational projection or dplyr's `select`)

### Indexing columns

Before, we saw that we can extract the data corresponding to a single column by
using the `@col` macro or indexing with a `Val{symbol}`. To extract multiple
columns and build a new `Table` with a subset of existing columns, we can call
`@col` with multiple columns (e.g. `subtable = @col(table, A, C)`) or otherwise
index with a (`Val` of a) tuple of `Symbol`s, such as
`subtable = table[Val{(:A, :C)}]`.

#### The `@select` macro

A powerful `@select` macro has been included that can project, rename and
compute new columns - incorporating the popular R-package `dplyr`s grammar for
`select` as well as `mutate`.

The macro is typified by the following example:
``` julia
@select(table, col1, newname = col2, newcol::neweltype = col1 -> f(col1))
```
Here, we take the column labelled `col1` from the table, unmodified, plus the
column `col2` taking the new name `newcol` and finally and new column called
`newcol` with elements of type `newtype` (optional) that is calculated from the
values of `col1` via the function `f(col1)`. This new column is calculated via
a comprehension (so generates an `Vector{newtype}`), and almost arbitrary code
can be included on the right-hand-side and evaluated quickly. On the
left-hand-side, more than one column name can be specified in a tuple format
similar to anonymous functions,  e.g. `newcol = (col1,col2) -> f(col1) + g(col2)`.

### Filtering rows (a.k.a. relational selection or dplyr's `filter`)

#### Indexing rows

Basic iteration over and indexing of rows is implemented by default, similar to
Julia `Array`s. One may create their own function to select the
rows you wish to keep according to some criteria or tests, for instance by passing
to Julia's inbuilt `filter()` a function that takes a `Row` and returns a `Bool`.

#### The `@filter` macro family

For convenience, a macro `@filter` is provided that can apply a series of
predicates to the data in the table to eliminate rows. Syntax follows the form:

```julia
@filter(table, col1 -> col1 == 1, (col1, col2) -> col1 < col2)
```

Similar to `@select`, the left of the `->` symbol defines the columns that are
used in the function to the right. All conditions must be met and are tested via
short-circuit evaluation (exactly equivalent to a single condition joined by `&&`).

Depending on the situation, users may want to create an entirely new table using
`@filter`, or maybe mutate the table with the version `@filter!`, or simply
generate a `Vector{Bool}` index of the relevant rows as a "view" of the subset
using `@filter_mask`.

### Concatenation

`Cell`s, `Row`s, `Column`s and `Table`s can all be concatenated with the
appropriate `hcat` or `vcat` command.

### Renaming

Field names may be modified with the `rename` function:

```julia
rename(table, old_name, new_name) # rename a single field
rename(table, new_names)          # rename all fields (in order)
```

### Joins

Two tables can be joined with the syntax

```julia
join(table1, table2)
```

The default (and currently only) type of join supported is the natural inner
join, and is performed by hashing the relevant sub-columns of `table1` and
then comparing them with `table2`.

### Set operations

Operations for dealing with tables as sets are defined, including `unique` (and
it's mutating version `unique!`), `union`, `intersect` and `setdiff`.

## Input/Output

### At the REPL

Some effort has been put into making the output appealing and easy to read.
Currently, it will intelligently truncate the output both vertically (printing
only the head and tail of the table) and horizontally (by truncating columns),
and also to minimize the horizontal size of a column when possible (compare row
"C" to "C_long" below).

```
julia> @Table(A = [1,2,3],
              B = [2.0,4.0,6.0],
              C = Nullable{Bool}[true,false,Nullable{Bool}()],
              C_long = Nullable{Bool}[true,false,Nullable{Bool}()],
              D = ["A","ABCD","ABCDEFGHIJKLMNOPQRSTUVWXYZ"])
3-row × 5-column Table:
    ╔═══╤════════╤═══╤════════╤══════════════════════╗
Row ║ A │ B      │ C │ C_long │ D                    ║
    ╟───┼────────┼───┼────────┼──────────────────────╢
  1 ║ 1 │ 2.0000 │ T │  true  │ "A"                  ║
  2 ║ 2 │ 4.0000 │ F │ false  │ "ABCD"               ║
  3 ║ 3 │ 6.0000 │ - │     -  │ "ABCDEFGHIJKLMNOPQ…" ║
    ╚═══╧════════╧═══╧════════╧══════════════════════╝
```

The edge of the table is indicated by the double border. Since rows, columns and
cells are only elements of a table, some of their borders are indicated by a
single line. For example, rows have a single-line top/bottom, columns have
single-line sides, and cells are entirely single-lined. Thus we can visualize
the difference in type between the following, while keeping a consistent
appearance:

```
julia> @cell(A::Int64=1)
Cell:
 ┌───┐
 │ A │
 ├───┤
 │ 1 │
 └───┘

 julia> @row(A::Int64=1)
 1-column Row:
  ╓───╖
  ║ A ║
  ╟───╢
  ║ 1 ║
  ╙───╜

 julia> @column(A::Int64=[1])
 1-row Column:
     ╒═══╕
 Row │ A │
     ├───┤
   1 │ 1 │
     ╘═══╛

 julia> @table(A::Int64=[1])
 1-row × 1-column Table:
     ╔═══╗
 Row ║ A ║
     ╟───╢
   1 ║ 1 ║
     ╚═══╝
```

### File I/O

The functions `readtable` and `writetable` are defined to read and write
delimited text files (such as CSV). Currently `readtable` relies on Julia's
inbuilt `readdlm` function, while `writetable` is a specialized version that
accepts a variety of keyword arguments for creating the desired output.

Furthermore, `readtable` is overloaded to accept column-dictionary-like objects,
including `DataFrame`s.

## Roadmap

- [x] Unit tests
- [x] `join` for natural, inner joins
- [x] Pretty output
- [x] Set operations on tables (`union`, `intersect`, `setdiff`, `unique`/`unique!`, etc)
- [x] I/O from files and `DataFrame`s (`readtable` and `writetable`)
- [x] `@select` for dplyr-like `select` and `mutate`
- [x] `@filter` for dplyr-like `filter`.
- [ ] inherit from `AbstractTable` in *AbstractTables.jl*
- [ ] support *DataStreams.jl*
- [ ] sort/arrange (probably also *a la* dplyr)
- [ ] Other types of joins
- [ ] More support for views, `slice` and `sub` (or `view`)
- [ ] Make `Table` and `Column` inherit from `AbstractVector{Row{...}}}` (maybe?)
- [ ] `DenseTable` for row-based storage (a vector of rows)
- [ ] `KeyTable` and `DenseKeyTable` for tables that are indexed by a key value
- [ ] Sorted tables and/or sorting information included with a table
- [ ] Some way of interacting with SQL-formatted queries and other JuliaStats formalisms (maybe?)
- [ ] Make life easier for users by removing `Val{}` (either advanced constant
      propagation using `@pure` functions or by generated types for easy field access).
