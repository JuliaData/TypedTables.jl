# Release history

Note: minor changes and bug fixes may be ommited from this document.

### 0.0.3

- New super-macro @select does selection plus more. Includes 3 abilities:
      @select(table, col1, newname = col2, newcol::newtype = col1 -> f(col1))
  1) select a column "col1"
  2) rename a column "col2" to new name "newname"
  3) compute a new column "newcol" from the data in "col" via a comprehension
     over f(table[Val{:col1}])
- New macro @filter does similarly on selecting rows. Takes the format:
      @filter(table, col1 -> col1 == 1, (col1, col2) -> col1 < col2)
  Similarly related `@filter!` and `@filter_mask` macros a provided.

### 0.0.3

- Set operations: `unique()`, `unique!()`, `uniqueind()`, `groupinds()`,
  `union()`, `intersect()` and `setdiff()`.
- Ability to import a table from a `DataFrame` or file `IOStream` using
  `readtable()`
- Ability to write a table to CSV/DLM format using `writetable()`
- `vcat` for reordered indices, like already possible for `append!`

### 0.0.2

Improved pretty-printing, bug fixes.

### 0.0.1

First official release.
