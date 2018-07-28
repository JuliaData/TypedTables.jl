# Column-based operations: Some operations on rows are faster when considering columns

# In `map`, the output shouldn't alias inputs, so copies are made
Base.map(::typeof(identity), t::Table) = copy(t)

Base.map(::typeof(merge), t::Table) = copy(t)

function Base.map(::typeof(merge), t1::Table, t2::Table)
    return copy(Table(merge(columns(t1), columns(t2))))
end

function Base.map(::GetProperty{name}, t::Table) where {name}
    return copy(getproperty(t, name::Symbol))
end

# In `mapview`, the output should alias the inputs
function SplitApplyCombine.mapview(::typeof(merge), t1::Table, t2::Table)
    return Table(merge(columns(t1), columns(t2)))
end

@inline function SplitApplyCombine.mapview(f::GetProperty{name}, t::Table) where {name}
    return getproperty(t, name::Symbol)
end


# TODO support `broadcasted`, `materialize`, etc.

Base.broadcast(::typeof(identity), t::Table) = copy(t) # output shouldn't alias input

Base.broadcast(::typeof(merge), t::Table) = copy(t) # output shouldn't alias input


# TODO: fix this
#function Base.broadcast(::typeof(merge), t1::Table, t2::Table)
#	if axes(t1) == axes(t2)
#		map(merge, t1, t2)
#	else
#		...
#	end
#end
