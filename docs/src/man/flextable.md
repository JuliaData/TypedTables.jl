# FlexTable

This package defines a second tabular container type, `FlexTable`, that is designed to be a more **flex**ible **table**.

The two primary difference between `Table` and `FlexTable` are that

 * The columns can be mutated - that is, we can add, replace or delete a column.
 * The compiler cannot track the types or names of the columns.

Thus, a `FlexTable` provides the same interface as a `Table` plus some extra operations. However, the fact that the compiler can no longer statically analyse the names and types of the columns at any given moment of the program means that the element type of a `FlexTable` is no more specific than `NamedTuple`. Iteration over rows will therefore be slower using `for` loops than for the equivalent `Table` - for maximum speed, higher-level functions (like `map`, `filter`, `reduce`, `group` and `innerjoin`) or a high-level DSL (like *Query.jl*) should be utilized.

Amongst other things, using `FlexTable` might allow you to more easily port your code from another environment where the columns are mutable, such as *DataFrames.jl*.

## Adding or replacing columns

A column can be added by using the `.` operator (also known as `setproperty!`).

```julia
julia> ft = FlexTable(name = ["Alice", "Bob", "Charlie"], age = [25, 42, 37])
FlexTable with 2 columns and 3 rows:
     name     age
   ┌─────────────
 1 │ Alice    25
 2 │ Bob      42
 3 │ Charlie  37

julia> ft.sex = [:F, :M, :M];

julia> ft
FlexTable with 3 columns and 3 rows:
     name     age  sex
   ┌──────────────────
 1 │ Alice    25   F
 2 │ Bob      42   M
 3 │ Charlie  37   M
```

The same syntax is used to replace a column.

```julia
julia> ft.sex = ["female", "male", "male"];

julia> ft
FlexTable with 3 columns and 3 rows:
     name     age  sex
   ┌─────────────────────
 1 │ Alice    25   female
 2 │ Bob      42   male
 3 │ Charlie  37   male
```
