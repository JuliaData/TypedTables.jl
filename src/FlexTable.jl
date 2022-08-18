# A `Table` presents itself as an `AbstractArray` of `NamedTuples`s

"""
    FlexTable(name1 = array1, ...)

Create a column-storage-based `FlexTable` with column names `name1`, etc, from arrays `array1`,
etc. The input arrays `array1`, etc, must share the same dimensionality and indices.

`FlexTable` itself is an `AbstractArray` whose elements are `NamedTuple`s of the form
`(name1 = first(array1), ...)`, etc. Rows of the table are obtained via standard array
indexing `table[i]`, and columns via `table.name`.

`FlexTable` differs from `Table` in that the columns are mutable - you may add, remove,
rename and replace entire columns of a `FlexTable`, but not a `Table`. However, `Table` can
access and iterate rows in local scope with fast, fully type-inferred code while `FlexTable`
will be more efficient with a higher-order interface.
"""
mutable struct FlexTable{N} <: AbstractArray{NamedTuple, N}
    data::NamedTuple{<:Any, <:Tuple{Vararg{AbstractArray{<:Any, N}}}}

    # Inner constructor, to compare axes?
    function FlexTable{N}(d::NamedTuple{<:Any, <:Tuple{Vararg{AbstractArray{<:Any, N}}}}) where N
        new(d)
    end
end

FlexTable(ts...; kwargs...) = _flextable(removenothings(merge(_columns(ts...), kwargs.data)))
FlexTable{N}(ts...; kwargs...) where {N} = _flextable(removenothings(merge(_columns(ts...), kwargs.data)))::FlexTable{N}

_flextable(nt::NamedTuple) = FlexTable{_ndims(nt)}(nt)

FlexTable(t::Table) = FlexTable(columns(t))
Table(t::FlexTable) = Table(columns(t))

_columns(t::FlexTable) = columns(t)

Tables.istable(::Type{<:FlexTable}) = true
Tables.rowaccess(::Type{<:FlexTable}) = true
Tables.columnaccess(::Type{<:FlexTable}) = true
Tables.schema(t::FlexTable) = Tables.Schema(_eltypes(columns(t)))
Tables.materializer(::FlexTable) = FlexTable

"""
    columns(dataframe::FlexTable)

Convert a `FlexTable` into a `NamedTuple` of its columns.
"""
@inline Tables.columns(t::FlexTable) = getfield(t, :data)

@inline Tables.rows(t::FlexTable) = Table(columns(t))

# Simple column access via `table.columnname`
@inline Base.getproperty(t::FlexTable, name::Symbol) = getproperty(columns(t), name)

function Base.setproperty!(t::FlexTable, name::Symbol, a)
    setfield!(t, :data, merge(columns(t), NamedTuple{(name,)}((convert(AbstractArray, deepcopy(a)),))))
    return t
end

function Base.setproperty!(t::FlexTable, name::Symbol, ::Nothing)
    setfield!(t, :data, removenothings(merge(columns(t), NamedTuple{(name,)}((nothing,)))))
    return t
end

propertytype(::FlexTable{N}) where {N} = FlexTable{N}

"""
    columnnames(table)

Return a tuple of the column names of a `Table`.
"""
columnnames(t::FlexTable) = keys(columns(t))

# show
Base.show(io::IO, ::MIME"text/plain", t::FlexTable) = showtable(io, t)
#Base.show(io::IO, t::FlexTable) = showtable(io, t)

# Basic AbstractArray interface

@inline Base.size(t::FlexTable{N}) where {N} = size(first(columns(t)))::NTuple{N, Integer}
@inline Base.axes(t::FlexTable{N}) where {N} = axes(first(columns(t)))::NTuple{N, Any}
@inline Base.IndexStyle(t::FlexTable) = IndexStyle(first(columns(t)))

function Base.checkbounds(::Type{Bool}, t::FlexTable, i...)
    # Make sure we are in bounds for *every* column. Only safe to do
    # here because each column might mutate size independently of the others!
    all(col -> checkbounds(Bool, col, i...), columns(t))
end

@inline function Base.getindex(t::FlexTable, i::Int)
    @boundscheck checkbounds(t, i)
    map(col -> @inbounds(getindex(col, i)), columns(t))::NamedTuple
end

@inline function Base.getindex(t::FlexTable, i::Int...)
    @boundscheck checkbounds(t, i...)
    map(col -> @inbounds(getindex(col, i...)), columns(t))::NamedTuple
end

@inline function Base.setindex!(t::FlexTable, v::NamedTuple, i::Int)
    @boundscheck begin
        checkbounds(t, i)
        @assert keys(v) === keys(columns(t))
    end
    map((val, col) -> @inbounds(setindex!(col, val, i)), v, columns(t))
    return t
