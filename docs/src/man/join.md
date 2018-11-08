# Joining data

The methods defined so far work on single data sources (tables) at-a-time. Sometimes, we need to *join* information together from multiple tables.

## Cartesian product/join of tables

Before progressing to the typical "join" operations on tables, we'll discuss the Cartesian product (or Cartesian "join") between two tables. In SQL, this is called the `CROSS JOIN`.

Suppose `table1` has `n` rows, and `table2` has `m` rows. We can create a new table that contains `n × m` rows with the data from `table1` and `table2`. In fact, if the output `table3` were an `n × m` *matrix* of rows, we could say that the row `table3[i, j]` contains the combination of `table1[i]` and `table2[j]`.

The easiest way to do this is with the `SplitApplyCombine.product`. For a quick primer, `out = product(f, a, b)` returns an array `out` such that `out[i, j] = f(a, b)`. For example, let's take all combinations of the sums of `[1, 2, 3]` and `[10, 20, 30, 40]`.

```julia
julia> product(+, [1, 2, 3], [10, 20, 30, 40])
3×4 Array{Int64,2}:
 11  21  31  41
 12  22  32  42
 13  23  33  43
```

One can also use `tuple` to simply collect both sets of data.

```julia
julia> product(tuple, [1, 2, 3], [10, 20, 30, 40])
3×4 Array{Tuple{Int64,Int64},2}:
 (1, 10)  (1, 20)  (1, 30)  (1, 40)
 (2, 10)  (2, 20)  (2, 30)  (2, 40)
 (3, 10)  (3, 20)  (3, 30)  (3, 40)
```

(Note that `tuple` is the *only* option for the similar function `Iterators.product`). Let's try this with a table. This time, for two tables with *distinct* column names, we can use the `merge` function to merge the rows into single `NamedTuple`s - for example, take this list of all pairings of firstnames and lastnames.

```julia
julia> t1 = Table(firstname = ["Alice", "Bob", "Charlie"])
Table with 1 column and 3 rows:
     firstname
   ┌──────────
 1 │ Alice
 2 │ Bob
 3 │ Charlie

julia> t2 = Table(lastname = ["Smith", "Williams", "Brown", "King"])
Table with 1 column and 4 rows:
     lastname
   ┌─────────
 1 │ Smith
 2 │ Williams
 3 │ Brown
 4 │ King

julia> t3 = product(merge, t1, t2)
Table with 2 columns and 3×4 rows:
       firstname  lastname
     ┌────────────────────
 1,1 │ Alice      Smith
 2,1 │ Bob        Smith
 3,1 │ Charlie    Smith
 1,2 │ Alice      Williams
 2,2 │ Bob        Williams
 3,2 │ Charlie    Williams
 1,3 │ Alice      Brown
 2,3 │ Bob        Brown
 3,3 │ Charlie    Brown
 1,4 │ Alice      King
 2,4 │ Bob        King
 3,4 │ Charlie    King

julia> size(t3)
(3, 4)
```
Remember that one must be careful that the column names are indeed distinct when using `product(merge, ...)` this way.

This is our first example of a `Table` which an array of higher than one-dimension - it is an `AbstractMatrix`. The `product` of many tables may be a `3`- or higher-dimensional array. Note that higher-dimensional tables do not print as a matrix like other higher-dimensional arrays at the REPL, as this would quickly obscure the columns. Instead, the indices are displayed to the left of each row.

Finally, also note that there is a `productview` function for performing this operation lazily. This may be crucial to remember - the size of the output is the *product* of the size of the inputs, which grows very quickly even for very reasonably sized input tables. This operation can be very expensive in both time and memory if appropriate care isn't taken.

### Cartesian product with generators

One can feed in multiple inputs into a generator, and Julia will automatically take the Cartesian product of all inputs. For example:

```julia
julia> t3 = Table(merge(row1, row2) for row1 in t1, row2 in t2)
Table with 2 columns and 12 rows:
      firstname  lastname
    ┌────────────────────
 1  │ Alice      Smith
 2  │ Bob        Smith
 3  │ Charlie    Smith
 4  │ Alice      Williams
 5  │ Bob        Williams
 6  │ Charlie    Williams
 7  │ Alice      Brown
 8  │ Bob        Brown
 9  │ Charlie    Brown
 10 │ Alice      King
 11 │ Bob        King
 12 │ Charlie    King
```

## Relational "join"

In a nutshell: the relational "join" operation is simply the above Cartesian product followed by a filtering operation. Generally, the filtering operation will depend on information coming from *both* input data sets - for example, that the values in a particular column must match exactly. (Any filtering that depends only on information from one input table can be done more efficiently *before* the join operation).

