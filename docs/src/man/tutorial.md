# Quick start tutorial

After reading this tutorial, you should be able to use Julia to perform a range of data
analysis tasks. Only basic knowledge of Julia is assumed, such as how to install packages
and use an array.

## Making and using a `Table`

It's simple to get started and create a table!

A `Table` is a wrapper around column arrays. Suppose you have an array containing names and
an array containing ages, then you can create a table with two columns:

```julia
julia> t = Table(name = ["Alice", "Bob", "Charlie"], age = [25, 42, 37])
Table with 2 columns and 3 rows:
     name     age
   ┌─────────────
 1 │ Alice    25
 2 │ Bob      42
 3 │ Charlie  37
```

A `Table` behaves as a Julia array that contains named tuples for each row. Each row is a
single element - you should consider the above as a one-dimensional container with three
elements, rather than as a two-dimensional "matrix" of six cells. Another name for a
collection of named tuples is a "relation", and `Table`s are useful for performing
[relational algebra](https://en.wikipedia.org/wiki/Relational_algebra).

You can access elements (rows) exactly like any other Julia array.

```julia
julia> t[1]
(name = "Alice", age = 25)

julia> t[1:2]
Table with 2 columns and 2 rows:
     name   age
   ┌───────────
 1 │ Alice  25
 2 │ Bob    42
```

A element (row) of the table can be updated with the usual array syntax.

```julia
julia> t[1] = (name = "Alice", age = 26);  # Alice had a birthday!

julia> t
Table with 2 columns and 3 rows:
     name     age
   ┌─────────────
 1 │ Alice    26
 2 │ Bob      42
 3 │ Charlie  37
```

You can easily access a column by the tables "properties", use the `.` operator.

```julia
julia> t.name
3-element Array{String,1}:
 "Alice"  
 "Bob"    
 "Charlie"
```

You can ask what the properties (column names) of a `Table` with the `propertynames`
function (as well as the `columnnames` function).

```julia
julia> propertynames(t)
(:name, :age)
```

Recall that `:name` is a `Symbol` - which you can think of a special kind of string that the
compiler works with when considering Julia code itself.

Individual cells can be accessed in two, symmetric ways.

```julia
julia> t.name[2]
"Bob"

julia> t[2].name
"Bob"
```

Note that the first way is more efficient, and recommended, because in the second case the
intermediate value `t[2]` is assembled from the elements of *all* the columns. The first
syntax also supports updating.

```julia
julia> t.name[2] = "Robert";  # No nicknames here...

julia> t
Table with 2 columns and 3 rows:
     name     age
   ┌─────────────
 1 │ Alice    26
 2 │ Robert   42
 3 │ Charlie  37
```

The names and number of columns in a `Table` are fixed and immutable. You cannot add, remove, or delete
columns from a `Table`. Instead, a new table should be formed - you can even call the new
table by the old variable name, if you want.

Multiple tables and additional columns can be created in the one `Table` constructor. For
example, it is easy to add an additional column.

```julia
julia> Table(t; lastname = ["Smith", "Smith", "Smith"])
Table with 3 columns and 3 rows:
     name     age  lastname
   ┌───────────────────────
 1 │ Alice    26   Smith
 2 │ Robert   42   Smith
 3 │ Charlie  37   Smith
```

And we can delete a column by setting it to `nothing`.

```julia
julia> Table(t; age = nothing)
Table with 1 column and 3 rows:
     name
   ┌────────
 1 │ Alice
 2 │ Robert
 3 │ Charlie
```

Because the names and types of your columns are fixed on any line of code, Julia's compiler
is able to produce lightning fast machine code for processing your data.

## `FlexTable`

Sometimes, it *is* handy to be able to add, remove and rename columns without create a new
`Table` container. The `FlexTable` type allows for this.

```julia
julia> ft = FlexTable(names = ["Alice", "Bob", "Charlie"])
FlexTable with 1 column and 3 rows:
     names
   ┌────────
 1 │ Alice
 2 │ Bob
 3 │ Charlie

julia> ft.age = [25, 42, 37];

julia> ft
FlexTable with 2 columns and 3 rows:
     names    age
   ┌─────────────
 1 │ Alice    25
 2 │ Bob      42
 3 │ Charlie  37
```

A column can be deleted by setting it to `nothing`.

```julia
julia> ft.age = nothing;

julia> ft
FlexTable with 1 column and 3 rows:
     names
   ┌────────
 1 │ Alice
 2 │ Bob
 3 │ Charlie
```

A `FlexTable` will be just as fast as a `Table` in most contexts. However, Julia's compiler
will not be able to predict in advance the names and types of the columns. The main thing to
watch is that an explicit `for` loop over the rows of a `FlexTable` will be a bit slower
than that of a `Table` - but all the operations demonstrated in this tutorial will be just
as speedy!

## Missing data

The recommended way to handle missing data in Julia is by using `missing`, which is a value
with its very own type `Missing`. For example, we may create a table where some people
haven't specified their age.

```julia
julia> Table(name = ["Alice", "Bob", "Charlie"], age = [25, missing, 37])
Table with 2 columns and 3 rows:
     name     age
   ┌─────────────────
 1 │ Alice    25
 2 │ Bob      missing
 3 │ Charlie  37
```

In Julia, `missing` values propagate safely where this is appropriate. For example,
`missing + 1` is also `missing` - if we didn't know the value before, we still don't after
adding `1`. This makes working with missing data simple and pain-free, and Julia's
optimizing compiler also makes it extremely fast.

## Loading and saving data from files

*TypedTables.jl* integrates seemlessly into an ecosystem of Julia I/O packages. For example,
we can use *CSV.jl* to load and save CSV files. Let's say we have a CSV file called
`input.csv` with the following data.

```
name,age
Alice,25
Bob,42
Charlie,37
```

We can load this file from disk using the `CSV.read` function.

```julia
julia> using CSV

julia> t = CSV.read("input.csv", Table)
FlexTable with 2 columns and 3 rows:
     names    age
   ┌─────────────
 1 │ Alice    25
 2 │ Bob      42
 3 │ Charlie  37
```

Similary, we can write a table to a new file `output.csv` with the `CSV.write` function.

```julia
julia> CSV.write("output.csv", t)
```

## Finding data

Julia's broadcasting and indexing syntax can work together to make it easy to find rows
of data based on given creteria. Suppose we wanted to find all the "old" people in the 
table.

```julia
julia> t = Table(name = ["Alice", "Bob", "Charlie"], age = [25, 42, 37])
Table with 2 columns and 3 rows:
     name     age
   ┌─────────────
 1 │ Alice    25
 2 │ Bob      42
 3 │ Charlie  37

julia> t.age .> 40
3-element BitArray{1}:
 false
  true
 false
```

Bob and Alice might disagree about what "old" means, but here we have identified all the
people over 40 years of age. Note the difference between the "scalar" operator `>` and the 
"broadcasting" operator `.>`.

We can use "logical" indexing to collect the rows for which the above predicate is `true`.

```julia
julia> t[t.age .> 40]
Table with 2 columns and 1 row:
     name  age
   ┌──────────
 1 │ Bob   42
```

Data can also be found with Julia's standard `filter` and `findall` functions.

## Summarizing data

Julia has a range of standard functions for asking common questions about a set of data.

For example, we can use the `in` operator to test if an entry is in a column.

```julia
julia> "Bob" in t.name
true
```

Or if a given row is `in` the table.

```julia
julia> (name = "Bob", age = 41) in t
false
```

(Bob is older than that).

We can `sum` columns, and with the `Statistics` standard library, we can find the `mean`,
`median`, and so-on.

```julia
julia> sum(t.age)
104

julia> using Statistics

julia> mean(t.age)
34.666666666666664

julia> median(t.age)
37.0
```

By these metrics, Bob's age *is* above average!

## Mapping data

Functions which map rows to new rows can be used to create new tables. 

Below, we create an annonymous function which takes a row containing a name and an age, and
returns an inital letter and whether the person is old (greater than 40), and use Julia's
built-in `map` function.

```julia
julia> map(row -> (initial = first(row.name), is_old = row.age > 40), t)
Table with 2 columns and 3 rows:
     initial  is_old
   ┌────────────────
 1 │ A        false
 2 │ B        true
 3 │ C        false
```

Writing anonymous functions can become laborious when dealing with many rows, so the
convenience macros `@Select` and `@Compute` are provided to aid in their construction.

The `@Select` macro returns a function that can map a row to a new row (or a table to a
new table) by defining a functional mapping for each output column. The above example can
alternatively be written as:

```julia
julia> map(@Select(initial = first($name), is_old = $age > 40), t)
Table with 2 columns and 3 rows:
     initial  is_old
   ┌────────────────
 1 │ A        false
 2 │ B        true
 3 │ C        false
```

For shorthand, the `= ...` can be ommited to simply extract a column. For example, we can
reorder the columns via

```
julia> @Select(age, name)(t)
Table with 2 columns and 3 rows:
     age  name
   ┌─────────────
 1 │ 25   Alice
 2 │ 42   Bob
 3 │ 37   Charlie
```
(Note that here we "select" columns directly, rather than using `map` to select the fields
of each row.)

The `@Compute` macro returns a function that maps a row to a value. As for `@Select`, the
input column names are prepended with `$`, for example:

```julia
julia> map(@Compute($name), t)
3-element Array{String,1}:
 "Alice"  
 "Bob"    
 "Charlie"
```

Unlike an anonymous function, these two macros create an introspectable function that allows
computations to take advantage of columnar storage and advanced features like acceleration
indices. You may find calculations may be performed faster with the macros for a wide
variety of functions like `map`, `broadcast`, `filter`, `findall`, `reduce`, `group` and
`innerjoin`. For instance, the example above simply extracts the `name` column from `t`,
without performing an explicit map.

## Grouping data

Frequently, one wishes to group and process data using a so-called "split-apply-combine"
methodology. *TypedTables* is a lightweight package and does not provide this functionality
directly - but it has been designed carefully to work optimally with external packages.

One such package is *SplitApplyCombine.jl*, which provides common operations for grouping
and joining data (if you wish, you may view its documentation
[here](https://github.com/JuliaData/SplitApplyCombine.jl)).

We will demonstrate grouping data with a slightly more complex dataset.

```julia
julia> t2 = Table(firstname = ["Alice", "Bob", "Charlie", "Adam", "Eve", "Cindy", "Arthur"], lastname = ["Smith", "Smith", "Smith", "Williams", "Williams", "Brown", "King"], age = [25, 42, 37, 65, 18, 33, 54])
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

Let us begin with basic usage of the `group` function from *SplitApplyCombine*, where we
wish to group firstnames by their initial letter.

```julia
julia> using SplitApplyCombine

julia> group(first, t2.firstname)
Dict{Char,Array{String,1}} with 4 entries:
  'C' => ["Charlie", "Cindy"]
  'A' => ["Alice", "Adam", "Arthur"]
  'E' => ["Eve"]
  'B' => ["Bob"]
```

The `group` function returns a dictionary (`Dict`) where the grouping key is calculated on
each row by the function passed as the first argument - in this case `first`. We can see the
firstnames starting with the letter `A` belong to the same group, and so on.

Sometimes you may want to transform the grouped data - you can do so by passing a second
mapping function. For example, we may want to group firstnames by lastname.

```julia
julia> group(@Compute($lastname), $Compute($firstname), t2)
Dict{String,Array{String,1}} with 4 entries:
  "King"     => ["Arthur"]
  "Williams" => ["Adam", "Eve"]
  "Brown"    => ["Cindy"]
  "Smith"    => ["Alice", "Bob", "Charlie"]
```
Note that the returned structure is still not a `Table` at all - it is a dictionary with the
unique `lastname` values as keys, returing (non-tabular) arrays of `firstname`.

If instead, our group elements are rows (named tuples), each group will itslef be a table.
For example, we can keep the entire row by dropping the second function.

```julia
julia> families = group(@Compute($lastname), t2)
Groups{String,Any,Table{NamedTuple{(:firstname, :lastname, :age),Tuple{String,String,Int64}},1,NamedTuple{(:firstname, :lastname, :age),Tuple{Array{String,1},Array{String,1},Array{Int64,1}}}},Dict{String,Array{Int64,1}}} with 4 entries:
  "King"     => Table with 3 columns and 1 row:…
  "Williams" => Table with 3 columns and 2 rows:…
  "Brown"    => Table with 3 columns and 1 row:…
  "Smith"    => Table with 3 columns and 3 rows:…
```

The results are only summarized above (for compactness), but can be easily accessed.

```julia
julia> families["Smith"]
Table with 3 columns and 3 rows:
     firstname  lastname  age
   ┌─────────────────────────
 1 │ Alice      Smith     25
 2 │ Bob        Smith     42
 3 │ Charlie    Smith     37
```

There are also more advanced functions `groupreduce`, `groupinds` and `groupview`, which may
help you perform your analysis more succinctly and faster, and are covered in later sections
of this manual.

## Joining data

A very common relational operation is to *join* the data from two tables based on certain
commonalities, such as the values matching in two columns. *SplitApplyCombine.jl* provides
an `innerjoin` function for precisely this (please note that `join` is a Julia operation to
concatenate strings).

Let's suppose we have a small database of customers, and the items they have ordered from
an online store.

```julia
julia> customers = Table(id = 1:3, name = ["Alice", "Bob", "Charlie"], address = ["12 Beach Street", "163 Moon Road", "6 George Street"])
Table with 3 columns and 3 rows:
     id  name     address
   ┌─────────────────────────────
 1 │ 1   Alice    12 Beach Street
 2 │ 2   Bob      163 Moon Road
 3 │ 3   Charlie  6 George Street

julia> orders = Table(customer_id = [2, 2, 3, 3], items = ["Socks", "Tie", "Shirt", "Underwear"])
Table with 2 columns and 4 rows:
     customer_id  items
   ┌───────────────────────
 1 │ 2            Socks
 2 │ 2            Tie
 3 │ 3            Shirt
 4 │ 3            Underwear
```

Here, these two tables are related by the customer's `id`. We can join the two tables on
this column to determine the `address` that we need to send the `items` to. The `innerjoin`
function expects two functions, to describe the joining key of the first table and the
joining key of the second table. We will use `getproperty` to select the columns.

```julia
julia> innerjoin(@Compute($id), @Compute($customer_id), customers, orders)
Table with 5 columns and 4 rows:
     id  name     address          customer_id  items
   ┌─────────────────────────────────────────────────────
 1 │ 2   Bob      163 Moon Road    2            Socks
 2 │ 2   Bob      163 Moon Road    2            Tie
 3 │ 3   Charlie  6 George Street  3            Shirt
 4 │ 3   Charlie  6 George Street  3            Underwear
```

By default, `innerjoin` will `merge` all of the columns. Like `group`, the `innerjoin`
function can accept an additional function to describe a mapping to desired output (as well
as a comparison operation on the keys). The more advanced features of `innerjoin` and other
types of joins are covered in later sections of this manual.

## Progressing onwards

Congratulations on completing the introductory tutorial. You should now know enough basics
to get started with data analysis in Julia using *TypedTables.jl* and related packages.

The following setions of the manual demonstrate more advanced techniques, explain the 
design of this (and related) packages, and provide an API reference.