end

@inline function Base.setindex!(t::FlexTable, v::NamedTuple, i::Int...)
    @boundscheck begin
        checkbounds(t, i)
        @assert keys(v) === keys(columns(t))
    end
    map((val, col) -> @inbounds(setindex!(col, val, i...)), v, columns(t))
    return t
end

# similar
@inline Base.similar(t::FlexTable{N}) where {N} = FlexTable{N}(similar(Table(t)))::FlexTable{N}
@inline Base.similar(t::FlexTable{N}, ::Type{NamedTuple}) where {N} = FlexTable{N}(similar(Table(t)))
@inline Base.similar(t::FlexTable{N}, ::Type{NamedTuple{names,T}}) where {N, names, T} = FlexTable{N}(similar(Table(t, NamedTuple{names, T})))
@inline Base.similar(t::FlexTable, ::Type{NamedTuple}, dims) = FlexTable{__ndims(dims)}(similar(Table(t), _eltypes(columns(t)), dims))
@inline Base.similar(t::FlexTable, ::Type{NamedTuple{names,T}}, dims) where {names, T} = FlexTable{__ndims(dims)}(similar(Table(t), NamedTuple{names, T}, dims))

# Ambiguities...
@inline Base.similar(t::FlexTable, ::Type{NamedTuple}, dims::Union{Integer, AbstractUnitRange}...) = FlexTable{__ndims(dims)}(similar(Table(t), _eltypes(columns(t)), dims))
@inline Base.similar(t::FlexTable, ::Type{NamedTuple}, dims::Tuple{Vararg{Int, N}}) where {N} = FlexTable{__ndims(dims)}(similar(Table(t), _eltypes(columns(t)), dims))
@inline Base.similar(t::FlexTable, ::Type{NamedTuple}, dims::Tuple{Union{Integer, OneTo},Vararg{Union{Integer, OneTo}}}) = FlexTable{__ndims(dims)}(similar(Table(t), _eltypes(columns(t)), dims))

@inline Base.similar(t::FlexTable, ::Type{NamedTuple{names, T}}, dims::Union{Integer, AbstractUnitRange}...) where {names, T} = FlexTable{__ndims(dims)}(similar(Table(t), NamedTuple{names, T}, dims))
@inline Base.similar(t::FlexTable, ::Type{NamedTuple{names, T}}, dims::Tuple{Vararg{Int, N}}) where {N, names, T} = FlexTable{__ndims(dims)}(similar(Table(t), NamedTuple{names, T}, dims))
@inline Base.similar(t::FlexTable, ::Type{NamedTuple{names, T}}, dims::Tuple{Union{Integer, OneTo},Vararg{Union{Integer, OneTo}}}) where {names, T} = FlexTable{__ndims(dims)}(similar(Table(t), NamedTuple{names, T}, dims))

@inline __ndims(::Integer) = 1
@inline __ndims(::AbstractUnitRange) = 1
@inline __ndims(::NTuple{N, Any}) where {N} = N

# empty
Base.empty(t::FlexTable) = empty(t, _eltypes(columns(t)))
function Base.empty(t::FlexTable, ::Type{NamedTuple{names, T}}) where {names, T <: Tuple}
    FlexTable(empty(Table(t), NamedTuple{names, T}))
end

Base.emptymutable(t::FlexTable) = Base.emptymutable(t, _eltypes(columns(t)))
function Base.Base.emptymutable(t::FlexTable, ::Type{NamedTuple{names, T}}) where {names, T <: Tuple}
    FlexTable(Base.emptymutable(Table(t), NamedTuple{names, T}))
end

# Support Vector / deque interface (mutable-length vectors)

function Base.empty!(t::FlexTable)
    map(empty!, columns(t))
    return t
end

function Base.pop!(t::FlexTable)
    return map(pop!, columns(t))::NamedTuple
end

function Base.push!(t::FlexTable, v::NamedTuple)
    map(push!, columns(t), v)
    return t
end

function Base.append!(t::Union{FlexTable, Table}, t2::Union{FlexTable, Table})
    map(append!, columns(t), columns(t2))
    return t
end

function Base.popfirst!(t::FlexTable)
    return map(popfirst!, columns(t))::NamedTuple
end

function Base.pushfirst!(t::FlexTable, v::NamedTuple)
    map(pushfirst!, columns(t), v)
    return t
end

function Base.prepend!(t::Union{FlexTable, Table}, t2::Union{FlexTable, Table})
    map(prepend!, columns(t), columns(t2))
    return t
end

function Base.deleteat!(t::FlexTable, i)
    map(col -> deleteat!(col, i), columns(t))
    return t
end

function Base.insert!(t::FlexTable, i::Integer, v::NamedTuple)
    map((col, val) -> insert!(col, i, val), columns(t), v)
    return t
