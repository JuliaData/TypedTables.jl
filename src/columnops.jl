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

@inline function Base.map(f::Calc{names}, t::Table) where {names}
    map(f, GetProperties(names)(t))
end

@inline function Base.map(f::Calc{names}, t::Table{<:NamedTuple{names}}) where {names}
    invoke(map, Tuple{Function, typeof(t)}, f, t)
end

@generated function Base.map(s::Select{names}, t::Table) where {names}
    exprs = [:($(names[i]) = map(s.calcs[$i], t)) for i in 1:length(names)]

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

@inline function SplitApplyCombine.mapview(f::Calc{names}, t::Table) where {names}
    mapview(f, GetProperties(names)(t))
end

@inline function SplitApplyCombine.mapview(f::Calc{names}, t::Table{<:NamedTuple{names}}) where {names}
    invoke(mapview, Tuple{Function, typeof(t)}, f, t)
end

@generated function SplitApplyCombine.mapview(s::Select{names}, t::Table) where {names}
    exprs = [:($(names[i]) = mapview(s.calcs[$i], t)) for i in 1:length(names)]

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

@inline function Broadcast.broadcasted(::Broadcast.DefaultArrayStyle{N}, f::Calc, t::Table{<:Any, N}) where {N}
    return Broadcast.Broadcasted{Broadcast.DefaultArrayStyle{N}}(f, (t,), axes(t))
end

@inline function Broadcast.broadcasted(::Broadcast.DefaultArrayStyle{N}, f::Select, t::Table{<:Any, N}) where {N}
    return mapview(f, t)
end

# I'm not 100% sure how wise this pattern is...
Broadcast.materialize(t::Table) = Table(map(_materialize, columns(t)))
_materialize(x) = Broadcast.materialize(x)
_materialize(x::MappedArray) = copy(x)

# TODO filter

# TODO mapreduce
