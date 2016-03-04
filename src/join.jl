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
join, and return true or false. By default, uses jointype InnerJoin(), but
also other popular joins are implemented, including LeftJoin(), RightJoin() and
OuterJoin().

Users may define their own jointype as a subtype of AbstractJoin as well as the
corresponding testjoin() and dojoin() functions to implement
join(table1, table2, jointype).
"""
testjoin(a, b, jointype::InnerJoin = InnerJoin()) = a == b

"""
  testjoin(a, b, [jointype])

Given two pieces of raw data that are previously tested as being joinable, and
return the correct data. By default, uses jointype InnerJoin(), but
also other popular joins are implemented, including LeftJoin(), RightJoin() and
OuterJoin().

Users may define their own jointype as a subtype of AbstractJoin as well as the
corresponding testjoin() and dojoin() functions to implement
join(table1, table2, jointype).
"""
dojoin(a, b, jointype::InnerJoin = InnerJoin()) = a


"""
  join(a::Row, b::Row, [jointype])

Determine if two rows data are considered equal for the purpose of a
join, and returns a nullable of the joined rows. By default, this will be
performed individually on

Users may define their own jointype as a Julia type/immutable and the
corresponding joins() function to implement join(table1, table2, jointype).
"""
Base.join{Index}(a::Row{Index}, b::Row{Index}, jointype::AbstractJoin = InnerJoin()) = join(a, b, jointype, isdispatchable(jointype))


@generated function Base.join{Index}(a::Row{Index}, b::Row{Index}, jointype::AbstractJoin = InnerJoin(), ::DispatchableJoin = DispatchableJoin())
    expr1 = Vector{Expr}(length(Index))
    for i = 1:length(Index)
        expr1[i] = quote
            if testjoin(a.data[$(Index(i))], b.data[$(Index(i))], jointype); return Nullable{Row{Index}}(); end
        end
    end

    expr2 = Vector{Expr}(length(Index))
    for i = 1:length(Index)
        expr2[i] = :( dojoin(testjoin(a.data[$(Index(i))], b.data[$(Index(i))], jointype)) )
    end

    :($Expr1...; Nullable{Row{Index}}(Nullable{Row{Index}}(($Expr2...))) )
end
