# Reducing data

Here we demonstrate how to ask a few questions with "scalar" answers - like "Does the table contain *x*?", or "What is the average value of *y*?"

## Testing containment

One of the most basic questions to ask is: "Is this element in the table/column?". Julia's `in` operator is perfect for this.

```julia
julia> t = Table(name = ["Alice", "Bob", "Charlie"], age = [25, 42, 37])
Table with 2 columns and 3 rows:
     name     age
   ┌─────────────
 1 │ Alice    25
 2 │ Bob      42
 3 │ Charlie  37

julia> in("Alice", t.name)
true

julia> in("Debbie", t.name)
false
```

The `in` function can also be used as an infix operator, as in `"Alice" in t.name` or `"Alice" ∈ t.name`.

## "How many?"

The `count` method is useful for asking how many rows satisfy a certain criterion.

```julia
julia> count(row -> row.age > 40, t)
1
```

## Totals, averages, etc.

Individual columns can be reduced in the typical way for Julia arrays. Some examples.

```julia
julia> sum(t.age)
104

julia> using Statistics

julia> mean(t.age)
34.666666666666664

julia> median(t.age)
37.0

julia> join(t.name, ", ", " and ")
"Alice, Bob and Charlie"
```

Note that `join` is a string joining function; see `innerjoin` (from *SplitApplyCombine*) for the relational operation.


It's just as easy to calculate multi-column statistics by reducing over the entire table.

```julia
julia> mapreduce(row -> length(row.name) * row.age, +, t)
510
```