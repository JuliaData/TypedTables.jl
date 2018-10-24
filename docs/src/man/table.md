# Table

It's simple to get started and create a table!

```julia
julia> using TypedTables

julia> t = Table(a = [1, 2, 3], b = [2.0, 4.0, 6.0])
Table with 2 columns and 3 rows:
     a  b
   ┌───────
 1 │ 1  2.0
 2 │ 2  4.0
 3 │ 3  6.0

julia> t[1]  # Get first row
(a = 1, b = 2.0)

julia> t.a  # Get column `a`
3-element Array{Int64,1}:
 1
 2
 3
```

## What is a `Table`?

Table is actually a Julia array type, where each element (row) is a `NamedTuple`. In particular:

 * Externally. a `Table` presents itself as an array of named tuples. That is, each row of the table is represented as one of Julia's new `NamedTuple`s, which are easy to use and highly efficient. In subtype notation, `Table <: AbstractArray{<:NamedTuple}`.

 * Internally, a `Table` stores a (named) tuple of arrays, and is a convenient structure for column-based storage of tabular data.

Thus, manipulating data as a `Table` is as easy as manipulating arrays and named tuples - which is something Julia was specifically designed to make simple, efficient and *fun*. 

`Table`s (and their columns) may be an `AbstractArray` of any dimensionality. This lets you take advantage of Julia's powerful array functionality, such as multidimensional broadcasting. Each column must be an array of the same dimensionality and size of the other columns.

## Why use a `Table`?

Two words: productivity and speed.

*TypedTables.jl* aims to introduce very few concepts, with minimal learning curve to let you manipulate tabular data. The `Table` type is a simple wrapper over columns and presents the well-known and extremely productive `AbstractArray` interface. If you are familiar with arrays and named tuples, you should be able to write your data analytics with a `Table`.

