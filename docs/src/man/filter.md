# Finding data

Frequently, we need to find data that matches certain criteria, and there are multiple mechanisms for achieving this in Julia.

Imagine we have a predicate function `pred` that takes a complete row of a table (ie. a `NamedTuple`) and returns either `true` or `false`. We can find indentify the rows using multiple techniques.

 * Using `result = filter(pred, table)` to return a new table with just the rows matching `true`.
 * Using `selection = map(pred, table)` to return an array of `true`s and `false`s. The `table` can be filtered to just the matching rows via logical indexing, `result = table[selection]`. (Internally, Julia tends to perform `filter` with this method).
 * Using `indices = findall(pred, table)` to return an array of the indices for which `pred` is `true`. 

Depending on your data (particularly, what fraction of data you expect to retain), either the second or third strategy may be more efficient.

## Preselection

As mentioned in other sections, it is frequently worthwhile to preselect the columns relating to your search predicate, to avoid any wastage in fetching from memory values in columns that you don't care about.

One simple example of such a transformation is to first project to the column(s) of interest, followed by using `map` or `findall` to identify the indices of the rows where `pred` is `true`, and finally to use `getindex` or `view` to obtain the result.