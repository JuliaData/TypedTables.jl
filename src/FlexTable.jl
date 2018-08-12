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
end

FlexTable(;kwargs...) = FlexTable(kwargs.data)
FlexTable(nt::NamedTuple) = FlexTable{_ndims(nt)}(nt)

function FlexTable(x)
    cols = columns(x)
    if cols isa NamedTuple{<:Any, <:Tuple{Vararg{AbstractArray{N}} where N}}
        return FlexTable(cols)
    else
        return FlexTable(columntable(cols))
    end
end
FlexTable(t::Table) = FlexTable(columns(t))
Table(df::FlexTable) = Table(columns(df))

FlexTable{N}(t::Table{<:Any, N}) where {N} = FlexTable{N}(columns(t))

Tables.AccessStyle(::FlexTable) = Tables.ColumnAccess()
Tables.schema(df::FlexTable) = _eltypes(columns(df))

"""
    columns(dataframe::FlexTable)

Convert a `FlexTable` into a `NamedTuple` of it's columns.
"""
@inline columns(df::FlexTable) = Core.getfield(df, :data)

@inline rows(df::FlexTable) = Table(columns(df))

# Simple column access via `table.columnname`
@inline Base.getproperty(df::FlexTable, name::Symbol) = getproperty(columns(t), name)

"""
    columnnames(table)

Return a tuple of the column names of a `Table`.
"""
columnnames(df::FlexTable) = keys(columns(df))


# Basic AbstractArray interface

@inline Base.size(df::FlexTable{N}) where {N} = size(first(columns(df)))::NTuple{N, Integer}
@inline Base.axes(df::FlexTable{N}) where {N} = axes(first(columns(df)))::NTuple{N, Any}
@inline Base.IndexStyle(df::FlexTable) = IndexStyle(first(columns(df)))

function Base.checkbounds(::Type{Bool}, df::FlexTable, i...)
    # Make sure we are in bounds for *every* column. Only safe to do
    # here because each column might mutate size independently of the others!
    all(col -> checkbounds(Bool, col, i...), columns(df))
end

@inline function Base.getindex(df::FlexTable, i::Int)
    @boundscheck checkbounds(df, i)
    map(col -> @inbounds(getindex(col, i)), columns(df))::NamedTuple
end

@inline function Base.getindex(df::FlexTable, i::Int...)
    @boundscheck checkbounds(df, i...)
    map(col -> @inbounds(getindex(col, i...)), columns(df))::NamedTuple
end

@inline function Base.setindex!(df::FlexTable, v::NamedTuple, i::Int)
    @boundscheck begin
        checkbounds(df, i)
        @assert keys(v) === keys(columns(df))
    end
    map((val, col) -> @inbounds(setindex!(col, val, i)), v, columns(df))
    return df
end

@inline function Base.setindex!(df::FlexTable, v::NamedTuple, i::Int...)
    @boundscheck begin
        checkbounds(df, i)
        @assert keys(v) === keys(columns(df))
    end
    map((val, col) -> @inbounds(setindex!(col, val, i...)), v, columns(df))
    return df
end

# similar
@inline Base.similar(df::FlexTable{N}) where {N} = FlexTable{N}(similar(Table(df)))::FlexTable{N}
@inline Base.similar(df::FlexTable{N}, ::Type{NamedTuple}) where {N} = FlexTable{N}(similar(Table(df)))
@inline Base.similar(df::FlexTable{N}, ::Type{NamedTuple{names,T}}) where {N, names, T} = FlexTable{N}(similar(Table(df, NamedTuple{names, T})))
@inline Base.similar(df::FlexTable, ::Type{NamedTuple}, dims) = FlexTable{__ndims(dims)}(similar(Table(df), _eltypes(columns(df)), dims))
@inline Base.similar(df::FlexTable, ::Type{NamedTuple{names,T}}, dims) where {names, T} = FlexTable{__ndims(dims)}(similar(Table(df), NamedTuple{names, T}, dims))

# Ambiguities...
@inline Base.similar(df::FlexTable, ::Type{NamedTuple}, dims::Union{Integer, AbstractUnitRange}...) = FlexTable{__ndims(dims)}(similar(Table(df), _eltypes(columns(df)), dims))
@inline Base.similar(df::FlexTable, ::Type{NamedTuple}, dims::Tuple{Vararg{Int64,N}}) where {N} = FlexTable{__ndims(dims)}(similar(Table(df), _eltypes(columns(df)), dims))
@inline Base.similar(df::FlexTable, ::Type{NamedTuple}, dims::Tuple{Union{Integer, OneTo},Vararg{Union{Integer, OneTo}}}) = FlexTable{__ndims(dims)}(similar(Table(df), _eltypes(columns(df)), dims))

@inline Base.similar(df::FlexTable, ::Type{NamedTuple{names, T}}, dims::Union{Integer, AbstractUnitRange}...) where {names, T} = FlexTable{__ndims(dims)}(similar(Table(df), NamedTuple{names, T}, dims))
@inline Base.similar(df::FlexTable, ::Type{NamedTuple{names, T}}, dims::Tuple{Vararg{Int64,N}}) where {N, names, T} = FlexTable{__ndims(dims)}(similar(Table(df), NamedTuple{names, T}, dims))
@inline Base.similar(df::FlexTable, ::Type{NamedTuple{names, T}}, dims::Tuple{Union{Integer, OneTo},Vararg{Union{Integer, OneTo}}}) where {names, T} = FlexTable{__ndims(dims)}(similar(Table(df), NamedTuple{names, T}, dims))

