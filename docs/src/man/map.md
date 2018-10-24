# Mapping rows of data

Some operations on your data will act by mapping each row of data in a table to a value, or even to new rows (in the case of relational operations). In either case, you are mapping an element of table (which is an array whose elements are rows) to create a new array of computed elements (whose elements may or may not be rows, and thus may or may not be a `Table`).

## Using `map`

In Julia, the idiomatic way to perform such an operation is with the `map` function, which takes a function and an input array.

One very simple example of this is extracting a column, let's say the column called `name` from a table of people's names and ages.

```julia
julia> t = Table(name = ["Alice", "Bob", "Charlie"], age = [25, 42, 37])
Table with 2 columns and 3 rows:
     name     age
   ┌─────────────
 1 │ Alice    25
 2 │ Bob      42
 3 │ Charlie  37

julia> map(row -> row.name, t)
3-element Array{String,1}:
 "Alice"  
 "Bob"    
 "Charlie"
```

This has returned and standard Julia array, which will be a *copy* of the array of the `name` column. We could also do a more complicated calculation.

```julia
julia> is_old = map(row -> row.age > 40, t)
3-element Array{Bool,1}:
 false
  true
 false
```
Depending on your definition of "old", we have identified two younger people and one older person - though I suspect that Bob may have a different definition of old than Alice does.

One can also `map` rows, which are `NamedTuple`s, to new `NamedTuples`, which will naturally result in a new tabular structure. Here is an example where we simply copy the names into a new table (but change the column name to `firstname`):

```julia
julia> map(row -> (firstname = row.name,), t)
Table with 1 column and 3 rows:
     firstname
   ┌────────────
 1 │ Alice
 2 │ Bob
 3 │ Charlie
```

Internally, this is leveraging Julia's `similar` interface for constructing new arrays: if we are creating something `similar` to a `Table` with an element type that is a `NamedTuple`, we get a new `Table`. (The columns themselves are also `similar` to the existing columns, preserving their structure as appropriate). If the output type is not a `NamedTuple`, the output array is `similar` to the first column.

Putting this all together, we can create a brand-new table using `map` to manipulate both columns.

```julia
julia> map(row -> (name = row.name, is_old = row.age > 40), t)
Table with 2 columns and 3 rows:
     name     is_old
   ┌────────────────
 1 │ Alice    false
 2 │ Bob      true
 3 │ Charlie  false
```

## Explicit `for` loops

One can easily use `for` loops to iterate over your data and perform whatever mapping is required. For example, this loop takes the `first` character of the elements of the `name` column.

```julia
julia> function firstletter(t::Table)
    out = Vector{Char}(undef, length(t))

    for i in 1:length(t)
        out[i] = first(t.name[i])
    end

    return out
end

julia> firstletter(t)
3-element Array{Char,1}:
 'A'
 'B'
 'C'
```

Julia will use the type information it knows about `t` to create fast, compiled code. (Pro tip: to make the above loop *optimal*, adding an `@inbounds` annotation on the same line before the `for` loop will remove redundant array bounds checking and make the loop execute faster).

## Generators

Julia syntax provide for compact syntax for generators and comprehensions to define arrays.

 * The syntax `[f(x) for x in y]` is called a "comprehension" and constructs a new `Array`.
 * The syntax `f(x) for x in y` is called a `Generator` and is a lazy, iterable container called `Base.Generator`.

Tables can be constructed from `Geneartor`s, allowing for some pretty neat syntax.

```julia
julia> Table((name=row.name, isold=row.age>40) for row in t)
Table with 2 columns and 3 rows:
     name     isold
   ┌───────────────
 1 │ Alice    false
 2 │ Bob      true
 3 │ Charlie  false
```

Generators and comprehensions also support filtering data and combining multiple datasets, which cover in *Finding Data* and *Joining Data*.

## Preselection

Functions like `map` are not necessarily very intelligent about which columns are required and which are not. The reason is simple: given the operation `map(f, t)`, the `map` method has very little insight into what `f` does.

Thus, in some cases it might improve performance to preselect the columns of interest. For example, extracting a single column, or constructing a new table with a reduced number of columns, may prevent `map` from loading unused values as it materializes each full row as it iterates, and lead to performance improvements.

## `getproperty` and `map`

When we want to perform more complex tasks, such as `group` or `innerjoin`, we may be interested in extracting data from specific columns.

Given a `row`, a field is extracted with the `row.name` syntax - which Julia transforms to the function call `getproperty(row, :name)`. This package defines `getproperty(:name)` as returning a new, single-argument *function* that takes a `row` and returns `row.name`.

Thus, one way of projecting a table down to a single column is to use the `getproperty` function, like so:
```
julia> map(getproperty(:name), t)
3-element Array{String,1}:
 "Alice"
 "Bob"
 "Charlie"
```
While this operation may seem pointless (it's a lot less direct than `t.name`, after all!), projecting to a single column will be a common operation for more complex tasks such as grouping data and performing relational joins.

A naive implementation of this would be to iterate the rows and *then* project down to just the column of interest. For efficiency, functions like `map` (and `group`, `innerjoin`, etc) will know they can first project a `Table` or `FlexTable` to just that column, before continuing - making the operations significantly faster.

## Lazy mapping

It is also worth mentioning the possibility of lazily mapping the values. Functions such as `mapview` from *SplitApplyCombine* can let you construct a "view" of a new table based on existing data. This way you can avoid using up precious resources, like RAM, yet can still call up data upon demand.