end

function Base.splice!(t::FlexTable, inds::Integer)
    return map(col -> splice!(col, inds), columns(t))::NamedTuple
end

function Base.splice!(t::FlexTable, inds::AbstractVector)
    return FlexTable{1}(map(col -> splice!(col, inds), columns(t)))
end

function Base.splice!(t::FlexTable, inds::Integer, ins::NamedTuple)
    return map((col, vals) -> splice!(col, inds, vals), columns(t), ins)::NamedTuple
end

function Base.splice!(t::FlexTable, inds::AbstractVector, ins::NamedTuple)
    return FlexTable{1}(map((col, vals) -> splice!(col, inds, vals), columns(t), ins))
end

function Base.splice!(t::FlexTable, inds::Integer, ins::AbstractVector{<:NamedTuple})
    return map((col, vals) -> splice!(col, inds, vals), columns(t), columns(ins))::NamedTuple
end

function Base.splice!(t::FlexTable, inds::AbstractVector, ins::AbstractVector{<:NamedTuple})
    return FlexTable{1}(map((col, vals) -> splice!(col, inds, vals), columns(t), columns(ins)))
end

# TODO splicing in an `AbstractArray{<:NamedTuple}` should be possible...

function Base.resize!(t::FlexTable, i::Integer)
    foreach(col -> resize!(col, i), columns(t))
    return t
end

# Speedups for column-based storage

function Base.getindex(t::FlexTable, inds::Union{AbstractArray, Colon}...)
    return FlexTable{_getindex_dims(inds)}(map(col -> getindex(col, inds...), columns(t)))
end

function Base.view(t::FlexTable, inds::Union{AbstractArray, Colon}...)
    return FlexTable{_getindex_dims(inds)}(map(col -> view(col, inds...), columns(t)))
end

@inline _getindex_dims(inds) = __getindex_dims(0, inds...)
@inline __getindex_dims(n::Int) = n
@inline __getindex_dims(n::Int, ::Int, inds...) = __getindex_dims(n, inds...)
@inline __getindex_dims(n::Int, ::AbstractArray{<:Any, m}, inds...) where {m} = __getindex_dims(n + m, inds...)
@inline __getindex_dims(n::Int, ::Colon, inds...) = __getindex_dims(n + 1, inds...)

# Deprecated for .= syntax (via Base.Broadcast.materialize!)
# It seems `Ref` might be the new cool here. Could also consider `AbstractArray{<:NamedTuple, 0}`?
#function Base.setindex!(t::Table{<:NamedTuple{names}}, v::NamedTuple{names}, inds::Union{AbstractArray, Colon}...) where {names}
#    map((col, val) -> setindex!(col, val, inds...), columns(t), v)
#    return t
#end

function Base.setindex!(t::FlexTable, t2::Union{FlexTable, Table}, inds::Union{AbstractArray, Colon}...)
    map((col, col2) -> setindex!(col, col2, inds...), columns(t), columns(t2))
    return t
end

# Private fields are never exposed since they can conflict with column names
Base.propertynames(t::FlexTable, private::Bool=false) = columnnames(t)


@inline function Base.vcat(ts::Union{FlexTable, Table}...)
    return FlexTable{_vcat_ndims(map(ndims, ts)...)}(map(vcat, map(columns, ts)...))
end

@inline function Base.hcat(ts::Union{FlexTable, Table}...)
    return FlexTable{_hcat_ndims(map(ndims, ts)...)}(map(hcat, map(columns, ts)...))
end

function Base.hvcat(rows::Tuple{Vararg{Int}}, ts::Union{FlexTable, Table}...)
    return FlexTable(map((cols...,) -> hvcat(rows, cols...), map(columns, ts)...))
end

@pure function _vcat_ndims(i::Int...)
    max(1, i...)
end

@pure function _hcat_ndims(i::Int...)
    max(2, i...)
end

function Base.vec(t::FlexTable)
    return FlexTable{1}(map(vec, columns(t)))
end

# "Bulk" operations on FlexTables should generally first unrwap to Tables
_flex(t::Table{<:Any, N}) where {N} = FlexTable(columns(t))
_flex(t) = t

Broadcast.broadcastable(t::FlexTable) = Table(t)

Base.map(f, t::FlexTable{N}) where {N} = _flex(map(f, rows(t)))::AbstractArray{<:Any, N}
Base.map(f, t::FlexTable{N}, t2) where {N} = _flex(map(f, rows(t), t2))::AbstractArray{<:Any, N}
Base.map(f, t, t2::FlexTable{N}) where {N} = _flex(map(f, t, rows(t2)))::AbstractArray{<:Any, N}
Base.map(f, t::FlexTable{N}, t2::FlexTable{N}) where {N} = _flex(map(f, rows(t), rows(t2)))::AbstractArray{<:Any, N}