@inline __ndims(::Integer) = 1
@inline __ndims(::AbstractUnitRange) = 1
@inline __ndims(::NTuple{N, Any}) where {N} = N

# empty
Base.empty(df::FlexTable) = empty(df, _eltypes(columns(df)))
function Base.empty(df::FlexTable, ::Type{NamedTuple{names, T}}) where {names, T <: Tuple}
    FlexTable(empty(Table(df)))
end

# Support Vector / deque interface (mutable-length vectors)

function Base.empty!(df::FlexTable)
    map(empty!, columns(df))
    return df
end

function Base.pop!(df::FlexTable)
    return map(pop!, columns(df))::NamedTuple
end

function Base.push!(df::FlexTable, v::NamedTuple)
    map(push!, columns(df), v)
    return df
end

function Base.append!(df::Union{FlexTable, Table}, df2::Union{FlexTable, Table})
    map(append!, columns(df), columns(df2))
    return df
end

function Base.popfirst!(df::FlexTable)
    return map(popfirst!, columns(df))::NamedTuple
end

function Base.pushfirst!(df::FlexTable, v::NamedTuple)
    map(pushfirst!, columns(df), v)
    return df
end

function Base.prepend!(df::Union{FlexTable, Table}, df2::Union{FlexTable, Table})
    map(prepend!, columns(df), columns(df2))
    return df
end

function Base.deleteat!(df::FlexTable, i)
    map(col -> deleteat!(col, i), columns(df))
    return df
end

function Base.insert!(df::FlexTable, i::Integer, v::NamedTuple)
    map((col, val) -> insert!(col, i, val), columns(df), v)
    return df
end

function Base.splice!(df::FlexTable, inds::Integer)
    return map(col -> splice!(col, inds), columns(df))::NamedTuple
end

function Base.splice!(df::FlexTable, inds::AbstractVector)
    return FlexTable{1}(map(col -> splice!(col, inds), columns(df)))
end

function Base.splice!(df::FlexTable, inds::Integer, ins::NamedTuple)
    return map((col, vals) -> splice!(col, inds, vals), columns(df), ins)::NamedTuple
end

function Base.splice!(df::FlexTable, inds::AbstractVector, ins::NamedTuple)
    return FlexTable{1}(map((col, vals) -> splice!(col, inds, vals), columns(df), ins))
end

function Base.splice!(df::Union{FlexTable, Table}, inds::Integer, ins::Union{FlexTable, Table})
    return map((col, vals) -> splice!(col, inds, vals), columns(df), columns(ins))::NamedTuple
end

function Base.splice!(df::Union{FlexTable, Table}, inds::AbstractVector, ins::Union{FlexTable, Table})
    return FlexTable{1}(map((col, vals) -> splice!(col, inds, vals), columns(df), columns(ins)))
end

# TODO splicing in an `AbstractArray{<:NamedTuple}` should be possible...

# Speedups for column-based storage

function Base.getindex(df::FlexTable, inds::Union{AbstractArray, Colon}...)
    return FlexTable{_getindex_dims(inds)}(map(col -> getindex(col, inds...), columns(df)))
end

function Base.view(df::FlexTable, inds::Union{AbstractArray, Colon}...)
    return FlexTable{_getindex_dims(inds)}(map(col -> view(col, inds...), columns(df)))
end

@inline _getindex_dims(inds) = __getindex_dims(0, inds...)
@inline __getindex_dims(n::Int) = n
@inline __getindex_dims(n::Int, ::Int, inds...) = __getindex_dims(n, inds...)
@inline __getindex_dims(n::Int, ::AbstractArray{<:Any, m}, inds...) where {m} = __getindex_dims(n + m, inds...)
@inline __getindex_dims(n::Int, ::Colon, inds...) = __getindex_dims(n + 1, inds...)

# Deprecated for .= syntax (via Base.Broadcast.materialize!)
# It seems `Ref` might be the new cool here. Could also consider `AbstractArray{<:NamedTuple, 0}`?
#function Base.setindex!(df::Table{<:NamedTuple{names}}, v::NamedTuple{names}, inds::Union{AbstractArray, Colon}...) where {names}
#    map((col, val) -> setindex!(col, val, inds...), columns(df), v)
#    return df
#end

function Base.setindex!(df::FlexTable, df2::Union{FlexTable, Table}, inds::Union{AbstractArray, Colon}...)
    map((col, col2) -> setindex!(col, col2, inds...), columns(df), columns(df2))
    return df
end

function Base.vcat(df::Union{FlexTable, Table}, df2::Union{FlexTable, Table})
    return FlexTable{_vcat_ndims(ndims(df), ndims(df2))}(map(vcat, columns(df), columns(df2)))
end

function Base.hcat(df::Union{FlexTable, Table}, df2::Union{FlexTable, Table})
    return FlexTable{_hcat_ndims(ndims(df), ndims(df2))}(map(hcat, columns(df), columns(df2)))
end

function Base.hvcat(rows::Tuple{Vararg{Int}}, dfs::Union{FlexTable, Table}...)
    return FlexTable(map((cols...,) -> hvcat(rows, cols...), map(columns, dfs)...))
end

@pure function _vcat_ndims(i::Int, j::Int)
    max(i, j, 1)
end

@pure function _hcat_ndims(i::Int, j::Int)
    max(i, j, 2)
end