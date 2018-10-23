# Input and output

Input and output of `Table` and `FlexTable` are mostly handled through externally-defined interfaces.

## AbstractArray interface

One can convert an `AbstractArray` of `NamedTuple`s to a `Table` using a simple constructor.

```
julia> v = [(name="Alice", age=25), (name="Bob", age=42), (name= "Charlie", age=37)]
3-element Array{NamedTuple{(:name, :age),Tuple{String,Int64}},1}:
 (name = "Alice", age = 25)  
 (name = "Bob", age = 42)    
 (name = "Charlie", age = 37)

julia> t = Table(v)
Table with 2 columns and 3 rows:
     name     age
   ┌─────────────
 1 │ Alice    25
 2 │ Bob      42
 3 │ Charlie  37
```
In this way, we have converted a row-based storage container to a column-based storage container.

One can convert back to row-based storage by `collect`ing the results in an `Array`. 
```julia
julia> collect(t)
3-element Array{NamedTuple{(:name, :age),Tuple{String,Int64}},1}:
 (name = "Alice", age = 25)  
 (name = "Bob", age = 42)    
 (name = "Charlie", age = 37)
```

Note that `collect` is the generic construtor for an `Array` which accepts any kind of iterable - an "iterable" being any type that supports the `iterate` function.

## *Tables.jl*

NOTE: The information in this section represents the development versions of *Tables*, *CSV* and related packages.

The *Tables.jl* package provides a flexible interface for dealing with tabular data of all forms: from in-memory `Table`s to `CSV` files on a disk.

At it's core, it provides a way of:

 * Introspecting data via `Tables.istable`, `Tables.schema`, and so-on.
 * Provide a row iterator via `rows(data)`, where each row has fields/cells accessed by `getproperty`.
 * Provide a collection of columns via `columns(data)` that can be accessed via `getpropery`, each of which iterates fields/cells.

It's simple design allows us to treat many forms of tabular data in the same way.

## *CSV.jl*

As an example of good use of the *Tables.jl*, take the package *CSV.jl*, which is designed to load and save CSV files.

Let's say we have a CSV file called `input.csv`, and the following data.

```
name,age
Alice,25
Bob,42
Charlie,37
```

We can load this file from disk using the `CSV.File` constructor.

```julia
julia> using TypedTables, CSV

julia> csvfile = CSV.File("input.csv")
CSV.File("/home/ferris/example.csv", rows=3):
Tables.Schema:
 :name  Union{Missing, String}
 :age   Union{Missing, Int64}
```
Note that *CSV* has inferred the column types from the data, but by default allows for `missing` data. This can be controlled via the `allowmissing` keyword argument (as either `:all`, `:none` or `:auto`).

```julia
julia> CSV.File("input.csv", allowmissing=:none)
CSV.File("/home/ferris/example.csv", rows=3):
Tables.Schema:
 :name  String
 :age   Int64 
```

Either of these can finally be converted to a `Table`.

```julia
julia> Table(csvfile)
Table with 2 columns and 3 rows:
     name     age
   ┌─────────────
 1 │ Alice    25
 2 │ Bob      42
 3 │ Charlie  37
```

Similarly, the *CSV.jl* package supports writing tables with  `CSV.write` function.

```julia
julia> CSV.write("output.csv", t)
"output.csv"
```