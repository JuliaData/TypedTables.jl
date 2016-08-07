
# First lets define a fast natural inner join, before worrying about other kinds
# of joins.

# Our initial implementation will use a simple hashing algorithm
@generated function Base.join{Names1, Names2}(t1::Table{Names1}, t2::Table{Names2})
    int_names = (intersect(Names1, Names2)...)
    int_indices = collect(columnindex(Names1, int_names))
    int_types = Expr(:curly, :Tuple, eltypes(t1).parameters[int_indices]...)

    quote
        # Make a hashmap of the overlapping part of t1, indicating the relevant
        # rows`
        hashmap = Dict{Row{$int_names, $int_types}, Vector{Int}}()
        for i1 = 1:nrow(t1)
            @inbounds int_row = t1[i1, Val{$int_names}]
            #=
            if haskey(hashmap, int_row) # Can we avoid querying twice? Yes
                push!(hashmap[int_row], i1)
            else
                hashmap[int_row] = [i1]
            end
            =#
            push!(get!(hashmap, int_row, Vector{Int}(0)), i1)
        end

        # Make an empty output table
        out = jointype(t1, t2)()

        # Now see if t2 overlaps with the hashmap and push onto the solution as
        # appropriate
        for i2 = 1:nrow(t2)
            @inbounds int_row = t2[i2, Val{$int_names}]
            if haskey(hashmap, int_row)
                for i1 in hashmap[int_row]
                    # Combine matching rows and push onto output table
                    push!(out, joinrow(t1[i1], t2[i2]))
                end
            end
        end
        return out
    end
end

@generated function jointype{Names1,Types1,Names2,Types2}(t1::Table{Names1,Types1}, t2::Table{Names2,Types2})
    names_ab = (intersect(Names1, Names2)...)
    indices_ab = collect(columnindex(Names1, names_ab))
    types_ab = storagetypes(t1).parameters[indices_ab]

    names_a = (setdiff(Names1, Names2)...)
    indices_a = collect(columnindex(Names1, names_a))
    types_a = storagetypes(t1).parameters[indices_a]

    names_b = (setdiff(Names2, Names1)...)
    indices_b = collect(columnindex(Names2, names_b))
    types_b = storagetypes(t2).parameters[indices_b]

    new_names = (names_ab..., names_a..., names_b...)
    new_types = Expr(:curly, :Tuple, types_ab..., types_a..., types_b...)

    return :(Table{$new_names, $new_types})
end


@generated function joinrow{Names1,Types1,Names2,Types2}(r1::Row{Names1,Types1}, r2::Row{Names2,Types2})
    names_ab = (intersect(Names1, Names2)...)
    indices_ab = collect(columnindex(Names1, names_ab))
    types_ab = eltypes(r1).parameters[indices_ab]

    names_a = (setdiff(Names1, Names2)...)
    indices_a = collect(columnindex(Names1, names_a))
    types_a = eltypes(r1).parameters[indices_a]

    names_b = (setdiff(Names2, Names1)...)
    indices_b = collect(columnindex(Names2, names_b))
    types_b = eltypes(r2).parameters[indices_b]

    new_names = (names_ab..., names_a..., names_b...)
    new_types = Expr(:curly, :Tuple, types_ab..., types_a..., types_b...)

    exprs = vcat([:(r1.data[$(indices_ab[j])]) for j = 1:length(indices_ab)],
                 [:(r1.data[$(indices_a[j])]) for j = 1:length(indices_a)],
                 [:(r2.data[$(indices_b[j])]) for j = 1:length(indices_b)])

    return Expr(:call, :(Row{$new_names, $new_types}), Expr(:tuple, exprs...))
end




#=
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

  `join{Names}(a::Row{Names},b::Row{Names}, jointype)`

for joining (the overlapping potion of Rows) with more complex behaviour.
"""
Base.join{Names}(a::Row{Names}, b::Row{Names}, jointype::AbstractJoin = InnerJoin()) = join(a, b, jointype, isdispatchable(jointype))


@generated function Base.join{Names, Types}(a::Row{Names, Types}, b::Row{Names}, jointype::AbstractJoin = InnerJoin(), ::DispatchableJoin = DispatchableJoin())
    expr1 = Vector{Expr}(length(Names))
    for i = 1:length(Names)
        expr1[i] = :(if !testjoin(a.data[$i], b.data[$i], jointype); return Nullable{Row{Names,Types}}(); end)
    end
    expr1 = Expr(:block, expr1...)

    expr2 = Vector{Expr}(length(Names))
    for i = 1:length(Names)
        expr2[i] = :( dojoin(a.data[$i], b.data[$i], jointype) )
    end
    expr2 = Expr(:tuple, expr2...)
    :($expr1; Nullable{Row{Names,Types}}(Row{Names,Types}($expr2)) )
end


@generated function Base.join(a::Row, b::Row, jointype::AbstractJoin = InnerJoin())
    idx_a = (setdiff(names(a), names(b))...)
    idx_ab = (intersect(names(a), names(b))...)
    idx_b = (setdiff(names(b), names(a))...)
    idx_out = (idx_ab..., idx_a..., idx_b...)

    t_a  = eltypes(a).parameters[columnindex(names(a), idx_a)]
    t_ab = eltypes(a).parameters[columnindex(names(a), idx_ab)]
    t_b  = eltypes(b).parameters[columnindex(names(b), idx_b)]

    types = Expr(:curly, :Tuple, t_ab..., t_a..., t_b...)

    quote
        tmp = join(a[Val{$idx_ab}], b[Val{$idx_ab}], jointype)
        if isnull(tmp)
            return Nullable{Row{$idx_out, types}}()
        else
            return Nullable{Row{$idx_out, types}}(hcat(get(tmp), a[Val{$idx_a}], b[Val{$idx_b}]))
        end
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
@generated function Base.join(a::Table, b::Table, jointype::AbstractJoin = InnerJoin())
    NewNames = ...
    NewTypes = ...
    quote
        out = Table{$NewNames, $NewTypes}()
        for i = 1:length(a)
            for j = 1:length(b)
                row = join(a[i], b[j], jointype)
                if !isnull(row)
                    push!(out, get(row))
                end
            end
        end
        return out
    end
end
=#
