# Column-based operations: Some operations on rows are faster when considering columns

# In `map`, the output shouldn't alias inputs, so copies are made
Base.map(::typeof(identity), t::Union{FlexTable, Table}) = copy(t)

Base.map(::typeof(merge), t::Union{FlexTable, Table}) = copy(t)

function Base.map(::typeof(merge), t1::Table, t2::Table)
    return copy(Table(merge(columns(t1), columns(t2))))
end

function Base.map(::typeof(merge), df1::Union{Table, FlexTable}, df2::Union{Table, FlexTable})
    return copy(FlexTable(merge(columns(df1), columns(df2))))
end

function Base.map(::GetProperty{name}, t::Union{Table, FlexTable}) where {name}
    return copy(getproperty(t, name::Symbol))
end

# In `mapview`, the output should alias the inputs
function SplitApplyCombine.mapview(::typeof(merge), t1::Table, t2::Table)
    return Table(merge(columns(t1), columns(t2)))
end

function SplitApplyCombine.mapview(::typeof(merge), df1::Union{Table, FlexTable}, df2::Union{Table, FlexTable})
    return FlexTable(merge(columns(df1), columns(df2)))
end

@inline function SplitApplyCombine.mapview(f::GetProperty{name}, t::Union{Table, FlexTable}) where {name}
    return getproperty(t, name::Symbol)
end


# TODO support `broadcasted`, `materialize`, etc.

Base.broadcast(::typeof(identity), t::Union{Table, FlexTable}) = copy(t) # output shouldn't alias input

Base.broadcast(::typeof(merge), t::Union{Table, FlexTable}) = copy(t) # output shouldn't alias input


# TODO: fix this
#function Base.broadcast(::typeof(merge), t1::Table, t2::Table)
#	if axes(t1) == axes(t2)
#		map(merge, t1, t2)
#	else
#		...
#	end
#end