Base.mapreduce(f, op, t::FlexTable; kwargs...) = mapreduce(f, op, rows(t); kwargs...)

Base.filter(f, t::FlexTable{N}) where {N} = FlexTable(filter(f, rows(t)))::FlexTable{N}

# SplitApplyCombine.mapview(f::Union{Function, Type}, t::FlexTable{N}) where {N} = _flex(mapview(f, rows(t)))::AbstractArray{<:Any, N}
# SplitApplyCombine.mapview(f::Union{Function, Type}, t::FlexTable{N}, t2) where {N} = _flex(mapview(f, rows(t), t2))::AbstractArray{<:Any, N}
# SplitApplyCombine.mapview(f::Union{Function, Type}, t, t2::FlexTable{N}) where {N} = _flex(mapview(f, t, rows(t2)))::AbstractArray{<:Any, N}
# SplitApplyCombine.mapview(f::Union{Function, Type}, t::FlexTable{N}, t2::FlexTable{N}) where {N} = _flex(mapview(f, rows(t), rows(t2)))::AbstractArray{<:Any, N}

SplitApplyCombine.mapview(f, t::FlexTable{N}) where {N} = _flex(mapview(f, rows(t)))::AbstractArray{<:Any, N}
SplitApplyCombine.mapview(f::Base.Callable, t::FlexTable{N}) where {N} = _flex(mapview(f, rows(t)))::AbstractArray{<:Any, N}
SplitApplyCombine.mapview(f, t::FlexTable{N}, t2) where {N} = _flex(mapview(f, rows(t), t2))::AbstractArray{<:Any, N}
SplitApplyCombine.mapview(f, t, t2::FlexTable{N}) where {N} = _flex(mapview(f, t, rows(t2)))::AbstractArray{<:Any, N}
SplitApplyCombine.mapview(f, t::FlexTable{N}, t2::FlexTable{N}) where {N} = _flex(mapview(f, rows(t), rows(t2)))::AbstractArray{<:Any, N}

SplitApplyCombine.group(by, f, t::FlexTable) = group(by, f, rows(t))
SplitApplyCombine.groupview(by, f, t::FlexTable) = groupview(by, f, rows(t))
SplitApplyCombine.groupinds(by, t::FlexTable) = groupinds(by, rows(t))
SplitApplyCombine.groupreduce(by, f, op, t::FlexTable; kwargs...) = groupreduce(by, f, op, rows(t); kwargs...)

SplitApplyCombine.innerjoin(lkey::Base.Callable, rkey::Base.Callable, f::Base.Callable, cmp::Base.Callable, t1::FlexTable, t2) = _flex(innerjoin(lkey, rkey, f, cmp, rows(t1), t2))
SplitApplyCombine.innerjoin(lkey::Base.Callable, rkey::Base.Callable, f::Base.Callable, cmp::Base.Callable, t1, t2::FlexTable) = _flex(innerjoin(lkey, rkey, f, cmp, t1, rows(t2)))
SplitApplyCombine.innerjoin(lkey::Base.Callable, rkey::Base.Callable, f::Base.Callable, cmp::Base.Callable, t1::FlexTable, t2::FlexTable) = _flex(innerjoin(lkey, rkey, f, cmp, rows(t1), rows(t2)))

Base.:(==)(t1::FlexTable{N}, t2::AbstractArray{<:Any,N}) where {N} = (rows(t1) == t2)
Base.:(==)(t1::AbstractArray{<:Any,N}, t2::FlexTable{N}) where {N} = (t1 == rows(t2))
Base.:(==)(t1::FlexTable{N}, t2::FlexTable{N}) where {N} = (rows(t1) == rows(t2))

Base.isequal(t1::FlexTable{N}, t2::AbstractArray{<:Any,N}) where {N} = isequal(rows(t1), t2)
Base.isequal(t1::AbstractArray{<:Any,N}, t2::FlexTable{N}) where {N} = isequal(t1, rows(t2))
Base.isequal(t1::FlexTable{N}, t2::FlexTable{N}) where {N} = isequal(rows(t1), rows(t2))

Base.isless(t1::FlexTable{1}, t2::AbstractVector) = isless(rows(t1), t2)
Base.isless(t1::AbstractVector, t2::FlexTable{1}) = isless(t1, rows(t2))
Base.isless(t1::FlexTable{1}, t2::FlexTable{1}) = isless(rows(t1), rows(t2))

Base.hash(t::FlexTable, h::UInt) = hash(rows(t), h)


Adapt.adapt_structure(to, t::FlexTable{N}) where N = FlexTable{N}(; Adapt.adapt(to, getfield(t, :data))...)
