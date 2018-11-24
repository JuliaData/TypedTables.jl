# Column-based operations: Some operations on rows are faster when considering columns

# In `map`, the output shouldn't alias inputs, so copies are made
Base.map(::typeof(identity), t::Union{FlexTable, Table}) = copy(t)

Base.map(::typeof(merge), t::Union{FlexTable, Table}) = copy(t)

function Base.map(::typeof(merge), t1::Table, t2::Table)
    return copy(Table(merge(columns(t1), columns(t2))))
end

function Base.map(::typeof(merge), df1::Union{Table{<:Any, N}, FlexTable{N}}, df2::Union{Table{<:Any, N}, FlexTable{N}}) where {N}
    return copy(FlexTable{N}(merge(columns(df1), columns(df2))))
end

function Base.map(::GetProperty{name}, t::Union{Table{<:Any, N}, FlexTable{N}}) where {name, N}
    return copy(getproperty(t, name::Symbol))::AbstractArray{<:Any, N}
end

@inline function Base.map(f::GetProperties{names}, t::Union{Table{<:Any, N}, FlexTable{N}}) where {names,  N}
    return copy(f(t))
end

# In `mapview`, the output should alias the inputs
function SplitApplyCombine.mapview(::typeof(merge), t1::Table, t2::Table)
    return Table(merge(columns(t1), columns(t2)))
end

function SplitApplyCombine.mapview(::typeof(merge), df1::Union{Table{<:Any, N}, FlexTable{N}}, df2::Union{Table{<:Any, N}, FlexTable{N}}) where {N}
    return FlexTable{N}(merge(columns(df1), columns(df2)))
end

@inline function SplitApplyCombine.mapview(f::GetProperty{name}, t::Union{Table{<:Any, N}, FlexTable{N}}) where {name,  N}
    return getproperty(t, name::Symbol)::AbstractArray{<:Any, N}
end

@inline function SplitApplyCombine.mapview(f::GetProperties{names}, t::Union{Table{<:Any, N}, FlexTable{N}}) where {names,  N}
    return f(t)
end

# broadcast

@inline function Broadcast.broadcasted(::Broadcast.DefaultArrayStyle{N}, ::typeof(merge), ts::Table{<:Any, N}...) where {N}
	Table(merge(map(columns, ts)...))
end

@inline function Broadcast.broadcasted(::Broadcast.DefaultArrayStyle{N}, ::typeof(merge), ts::Union{Table{<:Any, N},FlexTable{N}}...) where {N}
	FlexTable{N}(merge(map(columns, ts)...))
end

@inline function Broadcast.broadcasted(::Broadcast.DefaultArrayStyle{N}, f::GetProperty{name}, t::Table{<:Any, N}) where {N, name}
	return getproperty(t, name::Symbol)
end

@inline function Broadcast.broadcasted(::Broadcast.DefaultArrayStyle{N}, f::GetProperty{name}, t::FlexTable{N}) where {N, name}
	return getproperty(t, name::Symbol)::AbstractArray{<:Any, N}
end

@inline function Broadcast.broadcasted(::Broadcast.DefaultArrayStyle{N}, f::GetProperties{names}, t::Table{<:Any, N}) where {N, names}
    return f(t)
end

@inline function Broadcast.broadcasted(::Broadcast.DefaultArrayStyle{N}, f::GetProperties{names}, t::FlexTable{N}) where {N, names}
    return f(t)
end
