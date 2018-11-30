# API Reference

*TypedTables.jl*'s API is intentially small, relying on existing interfaces to
expose powerful and composable functionality.

The reference material can be easily accessed at the REPL, by pressing `?` and
typing in the name of the command.

## Constructing tables

```@docs
TypedTables.Table
TypedTables.FlexTable
```

## Reflection

```@docs
TypedTables.columns
TypedTables.columnnames
```

## Convenience macros

These macros return *functions* that can be applied to tables and rows.

```@docs
TypedTables.@Compute
TypedTables.@Select
```
