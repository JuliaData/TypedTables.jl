# Release history

Note: minor changes and bug fixes may be omitted from this document.

### 0.0.5 (27 May 2016)

- Improved, faster formatting. Now `Cell`, `Column`, `Row` and `Table` all use
  the same output style, with difference in border to identify the type.
  Previously a large amount of code was recompiled every time a table was
  shown, making printing of tables have an annoying delay in response. Now
  code reuse has been increased and the compilation delay reduced.

- Added mutating `union!()` function.

- coveralls activated. Inference bugs detected with awesome `@inferred` test
  macro and corrected.

### 0.0.4 (23 March 2016)

- New super-macro `@select` does selection plus more. Includes 3 abilities:

      `@select(table, col1, newname = col2, newcol::newtype = col1 -> f(col1))`

  1) select a column `col1`

  2) rename a column `col2` to new name `newname`

  3) compute a new column `newcol` from the data in `col` via a comprehension
     over `f(table[Val{:col1}])`

- New macro `@filter` does similarly on selecting rows. Takes the format:

      `@filter(table, col1 -> col1 == 1, (col1, col2) -> col1 < col2)`

  Similarly related `@filter!` and `@filter_mask` macros are provided.

### 0.0.3 (21 March 2016)

- Set operations: `unique()`, `unique!()`, `uniqueind()`, `groupinds()`,
  `union()`, `intersect()` and `setdiff()`.
- Ability to import a table from a `DataFrame` or file `IOStream` using
  `readtable()`
- Ability to write a table to CSV/DLM format using `writetable()`
- `vcat` for reordered indices, like already possible for `append!`

### 0.0.2 (16 March 2016)

Improved pretty-printing, bug fixes.

### 0.0.1 (16 March 2016)

First official release.