For a simple example, let's look for all pairings of firstnames and lastnames that have an equal number of characters. For efficiency, we combine this with `productview`.
```julia
julia> filter(row -> length(row.firstname) == length(row.lastname), t3)
Table with 2 columns and 2 rows:
     firstname  lastname
   ┌────────────────────
 1 │ Alice      Smith
 2 │ Alice      Brown
```

Many might find that this two-step process a rather indirect way of performing a join operation. Below we cover two more standard techniques.

### Using primary and foreign keys

Before launching into `innerjoin`, it is worth taking a detour to expore a common case where a far simpler operation can perform the requisite join - indexing!

In a relation, a "primary" key is a column (or multiple columns) with values that uniquely identify the row - no two rows may have the same primary key. `Table` and `FlexTable` do not *directly* support uniqueness in the columns (though the *array* corresponding to a column could surely enforce uniqueness). However, each row *is* uniquely identified by it's index, for example `t1[1]` corresponds to the row `(firstname = "Alice",)`.

In fact, using the array index as the primary key can be the most efficient way of uniquely identifying your data. A second table with related data may indeed have a column containing the indices of relevant rows in the first table. Such columns are generally referred to as being a "foreign key" (they uniquely identify data in a "foreign" table).

As an example, let's take a simplistic `customers` and `orders` database.

```julia
julia> customers = Table(name = ["Alice", "Bob", "Charlie"], address = ["12 Beach Street", "163 Moon Road", "6 George Street"])
Table with 2 columns and 3 rows:
     name     address
   ┌─────────────────────────
 1 │ Alice    12 Beach Street
 2 │ Bob      163 Moon Road
 3 │ Charlie  6 George Street

julia> orders = Table(customer_id = [2, 2, 3, 3], items = ["Socks", "Tie", "Shirt", "Underwear"])
Table with 2 columns and 4 rows:
     customer_id  items
   ┌───────────────────────
 1 │ 2            Socks
 2 │ 2            Tie
 3 │ 3            Shirt
 4 │ 3            Underwear
```
To get the customer for each order is just a simple indexing operation.

```julia
julia> customers[orders.customer_id]
Table with 2 columns and 4 rows:
     name     address
   ┌─────────────────────────
 1 │ Bob      163 Moon Road
 2 │ Bob      163 Moon Road
 3 │ Charlie  6 George Street
 4 │ Charlie  6 George Street

```
We can denormalize the orders and their customers to a single table by performing a `merge` on each row (in this case using broadcasting dot-syntax for brevity).

```julia
julia> merge.(customers[orders.customer_id], orders)
Table with 4 columns and 4 rows:
     name     address          customer_id  items
   ┌─────────────────────────────────────────────────
 1 │ Bob      163 Moon Road    2            Socks
 2 │ Bob      163 Moon Road    2            Tie
 3 │ Charlie  6 George Street  3            Shirt
 4 │ Charlie  6 George Street  3            Underwear

```

We can perform these operation lazily for cost *O*(1) using `view` and `mapview` - after which the data can be processed further.

```julia
julia> mapview(merge, view(customers, orders.customer_id), orders)
Table with 4 columns and 4 rows:
     name     address          customer_id  items
   ┌─────────────────────────────────────────────────
 1 │ Bob      163 Moon Road    2            Socks
 2 │ Bob      163 Moon Road    2            Tie
 3 │ Charlie  6 George Street  3            Shirt
 4 │ Charlie  6 George Street  3            Underwear
```

