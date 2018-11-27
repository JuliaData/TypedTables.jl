# Column-based operations: Some operations on rows are faster when considering columns

# In `map`, the output shouldn't alias inputs, so copies are made
Base.map(::typeof(identity), t::Table) = copy(t)

Base.map(::typeof(merge), t::Table) = copy(t)

function Base.map(::typeof(merge), t1::Table, t2::Table)
    return copy(Table(merge(columns(t1), columns(t2))))
end

function Base.map(f::GetProperty, t::Table)
    return copy(f(t))
end

@inline function Base.map(f::GetProperties, t::Table)
    return copy(f(t))
end

@inline function Base.map(f::Compute{names}, t::Table) where {names}
    # minimize number of columns before iterating over the rows
    map(f, GetProperties(names)(t))
end

@inline function Base.map(f::Compute{names}, t::Table{<:NamedTuple{names}}) where {names}
    # efficient to iterate over rows with a minimal number of columns
    if length(names) == 1 # unwrap in the simple cases
        return map(f.f, getproperty(names[1])(t))
    elseif length(names) == 2
        return map(f.f, getproperty(names[1])(t), getproperty(names[2])(t))
    end

    invoke(map, Tuple{Function, typeof(t)}, f, t)
end

@generated function Base.map(s::Select{names}, t::Table) where {names}
    exprs = [:($(names[i]) = map(s.fs[$i], t)) for i in 1:length(names)]

    return :(Table($(Expr(:tuple, exprs...))))
end

# In `mapview`, the output should alias the inputs
SplitApplyCombine.mapview(::typeof(merge), t::Table) = t

function SplitApplyCombine.mapview(::typeof(merge), t1::Table, t2::Table)
    return Table(merge(columns(t1), columns(t2)))
end

@inline function SplitApplyCombine.mapview(f::GetProperty, t::Table)
    return f(t)
end

@inline function SplitApplyCombine.mapview(f::GetProperties, t::Table)
    return f(t)
end

@inline function SplitApplyCombine.mapview(f::Compute{names}, t::Table) where {names}
    # minimize number of columns before iterating over the rows
    mapview(f, GetProperties(names)(t))
end

@inline function SplitApplyCombine.mapview(f::Compute{names}, t::Table{<:NamedTuple{names}}) where {names}
    # efficient to iterate over rows with a minimal number of columns
    if length(names) == 1 # unwrap in the simple cases (consider 2-argument version)
        return mapview(f.f, getproperty(names[1])(t))
    end

    invoke(mapview, Tuple{Function, typeof(t)}, f, t)
end

@generated function SplitApplyCombine.mapview(s::Select{names}, t::Table) where {names}
    exprs = [:($(names[i]) = mapview(s.fs[$i], t)) for i in 1:length(names)]

    return :(Table($(Expr(:tuple, exprs...))))
end

# broadcast

@inline function Broadcast.broadcasted(::Broadcast.DefaultArrayStyle{N}, ::typeof(merge), ts::Table{<:Any, N}...) where {N}
	Table(merge(map(columns, ts)...))
end

@inline function Broadcast.broadcasted(::Broadcast.DefaultArrayStyle{N}, f::GetProperty, t::Table{<:Any, N}) where {N}
	return f(t)
end

@inline function Broadcast.broadcasted(::Broadcast.DefaultArrayStyle{N}, f::GetProperties, t::Table{<:Any, N}) where {N}
    return f(t)
end

@inline function Broadcast.broadcasted(style::Broadcast.DefaultArrayStyle{N}, f::Compute{names}, t::Table{<:NamedTuple, N}) where {N, names}
    # minimize number of columns before iterating over the rows
    return Broadcast.broadcasted(style, f, GetProperties(names)(t))
end

@inline function Broadcast.broadcasted(style::Broadcast.DefaultArrayStyle{N}, f::Compute{names}, t::Table{<:NamedTuple{names}, N}) where {N, names}
    # efficient to iterate over rows with a minimal number of columns
    if length(names) == 1 # unwrap in the simple cases
        return Broadcast.broadcasted(f.f, getproperty(names[1])(t))
    elseif length(names) == 2
        return Broadcast.broadcasted(f.f, getproperty(names[1])(t), getproperty(names[2])(t))
    end

    invoke(Broadcast.broadcasted, Tuple{typeof(style), Function, typeof(t)}, style, f, t)
end

@inline function Broadcast.broadcasted(::Broadcast.DefaultArrayStyle{N}, f::Select, t::Table{<:Any, N}) where {N}
    return mapview(f, t)
end

# I'm not 100% sure how wise this pattern is...
Broadcast.materialize(t::Table) = Table(map(_materialize, columns(t)))
_materialize(x) = Broadcast.materialize(x)
_materialize(x::MappedArray) = copy(x)

# mapreduce

function Base.mapreduce(f::GetProperty, op, t::Table; kwargs...)
    return mapreduce(identity, op, f(t); kwargs...)
end

function Base.mapreduce(f::GetProperties, op, t::Table; kwargs...)
    return mapreduce(identity, op, f(t); kwargs...)
end

function Base.mapreduce(f::Compute{names}, op, t::Table; kwargs...) where {names}
    # minimize number of columns before iterating over the rows
    t2 = GetProperties(names)(t)
    return mapreduce(f, op, t2; kwargs...)
end

function Base.mapreduce(f::Compute{names}, op, t::Table{<:NamedTuple{names}}; kwargs...) where {names}
    # efficient to iterate over rows with a minimal number of columns
    if length(names) == 1 # unwrap in the simple cases
        return mapreduce(f.f, op, getproperty(names[1])(t))
    elseif length(names) == 2
        return mapreduce(f.f, op, getproperty(names[1])(t), getproperty(names[2])(t))
    end
    
    invoke(mapreduce, Tuple{Function, typeof(op), typeof(t)}, f, op, t; kwargs...)
end

# `filter(f, t)` defaults to `t[map(f, t)]`

function Base.filter(f::GetProperty, t::Table)
    return @inbounds t[f(t)::AbstractArray{Bool}]
end

# findall

function Base.findall(f::GetProperty, t::Table)
    return findall(identity, f(t))
end

function Base.findall(f::Compute{names}, t::Table) where {names}
    # minimize number of columns before iterating over the rows
    return findall(f, GetProperties(names)(t))
end

function Base.findall(f::Compute{names}, t::Table{<:NamedTuple{names}}) where {names}
    # efficient to iterate over rows with a minimal number of columns
    if length(names) == 1 # unwrap in the simple cases
        return findall(f.f, getproperty(names[1])(t))
    end

    invoke(findall, Tuple{Function, typeof(t)}, f, t)
end
