# Finding data

Frequently, we need to find data (i.e. rows of the table) that matches certain criteria, and there are multiple mechanisms for achieving this in Julia. Here we will briefly review `map`, `findall` and `filter` as options.

## `map(predicate, table)`

Following the previous section, we can identify row satisfying an arbitrary predicate using the `map` function. Note that "predicate" is just a name for function that takes an input and returns either `true` or `false`.

```julia
julia> t = Table(name = ["Alice", "Bob", "Charlie"], age = [25, 42, 37])
Table with 2 columns and 3 rows:
     name     age
   ┌─────────────
 1 │ Alice    25
 2 │ Bob      42
 3 │ Charlie  37

julia> is_old = map(row -> row.age > 40, t)
3-element Array{Bool,1}:
 false
  true
 false
```

Finally, we can use "logical" (i.e. Boolean) indexing to extract the rows where the predicate is `true`.

```julia
julia> t[is_old]
Table with 2 columns and 1 row:
     name  age
   ┌──────────
 1 │ Bob   42
```

The `map(predicate, table)` approach will allocate one `Bool` for each row in the input table - for a total of `length(table)` bytes.
*SplitApplyCombine* defines a `mapview` function to do this lazily.

## `findall(predicate, table)`

If we wish to locate the indices of the rows where the predicate returns `true`, we can use Julia's `findall` function.

```julia
julia> inds = findall(row -> row.age > 40, t)
1-element Array{Int64,1}:
 2

julia> t[inds]
Table with 2 columns and 1 row:
     name  age
   ┌──────────
 1 │ Bob   42
```

This method may be less resource intensive (result in less memory allocated) if you are expecting a small number of matching rows, returing one `Int` per result.

## `filter(predicate, table)`

Finally, if we wish to directly `filter` the table and obtain the rows of interest, we can do that as well.

```julia
julia> filter(row -> row.age > 40, t)
Table with 2 columns and 1 row:
     name  age
   ┌──────────
 1 │ Bob   42
```

Internally, the `filter` method may rely on one of the implementations above.

## Generators

Julia's "generator" syntax also allows for filtering operations using `if`.

```
julia> Table(row for row in t if row.age > 40)
Table with 2 columns and 1 row:
     name  age
   ┌──────────
 1 │ Bob   42

```

This can be combined with mapping at the same time, as in `Table(f(row) for row in table if predicate(row))`. In *Joining Data* we discuss how to use generator syntax to combine multiple datasets.

## Preselection

As mentioned in other sections, it is frequently worthwhile to preselect the columns relating to your search predicate, to avoid any wastage in fetching from memory values in columns that you don't care about.

One simple example of such a transformation is to first project to the column(s) of interest, followed by using `map` or `findall` to identify the indices of the rows where `predicate` is `true`, and finally to use `getindex` or `view` to obtain the result of the full table.

```julia
julia> inds = findall(age -> age > 40, t.age)
1-element Array{Int64,1}:
 2

julia> t[inds]
Table with 2 columns and 1 row:
     name  age
   ┌──────────
 1 │ Bob   42
```

Easy, peasy!