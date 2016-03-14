# Tables

A generic yet type-safe system for implementing data tables (sometimes called data frames, from R) in Julia.

[![Build Status](https://travis-ci.org/FugroRoames/Tables.jl.svg?branch=master)](https://travis-ci.org/FugroRoames/Tables.jl)

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
complication for the package maintainers and compiler. While convenience of the end-user
has been taken into consideration, there is no getting around that the approach
relies heavily on generated functions and does involve additional compile-time
overhead.

## Quick usage

Convenience macros are defined to for constructing different table objects,
since their type-parameter list can become cumbersome. For example, we can
define a table as:

    julia> Tables.@table(A::Int64=[1,2,3], B::Float64=[2.0,4.0,6.0])
    ┌───┬─────┐
    │ A │ B   │
    ├───┼─────┤
    │ 1 │ 2.0 │
    │ 2 │ 4.0 │
    │ 3 │ 6.0 │
    └───┴─────┘

This object stores a tuple of the two vectors as the `data` field, so that
`t.data == ([1,2,3],[2.0,4.0,6.0])`. One could access the data directly, or
one can get each row, column, or cell via indexing.

## Structure

A `Table` is a two-dimensional array of data with a header, or "index", defining
the names and types of the columns. Each column is constrained to contain only
one (possibly abstract) data-type and is stored in its own (user-definable) data
structure, like a `Vector` or `NullableVector`, and the columns making up a
table must have identical lengths.

The name and type of each column is called a `Field`, and in analogy to Julia
syntax for type fields, we can define them by `@field(Name::Type)`. The macro
produces an instance of a singleton type, like `@field(A::Int64) == Field{:A,Int64}()`.
These fields are used for multiple tasks, such as indexing or adding a new
column to a table. Returning to our earlier example, we can extract the `A`
column from `t` via `a[@field(A::Int64)] == [1,2,3]`. Of course, we could also
keep our fields in scope as objects, for convenience:

    A = @field(A::Int64)
    B = @field(B::Float64)
    t = @table(A=[1,2,3], B=[2.0,4.0,6.0]) # Note: uses identifier here for the fields - will error without the above 2 lines
    ...
    t[A]

By default, indexing a table this way will return a view, not a copy, of the
data. If you don't want to modify your original table when you mutate your
extracted column, it is better to call `copy(t[A])`

Indexing a table by an integer (or range, etc) will return a single `Row` of the
table (or a `Table` containing the indicated rows). The `Row` type retains the
information of the names and types of the fields, so that it too can be indexed.
You can access the row's data via the `row.data` field or via indexing with the
corresponding `Field`.

A single element of a table is called a `Cell`, and contains the `Field` of the
corresponding `Column` as well as a single piece of data, and can be constructed
by the macro `@cell`:

    @cell(A::Int64=1)

`Cell`s can be concatenated into `Column`s via `vcat` and `Row`s via `hcat`, and
similarly for building `Table`s out of `Column`s and/or `Row`s.

Both `Table`s and `Row`s have multiple `Field`s, which
are stored in another singleton container called a `FieldIndex`, which can be
constructed by the `@index` macro:

    idx = @index(A::Int64, B::Float64)

An empty table could be created with just it's index, e.g. `t = Table(idx)`. By
default, this will use `Vector`s for most data types to store the columns,
except for `Nullable` data which will utilize `NullableVector`s for efficiency.
The user can build a table using any data storage container, so long as they
support the access methods they will use (e.g. indexing, iteration, etc. In the
case of iteration, the various containers must share the same iteration states).

## Details

Feel free to skip this section, since the details are not necessarily important
for usage.

This package makes extensive use of Julia's type system to annotate a collection
with field names and types. Currently, the most basic unit is the `Field`, which
is an *instance* of the singleton type `Field{:name, Type}()`, and will appear
to the user at the REPL in a Julia-like form `name::Type`.

Collections of `Field`s are also a unique type, stored as another singleton type
`FieldIndex{(Field1,...)}()`. They appear on the REPL like a tuple a fields.

`Column`s and `Cell`s are themselves annotated by a `Field`, for instance
`@cell(A::Int=1)` generates `Cell{Field{:A,Int},Int}(1)`. Note the additional
element type given in the type parameters (this may change in the future).
Similarly, `@column(A::Int=[1,2,3])` will generate `Column{Field{:A,Int},Int,Vector{Int}}(1)`.
This has a third parameter defining the storage type - `Column`s can also accept
any storage container other than `Vector`, and will intelligently default to
`NullableVector` when it is constructed from a field with `Nullable` elements.

On the other hand, `Row`s and `Table`s are annotated by a `FieldIndex`. The element
type of a `Row` is a `Tuple{}` of the elements of the individual fields. For `Table`,
different storage containers can be used for different fields. Care must be taken
that each storage container supports the methods of access (e.g. iteration via
`start`/`next`/`done`, or direct access via `getindex`) that you will use to
access the `Table`, since they will be broadcast across the columns.

## Relational algebra

The relational algebra consists of a closed set of operations on `Table`s that
return a `Table`.

### Selecting columns (*projection*)

Indexing a table with a `FieldIndex` will result in a smaller table. This is
implemented by copying the *reference* to the associated storage containers, so it
constitutes a lightweight view. Care must be taken not to e.g. not change the
number of rows in a subtable, if you want to continue to use the parent table
(of course, `copy` and `deepcopy` are defined to help with this situation).

One can also index with a `Field` or just a column name with `Val{:name}` to obtain
the *raw data* from a single column. Indexing with `Val{1}`, etc will result in a
type-annotated `Column` containing the data, rather than the raw storage array.

The `Val`-based indexing can be extended by indexing with a tuple of values
(either all `Int`, like `Val{(1,2,3)}`, or `Symbol`, like `Val{(:A,:B,:C)}`) to return a `Table`, similar to the `FieldIndex`
method.

There is also one special column of every `Table`, referenced with the Field
`DefaultKey()`, and having field name `:Row`. Indexing with this will also
return the row-number of the record.

### Selecting rows (*selection*)

Basic iteration over and indexing of rows is implemented by default, similar to
Julia `Array`s. Currently, one should create their own function to select the
rows you wish to keep according to some criteria or tests.

Convenience functions may be considered in the future. Depending on the
situation, users may want to create an entirely new table, or simply a
`Vector{Bool}` index of the relevant rows as a "view" of the subset.

### Concatenation

`Cell`s, `Row`s, `Column`s and `Table`s can all be concatenated with the
appropriate `hcat` or `vcat` command.

### Renaming

Field names may be modified with the `rename` function:

    rename(table, old_field, new_field) # rename a single field
    rename(table, old_index, new_index) # rename one or more fields
    rename(table, new_index)            # rename all fields (in order)

However, the new field(s) must have the same type as the previous.

### Joins

Two tables can be joined with the syntax

    join(table, table2, [jointype])

The default (and currently only) type of join supported is the natural inner
join, parameterized by the singleton `InnerJoin()`. In the future, more types
of joins will be implemented and a convenient framework for users to implement
their own join tests, etc will be included.

## Output

Some effort has been put into making the output pretty and easy to use.
Currently, it will intelligently truncate the output vertically (printing only
the head and tail of the table) and minimize space horizontally when possible
(compare row "C" to "C_long" below).

    julia> Tables.@table(A::Int64=[1,2,3], B::Float64=[2.0,4.0,6.0], C::Nullable{Bool}=Nullable{Bool}[true,false,Nullable{Bool}()], C_long::Nullable{Bool}=Nullable{Bool}[true,false,Nullable{Bool}()], D::ASCIIString = ["A","ABCD","ABCDEFGHIJKLM"])
    ┌───┬─────┬───┬────────┬────────────┐
    │ A │ B   │ C │ C_long │ D          │
    ├───┼─────┼───┼────────┼────────────┤
    │ 1 │ 2.0 │ T │ true   │ "A"        │
    │ 2 │ 4.0 │ F │ false  │ "ABCD"     │
    │ 3 │ 6.0 │ - │ NULL   │ "ABCDEFG…" │
    └───┴─────┴───┴────────┴────────────┘

## Roadmap

- [x] Unit tests
- [x] `join` for natural, inner joins
- [x] Pretty output (work remains on horizontal fill and aligning numbers)
- [ ] other types of joins
- [ ] Convenience functions for data manipulations, like `unique!`
- [ ] Conditional searches (selection)
- [ ] More support for views and `sub`
- [ ] Some way of interacting with SQL-formatted queries and other JuliaStats formalisms (maybe?)
- [ ] Remove dependence on generated functions via trait-based metaprogramming (probably requires Julia 0.5 `@pure` functions)
