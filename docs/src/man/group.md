# Grouping data

It is frequently useful to break data appart into different *groups* for processing - a paradigm frequently referred to a the split-apply-combine methodology.

In a powerful environment such as Julia, that fully supports nested containers, it makes sense to represent each group as distinct containers, with an outer container acting as a "dictionary" of the groups. This is in contrast to environments with a less rich system of containers, such as SQL, which has popularized a slightly different notion of grouping data into a single flat tabular structure, where one (or more) columns act as the grouping key. Here we focus on the former approach.

Data can be divided into groups by using the `group` function from *SplitApplyCombine*.

Can efficiently summarize the groups using `groupreduce`.

May also also use `groupinds` and `groupview` for efficiency reasons.
