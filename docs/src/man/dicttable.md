# DictTable

`DictTable` is similar to `Table` except that instead of being an `AbstractArray` it is
an `AbstractDictionary` (from [Dictionaries.jl](https://github.com/andyferris/Dictionaries.jl)).

The advantage of this is that rows can be indexed by a semantically-important key. A common
case is that the first column of a table is a unique, primary-key column. When you construct
a `DictTable` in with arrays it will assume the first column is the primary key.

```julia
julia> using TypedTables

julia> t = DictTable(name = ["Alice", "Bob", "Charlie"], age = [25, 42, 37])
DictTable with 1 column and 3 rows:
 name      age
 ────────┬────
 Alice   │ 25
 Bob     │ 42
 Charlie │ 37
```

As mentioned, rows can be indexed by the value of the primary key.

```julia
julia> t["Alice"]
(name = "Alice", age = 25)
```

The columns themselves are dictionaries that can be also be indexed by primary key.

```julia
julia> t.age
3-element Dictionaries.Dictionary{String, Int64}
   "Alice" │ 25
     "Bob" │ 42
 "Charlie" │ 37

julia> t.age["Alice"]
25
```

With the design of *Dictionaries.jl*, these dictionaries are able to share `Indices` so that
this has very little overhead (even with many columns).

```julia
julia> keys(t.age) === t.name
true
```

Note that it is not *required* that the first column is the primary key. The `DictTable`
constructor can accept arbitrary dictionaries as columns (so long as the keys agree).