# Built-in join types
abstract AbstractJoin
immutable InnerJoin <: AbstractJoin; end
immutable LeftJoin <: AbstractJoin; end
immutable RightJoin <: AbstractJoin; end
immutable OuterJoin <: AbstractJoin; end

# A trait for the join is whether it can be tested element-wise or not.
immutable DispatchableJoin; end
isdispatchable(x) = DispatchableJoin()

"""
    testjoin(a, b, [jointype])

Determine if two pieces of raw data are considered equal for the purpose of a
join, and return true or false. By default, uses jointype `InnerJoin()`, but
also other popular joins are implemented, including `LeftJoin()`, `RightJoin()` and
`OuterJoin()`.

Users may define their own jointype as a subtype of `AbstractJoin` as well as the
corresponding `testjoin()` and `dojoin()` functions to implement
`join(table1, table2, jointype)`.
"""
testjoin(a, b, jointype::InnerJoin = InnerJoin()) = a == b

"""
    dojoin(a, b, [jointype])

Given two pieces of raw data that are previously tested as being joinable, and
return the correct data. By default, uses jointype `InnerJoin()`, but
also other popular joins are implemented, including `LeftJoin()`, `RightJoin()` and
`OuterJoin()`.

Users may define their own jointype as a subtype of `AbstractJoin` as well as the
corresponding `testjoin()` and `dojoin()` functions to implement
join(table1, table2, jointype).
"""
dojoin(a, b, jointype::InnerJoin = InnerJoin()) = a


"""
    join(a::Row, b::Row, [jointype])

Determine if two rows data are considered equal for the purpose of a
join, and returns a nullable of the joined rows. By default, this will be
performed individually on each element of the row.

Users may define their own jointype as a subtype of `AbstractJoin` and the
corresponding method

  `join{Index}(a::Row{Index},b::Row{Index}, jointype)`

for joining (the overlapping potion of Rows) with more complex behaviour.
"""
Base.join{Index}(a::Row{Index}, b::Row{Index}, jointype::AbstractJoin = InnerJoin()) = join(a, b, jointype, isdispatchable(jointype))


@generated function Base.join{Index}(a::Row{Index}, b::Row{Index}, jointype::AbstractJoin = InnerJoin(), ::DispatchableJoin = DispatchableJoin())
    expr1 = Vector{Expr}(length(Index))
    for i = 1:length(Index)
        expr1[i] = :(if !testjoin(a.data[$i], b.data[$i], jointype); return Nullable{Row{$Index,$(eltypes(Index))}}(); end)
    end
    expr1 = Expr(:block, expr1...)

    expr2 = Vector{Expr}(length(Index))
    for i = 1:length(Index)
        expr2[i] = :( dojoin(a.data[$i], b.data[$i], jointype) )
    end
    expr2 = Expr(:tuple, expr2...)
    :($expr1; Nullable{Row{$Index,$(eltypes(Index))}}(Row{$Index,$(eltypes(Index))}($expr2)) )
end


function Base.join(a::Row, b::Row, jointype::AbstractJoin = InnerJoin())
    idx_a = setdiff(index(a),index(b))
    idx_ab = intersect(index(a),index(b))
    idx_b = setdiff(index(b),index(a))
    idx_out = idx_ab + idx_a + idx_b

    tmp = join(a[idx_ab],b[idx_ab],jointype)
    if isnull(tmp)
        return Nullable{Row{idx_out,eltypes(idx_out)}}()
    else
        return Nullable{Row{idx_out,eltypes(idx_out)}}(hcat(get(tmp),a[idx_a],b[idx_b]))
    end
end


"""
    join(a::Table, b::Table, [jointype])

Perform the relational join operation on two tables, generating a new `Table`.

A typical join operation searches for `Row`s which are equal in their overalapping
fields, and pushes a concatenation of the matches to the output table. However,
the join test may be something other than equality. Built-in joins include:

  `InnerJoin()` - equality tested with `==` [default]
  ...

Users may define their own jointype as a subtype of `TypedTables.AbstractJoin` and the
corresponding method for either (a) `TypedTables.testjoin()` and `TypedTables.dojoin()` for
individual data elements, or (b) `join()` on `Row`s for more complex behaviour (e.g.
multi-cell tests).
"""
function Base.join(a::Table, b::Table, jointype::AbstractJoin = InnerJoin())
    out = Table(intersect(index(a),index(b)) + setdiff(index(a),index(b)) + setdiff(index(b),index(a)))
    for i = 1:length(a)
        for j = 1:length(b)
            row = join(a[i],b[j],jointype)
            if !isnull(row)
                push!(out,get(row))
            end
        end
    end
    return out
end