However, it would be of little use if the data container was inherently slow, or if using the container was subject to traps and pitfalls where performance falls of a cliff if the programmer uses an otherwise-idiomatic pattern. In this case, `for` loops over the rows of a `Table` are possible at the speed of hand-written code in a statically compiled language such as C, because the compiler is fully aware of the types of each column. Thus, users can write generic functions using a mixture of hand-written loops, calls to functions such as `map`, `filter`, `reduce`, `group` and `innerjoin`, as well as high-level interfaces provided by packages such as [*Query.jl*](https://github.com/queryverse/Query.jl) - and still obtain optimal performance.

Finally, since `Table` is unoppinionated about the underlying array storage (and acts more as a convenient metaprogramming layer), the arrays represent each column might have rather distinct properties - for example, supporting in-memory, out-of-core and distributed workloads (see the section on *Data Representation* for more details).

## Creating `Table`s

The easiest way to create a table from columns is with keyword arguments, such as

```julia
julia> t = Table(name = ["Alice", "Bob", "Charlie"], age = [25, 42, 37])
Table with 2 columns and 3 rows:
     name     age
   ┌─────────────
 1 │ Alice    25
 2 │ Bob      42
 3 │ Charlie  37
```
The constructor will equally accept a `NamedTuple` of columns, as `Table((name = ["Alice", "Bob", "Charlie"], age = [25, 42, 37]))` (note the extra brackets).

Also, one can easily convert the row-storage-based vector of named tuples into columnar storage using the `Table` constructor:

```julia
julia> Table([(name = "Alice", age = 25), (name = "Bob", age = 42), (name = "Charlie", age = 37)])
Table with 2 columns and 3 rows:
     name     age
   ┌─────────────
 1 │ Alice    25
 2 │ Bob      42
 3 │ Charlie  37
```

## Accessing data stored in `Table`s

### Row access

A single row of a `Table` is just a `NamedTuple`, which is easy to access.

```julia
julia> t[1]
(name = "Alice", age = 25)
```

Multiple rows can be indexed similarly to standard arrays in Julia:
```
julia> t[2:3]
Table with 2 columns and 2 rows:
     name     age
   ┌─────────────
 1 │ Bob      42
 2 │ Charlie  37
```

One can interrogate the `length`, `size` or `axes` of a `Table` just like any other `AbstractArray`:
```
julia> length(t)
3

julia> size(t)
(3,)
```

(Note: the number of columns does not participate in the `size`.)

Finally, if the backing arrays support mutation, rows can be mutated with `setindex!`

```
julia> t[3] = (name = Charlie, name = 38)  # Charlie had a birthday
Table with 2 columns and 3 rows:
     name     age
   ┌─────────────
 1 │ Alice    25
 2 │ Bob      42
 3 │ Charlie  38
```

Similarly, rows can be added or removed with `push!`, `pop!` and [so-on](https://docs.julialang.org/en/v1.0/base/collections/#Dequeues-1).

### Column access

A single column can be recovered using Julia's new `getproperty` syntax using the `.` operator.
```julia
julia> t.name
3-element Array{String,1}:
 "Alice"  
 "Bob"    
 "Charlie"
```

Currently, the simplest way to extract more than one column is to construct a brand new table out of the columns (as in `table2 = Table(column1 = table1.column1, column2 = table1.column2, ...)`).

The columns of a `Table` can be accessed directly as a `NamedTuple` of arrays using the `columns` function.
```julia
julia> columns(t)
(name = ["Alice", "Bob", "Charlie"], age = [25, 42, 37])
```

There is a `columnnames` function for getting the names of the columns:
```julia
julia> columnnames(t)
(:name, :age)
```

Note that the column names are Julia `Symbol`s, which are [interned strings](https://en.wikipedia.org/wiki/String_interning) tracked by the compiler.

Finally, the values contained in entire columns may be updated using `.=`, such as `t.age .= 0` or `t.age .= [26, 43, 38]`. Note that skipping the `.` in `.=`, such as `t.age = [26, 43, 38]`, will produce an error because the references to the column *containers* are immutable (if you wish to replace the entire *container* of a column, you may need to use a `FlexTable`).

### Cell access

From the above, we can see two identical ways to get a cell of data:

```julia
julia> t[1].name
"Alice"

julia> t.name[1]
"Alice"
```

While Julia's compiler will elide a lot of unnecessary code, you may find it faster to index individual cells of the table using the second option (to avoid fetching and constructing the *entire* named tuple of a row as an intermediate step).

Similarly, the value of a cell can be updated via `setindex!`, for example using the syntax `t.name[1] = "Alicia"`. Note that the syntax `t[1].name = "Alicia"` will error because you are trying to mutate `t[1]`, which is an immutable *copy* of the row (completely independent from `t`).

## Comparison with other packages 

### `DataFrame`

For those with experience using the [*DataFrames.jl*](https://github.com/JuliaData/DataFrames.jl) package, this comparison may be useful:

 * The columns stored in a `Table` are immutable - you cannot add, remove or rename a column. However, it is very cheap to create a new table with different columns, encouraging a functional programming style to deal with your outer data structure. (See also `FlexTable` for a more flexible alternative). For comparison, this is a similar approach to [*IndexedTables*](https://github.com/JuliaComputing/IndexedTables.jl) and [*JuliaDB*](https://github.com/JuliaComputing/JuliaDB.jl), while *DataFrames* uses an untyped vector of columns.

 * The columns themselves may be mutable. You may modify the data in one-or-more columns, and add or remove rows as necessary. Thus, operations on the *data* (not the data *structure*) can follow an imperative form, if desired.

 * The types of the columns are known to the compiler, making direct operations like iteration of the rows of a `Table` very fast. The programmer is free to write a combination of low-level `for` loops, use operations like `map`, `filter`, `reduce`, `group` or `innerjoin`, or to use a high-level query interface such as *Query.jl* - all with the high performance you would expect of a statically compiled language.

 * Conversely, the Julia compiler spends effort tracking the names and types of all the columns of the table. If you have a very large number of columns (many hundreds), `Table` may not be a suitable data structure (here, `DataFrame`s dynamically sized and typed vector of columns may be more appropriate).

 * `Table`s can be an array of any dimensionality.

 * Unlike a `DataFrame`, you cannot access a single cell in a single `getindex` call (you should first extract a column, and index a cell from that column). Similarly, the number of columns does not participate in the `size` or `length` of a `Table`.

A good litimus test of whether a statically-compiled `Table` or a dynamic approach like *DataFrames* is more appropriate, is to see whether the written **code** tends to refer to the columns by name, or whether the column names are more dynamic (and, for example, iteration over columns is required).
