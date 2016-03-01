# Tables

A generic yet type-safe system for implementing data tables (sometimes called data frames, from R) in Julia.

[![Build Status](https://travis-ci.org/andyferris/Tables.jl.svg?branch=master)](https://travis-ci.org/andyferris/Tables.jl)

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

    t = @table(A::Int64=[1,2,3], B::Float64=[2.0,4.0,6.0])

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
    t = @table(A=[1,2,3], B=[2.0,4.0,6.0]) # Note: use identifier here for the fields
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

    idx = @index(A::Int64,B::Float64)

An empty table could be created with just it's index, e.g. `t = Table(idx)`. By
default, this will use `Vector`s for most data types to store the columns,
except for `Nullable` data which will utilize `NullableVector`s for efficiency.
The user can build a table using any data storage container, so long as they
support the access methods they will use (e.g. indexing, iteration, etc. In the
case of iteration, the various containers must share the same iteration states).

## Details

Feel free to skip this section, since the details are not necessarily important
for usage.

TODO

## Relational algebra and `join`

The relational algebra consists of a closed set of operations on `Table`s that
return a `Table`.

TODO

## Functions

A range of functions to manipulate data in `Table`s, including those present
in DataFrames.jl.

## Roadmap

- [x] Unit tests
- [ ] `hcat` and `vcat` for `Table`
- [ ] `join` and the multiple types of joins
- [ ] Convenience functions for data manipulations, like `unique!`
- [ ] Condition searches
- [ ] More support for views
- [ ] (possibly) Some way of interacting with SQL-formatted queries and other JuliaStats formalisms.
- [ ] Remove dependence on generated functions via trait-based metaprogramming (possibly quite hard).
