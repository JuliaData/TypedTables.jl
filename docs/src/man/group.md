```@meta
DocTestSetup = quote
    using TypedTables
end
```
# Grouping data

It is frequently useful to break data appart into different *groups* for processing - a paradigm frequently referred to a the split-apply-combine methodology.

In a powerful environment such as Julia, that fully supports nested containers, it makes sense to represent each group as distinct containers, with an outer container acting as a "dictionary" of the groups. This is in contrast to environments with a less rich system of containers, such as SQL, which has popularized a slightly different notion of grouping data into a single flat tabular structure, where one (or more) columns act as the grouping key. Here we focus on the former approach.

## Using the `group` function

*SplitApplyCombine* provides a `group` function, which can operate on arbitary Julia objects. The function has the signature `group(by, f, iter)` where `iter` is a container that can be iterated, `by` is a function from the elements of `iter` to the grouping *key*, and the optional argument `f` is a mapping applied to the grouped elements (by default, `f = identity`, the identity function).

To demonstrate the power of grouping, this time we'll add some more rows and columns to our example data.

```jldoctest grouping
julia> t = Table(
           firstname = ["Alice", "Bob", "Charlie", "Adam", "Eve", "Cindy", "Arthur"],
           lastname = ["Smith", "Smith", "Smith", "Williams", "Williams", "Brown", "King"],
           age = [25, 42, 37, 65, 18, 33, 54]
       )
Table with 3 columns and 7 rows:
     firstname  lastname  age
   ┌─────────────────────────
 1 │ Alice      Smith     25
 2 │ Bob        Smith     42
 3 │ Charlie    Smith     37
 4 │ Adam       Williams  65
 5 │ Eve        Williams  18
 6 │ Cindy      Brown     33
 7 │ Arthur     King      54
```

Let's get familiar with the *basic* usage of `group` on standard (non-tabular) arrays. For example, let's group people's first name by their first letter.
```jldoctest grouping
julia> using SplitApplyCombine

julia> group(first, t.firstname)
4-element Dictionaries.Dictionary{Char, Vector{String}}:
 'A' │ ["Alice", "Adam", "Arthur"]
 'B' │ ["Bob"]
 'C' │ ["Charlie", "Cindy"]
 'E' │ ["Eve"]
```
The groups are returned as a `Dict` where they indices (or keys) of the dictionary are the first character of people's firstname string. The values of the `Dict` are arrays listing the matching firstnames.

Next, we may want to group up data coming from a table (not just a single column). For example, we may want to group firstnames by lastname.

```jldoctest grouping
julia> group(getproperty(:lastname), getproperty(:firstname), t)
4-element Dictionaries.Dictionary{String, Vector{String}}:
    "Smith" │ ["Alice", "Bob", "Charlie"]
 "Williams" │ ["Adam", "Eve"]
    "Brown" │ ["Cindy"]
     "King" │ ["Arthur"]
```
Note that the returned structure is still not a `Table` at all - it is a dictionary (`Dict`) with the unique `lastname` values as keys, returing (non-tabular) arrays of `firstname`.

If instead, our grouping elements are `rows`, the group will be a table. For example, we can just drop the `getproperty(:firstname)` projection to get:

```jldoctest grouping
julia> groups = group(getproperty(:lastname), t)
4-element Dictionaries.Dictionary{String, Table{@NamedTuple{firstname::String, lastname::String, age::Int64}, 1, @NamedTuple{firstname::Vector{String}, lastname::Vector{String}, age::Vector{Int64}}}}:
    "Smith" │ [(firstname = "Alice", lastname = "Smith", age = 25), (firstname …
 "Williams" │ [(firstname = "Adam", lastname = "Williams", age = 65), (firstnam…
    "Brown" │ [(firstname = "Cindy", lastname = "Brown", age = 33)]
     "King" │ [(firstname = "Arthur", lastname = "King", age = 54)]
```
The results are only summarized (for compactness), but can be easily accessed.
```jldoctest grouping
julia> groups["Smith"]
Table with 3 columns and 3 rows:
     firstname  lastname  age
   ┌─────────────────────────
 1 │ Alice      Smith     25
 2 │ Bob        Smith     42
 3 │ Charlie    Smith     37
```

## Lazy grouping

There are additional functions provided to do grouping while copying less data.

A `groupinds` function let's you identify the indices of the rows belonging to certain groups.

```jldoctest grouping
julia> lastname_inds = groupinds(t.lastname)
4-element Dictionaries.Dictionary{String, Vector{Int64}}:
    "Smith" │ [1, 2, 3]
 "Williams" │ [4, 5]
    "Brown" │ [6]
     "King" │ [7]
```

We can then use these indices to perform calculations on each group of data, for example the mean age per lastname grouping.

```julia-repl
julia> using Statistics

julia> Dict(lastname => mean(t.age[inds]) for (lastname, inds) in lastname_inds)
Dict{String, Float64} with 4 entries:
  "King"     => 54.0
  "Williams" => 41.5
  "Brown"    => 33.0
  "Smith"    => 34.6667
```

There is additionally a `groupview` function, which calculates the `groupinds` and constructs each subset as a `view`.

## Summarizing groups with `groupreduce`

Sometimes we can perform a split-apply-combine strategy by streaming just once over the data, and reducing over the groups. The `groupreduce` function lets us do this, and can be more performant than alternative approaches.

For example, we can sum up the ages corresponding to each family name.

```jldoctest grouping
julia> groupreduce(getproperty(:lastname), getproperty(:age), +, t)
4-element Dictionaries.Dictionary{String, Int64}:
    "Smith" │ 104
 "Williams" │ 83
    "Brown" │ 33
     "King" │ 54
```

*SplitApplyCombine* provides related functions `groupsum`, `groupprod`, and so-on. One particularly handy function for summarizing data by giving counts of unique values is `groupcount`.

```jldoctest grouping
julia> groupcount(t.lastname)
4-element Dictionaries.Dictionary{String, Int64}:
    "Smith" │ 3
 "Williams" │ 2
    "Brown" │ 1
     "King" │ 1
```