This is a simple and powerful technique. By [normalizing](https://en.wikipedia.org/wiki/Database_normalization) your one-to-many relationships into multiple tables using the array index as primary and foreign keys, you can join your data together quickly and efficiently with (possibly lazy) indexing.

### Inner join

We now turn out attention to the relational join, implemented via *SplitApplyCombine*'s `innerjoin` function (note that the `join` function in `Base` is a concatenation operation on strings, not a relational operation on tables).

The `innerjoin` function is flexible, able to join any iterable data source via any comparing predicate, and perform an arbitrary mapping of the matching results. Using `?`, we can view its documentation at the REPL:

```julia
help?> innerjoin
search: innerjoin

  innerjoin(lkey, rkey, f, comparison, left, right)

  Performs a relational-style join operation between iterables left and right,
  returning a collection of elements f(l, r) for which comparison(lkey(l), rkey(r))
  is true where l ∈ left, r ∈ right.

  Example
  ≡≡≡≡≡≡≡≡≡

  julia> innerjoin(iseven, iseven, tuple, ==, [1,2,3,4], [0,1,2])
  6-element Array{Tuple{Int64,Int64},1}:
   (1, 1)
   (2, 0)
   (2, 2)
   (3, 1)
   (4, 0)
   (4, 2)
```

Let's examine this. Assume the inputs `left` and `right` are `Table`s. We may want to join the tables via a single column each, in which case `getproperty(:name)` would be suitable for `lkey` and `rkey`. In the simplest case, such as a natural join, for `f` we may want to `merge` all the columns from both input tables (which is the default for `f`), and the `comparison` operator may be equality (it defaults to `isequal`).

As an example, we modify our `customers` table to explicitly include the customer's `id`, similarly to above.

```julia
julia> customers = Table(id = 1:3, name = ["Alice", "Bob", "Charlie"], address = ["12 Beach Street", "163 Moon Road", "6 George Street"])
Table with 3 columns and 3 rows:
     id  name     address
   ┌─────────────────────────────
 1 │ 1   Alice    12 Beach Street
 2 │ 2   Bob      163 Moon Road
 3 │ 3   Charlie  6 George Street

julia> innerjoin(getproperty(:id), getproperty(:customer_id), customers, orders)
Table with 5 columns and 4 rows:
     id  name     address          customer_id  items
   ┌─────────────────────────────────────────────────────
 1 │ 2   Bob      163 Moon Road    2            Socks
 2 │ 2   Bob      163 Moon Road    2            Tie
 3 │ 3   Charlie  6 George Street  3            Shirt
 4 │ 3   Charlie  6 George Street  3            Underwear
```

The `innerjoin` function can be used to join any tables based on any conditions. However, by default only the `isequal` comparison is accelerated via a temporary hash index - all other comparisons will invoke an exhaustive *O*(`n^2`) algorithm.

See the section on Acceleration Indices for methods of (a) attaching secondary acceleration indices to your columns, and (b) using these to accelerate operations using comparisons other than `isequal`. For example, a `SortIndex` can be used to accelerate joins on order-related predicates, such as the value in one column being smaller than another column.

### Inner joins with generators

As a final example, generators provide a convenient syntax for filtering Cartesian products of collections - that is, to perform an inner join!

```julia
julia> Table(merge(customer, order) for customer in customers, order in orders if customer.id == order.customer_id)
Table with 5 columns and 4 rows:
     id  name     address          customer_id  items
   ┌─────────────────────────────────────────────────────
 1 │ 2   Bob      163 Moon Road    2            Socks
 2 │ 2   Bob      163 Moon Road    2            Tie
 3 │ 3   Charlie  6 George Street  3            Shirt
 4 │ 3   Charlie  6 George Street  3            Underwear
```

The disadvantage of this technique is that it will perform an exhaustive search by default, costing *O*(`n^2`).

## Left-group-join

Currently *SplitApplyCombine* and *TypedTables* do not provide what in SQL is called an `LEFT OUTER JOIN` (or any of the other `OUTER JOIN` operations).

Such a query can be alternatively modeled as a hybrid group/join operation. *SplitApplyCombine* provides `leftgroupjoin` to perform precisely this. This is similar to LINQ's `GroupJoin` method. Let us investigate this query with the same data as for `innerjoin`, above.

```julia
julia> groups = leftgroupjoin(getproperty(:id), getproperty(:customer_id), customers, orders)
Dict{Int64,Table{NamedTuple{(:id, :name, :address, :customer_id, :items),Tuple{Int64,String,String,Int64,String}},1,NamedTuple{(:id, :name, :address, :customer_id, :items),Tuple{Array{Int64,1},Array{String,1},Array{String,1},Array{Int64,1},Array{String,1}}}}} with 3 entries:
  2 => Table with 5 columns and 2 rows:…
  3 => Table with 5 columns and 2 rows:…
  1 => Table with 5 columns and 0 rows:…

julia> groups[1]
Table with 5 columns and 0 rows:
     id  name  address  customer_id  items
   ┌──────────────────────────────────────

julia> groups[2]
Table with 5 columns and 2 rows:
     id  name  address        customer_id  items
   ┌────────────────────────────────────────────
 1 │ 2   Bob   163 Moon Road  2            Socks
 2 │ 2   Bob   163 Moon Road  2            Tie

julia> groups[3]
Table with 5 columns and 2 rows:
     id  name     address          customer_id  items
   ┌─────────────────────────────────────────────────────
 1 │ 3   Charlie  6 George Street  3            Shirt
 2 │ 3   Charlie  6 George Street  3            Underwear
```

As you can see - 3 groups were identified, according to the distinct keys in the `id` column of `customers`. While the first customer had no associated orders, note that an empty group has nonetheless been created. Much like SQL's `LEFT OUTER JOIN` command, `leftgroupjoin` lets us handle the case that no matching data is found. While SQL achieves this by noting there is `missing` data in the columns associated with the right table, here we use a set of nested containers (dictionaries of tables of rows) to denote the relationship.