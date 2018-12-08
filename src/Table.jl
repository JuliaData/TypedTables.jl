# A `Table` presents itself as an `AbstractArray` of `NamedTuples`s

"""
    Table(name1 = array1, ...)

Create a column-storage-based `Table` with column names `name1`, etc, from arrays `array1`,
etc. The input arrays `array1`, etc, must share the same dimensionality and indices.

`Table` itself is an `AbstractArray` whose elements are `NamedTuple`s of the form
`(name1 = first(array1), ...)`, etc. Rows of the table are obtained via standard array
indexing `table[i]`, and columns via `table.name`.

`Table` differs from `FlexTable` in that the columns are immutable - you may add, remove,
rename and replace entire columns of a `FlexTable`, but not a `Table`. However, `Table` can
access and iterate rows in local scope with fast, fully type-inferred code while `FlexTable`
will be more efficient with a higher-order interface.
"""
struct Table{T <: NamedTuple, N, Data <: NamedTuple{<:Any, <:Tuple{Vararg{AbstractArray{<:Any,N}}}}} <: AbstractArray{T, N}
    data::Data

    # Inner constructor, to compare axes?
end

Table(ts...; kwargs...) = _table(removenothings(merge(_columns(ts...), kwargs.data)))

function Table{NamedTuple{names,T}}() where {names, T<:Tuple}
    # TODO we can make this type-stable.
    Table(NamedTuple{names}(ntuple(i -> Vector{T.parameters[i]}(), length(T.parameters))))
end

_table(nt::NamedTuple) = Table{_eltypes(nt), _ndims(nt), typeof(nt)}(nt)

_columns() = NamedTuple()
_columns(x, y...) = merge(_columns(x), _columns(y...))
_columns(nt::NamedTuple) = nt
_columns(t::Table) = columns(t)
function _columns(x)
    if Tables.istable(x)
        if Tables.columnaccess(x)
            return columntable(x)
        else
            return Tables.buildcolumns(Tables.schema(x), x)
        end
    else
        error("Cannot construct table from $(typeof(x))")
    end
end

@generated function removenothings(nt::NamedTuple{names, T}) where {names, T}
    exprs = []
    newnames = []
    params = T.parameters
    for i in 1:length(params)
        if params[i] <: AbstractArray
            push!(newnames, names[i])
            push!(exprs, :(getfield(nt, $(QuoteNode(names[i])))))
        elseif params[i] !== Nothing
            error("Columns must be arrays")
        end
    end

    if length(names) == length(newnames)
        return :(nt)
    else
        return :(NamedTuple{$(tuple(newnames...))}(tuple($(exprs...))))
    end
end

Tables.istable(::Type{<:Table}) = true
Tables.rowaccess(::Type{<:Table}) = true
Tables.columnaccess(::Type{<:Table}) = true
Tables.schema(::Table{T}) where {T} = Tables.Schema(T)
Tables.materializer(::Table) = Table

"""
    columns(table::Table)

Convert a `Table` into a `NamedTuple` of its columns.
"""
@inline Tables.columns(t::Table) = Core.getfield(t, :data)

@inline Tables.rows(t::Table) = t

# Simple column access via `table.columnname`
@inline Base.getproperty(t::Table, name::Symbol) = getproperty(columns(t), name)

function Base.setproperty!(t::Table, name::Symbol, a)
    error("type Table is immutable. Set the values of an existing column with the `.=` operator, e.g. `table.name .= array`.")
end

propertytype(::Table) = Table

"""
    columnnames(table)

Return a tuple of the column names of a `Table`.
"""
columnnames(::AbstractArray{<:NamedTuple{names}}) where {names} = names

# show
Base.show(io::IO, ::MIME"text/plain", t::Table) = showtable(io, t)
Base.show(io::IO, t::Table) = showtable(io, t)

# Basic AbstractArray interface

@inline Base.size(t::Table) = size(first(columns(t)))
@inline Base.axes(t::Table) = axes(first(columns(t)))
@inline Base.IndexStyle(t::Table) = IndexStyle(first(columns(t)))

function Base.checkbounds(::Type{Bool}, t::Table, i...)
    # Make sure we are in bounds for *every* column. Only safe to do
    # here because each column might mutate size independently of the others!
    all(col -> checkbounds(Bool, col, i...), columns(t))
end

@inline function Base.getindex(t::Table{T}, i::Int) where {T}
    @boundscheck checkbounds(t, i)
    # AbstractArray{T} expects a subtype of T, and NamedTuples are invariant.
    # For e.g. columns which are Union types we makes sure we emit a named tuple with Union
    # elements. The convert should be a no-op in the case of strongly-typed columns.

    # TODO find a way to make this faster than O(2^N) for N Union columns
    convert(T, map(col -> @inbounds(getindex(col, i)), columns(t)))::T
end

@inline function Base.getindex(t::Table{T}, i::Int...) where {T}
    @boundscheck checkbounds(t, i...)
    convert(T, map(col -> @inbounds(getindex(col, i...)), columns(t)))::T
end

@inline function Base.setindex!(t::Table{T}, v::T, i::Int) where {T}
    @boundscheck checkbounds(t, i)
    map((val, col) -> @inbounds(setindex!(col, val, i)), v, columns(t))
    return t
end
@inline Base.setindex!(t::Table{T}, v, i::Int) where {T} = setindex!(t, convert(T, v), i)

@inline function Base.setindex!(t::Table{T}, v::T, i::Int...) where {T}
    @boundscheck checkbounds(t, i...)
    map((val, col) -> @inbounds(setindex!(col, val, i...)), v, columns(t))
    return t
end
@inline Base.setindex!(t::Table{T}, v, i::Int...) where {T} = setindex!(t, convert(T, v), i...)

# similar

@inline Base.similar(t::Table, ::Type{NamedTuple{names, T}}, dims) where {names, T <: Tuple} = _similar(t, NamedTuple{names, T}, dims)

# Ambiguities...
@inline Base.similar(t::Table, ::Type{NamedTuple{names, T}}) where {names, T <: Tuple} = similar(t, NamedTuple{names, T}, axes(t))
@inline Base.similar(t::Table, ::Type{NamedTuple{names, T}}, dims::Union{Integer, AbstractUnitRange}...) where {names, T <: Tuple} = _similar(t, NamedTuple{names, T}, dims)
@inline Base.similar(t::Table, ::Type{NamedTuple{names, T}}, dims::Tuple{Vararg{Int64,N}}) where {names, T <: Tuple, N} = _similar(t, NamedTuple{names, T}, dims)
@inline Base.similar(t::Table, ::Type{NamedTuple{names, T}}, dims::Tuple{Union{Integer, OneTo},Vararg{Union{Integer, OneTo}}}) where {names, T <: Tuple} = _similar(t, NamedTuple{names, T}, dims)

@generated function _similar(t::Table{<:NamedTuple{oldnames}}, ::Type{NamedTuple{names, T}}, newaxes) where {oldnames, names, T <: Tuple}
    if isempty(names)
        return :(similar(first(columns(t)), NamedTuple{(),Tuple{}}, newaxes))
    end

    # Try and be clever - if the name is preserved, we preserve the similar type, otherwise
    # just be similar to the first one.
    exprs = [name ∈ oldnames ? :(similar(getproperty(t, $(QuoteNode(name))), $ElType, newaxes)) :
                               :(similar(first(columns(t)), $ElType, newaxes)) for (name, ElType) in zip(names, T.parameters)]
    return :(Table(NamedTuple{names}(tuple($(exprs...)))))
end

# empty
Base.empty(t::Table) = empty(t, eltype(t))
@generated function Base.empty(t::Table{<:NamedTuple{oldnames}, 1}, ::Type{NamedTuple{names, T}}) where {oldnames, names, T <: Tuple}
    if isempty(names)
        return :(empty(first(columns(t)), NamedTuple{(),Tuple{}}))
    end

    # Try and be clever - if the name is preserved, we preserve the similar type, otherwise
    # just be similar to the first one.
    exprs = [name ∈ oldnames ? :(empty(getproperty(t, $(QuoteNode(name))), $ElType)) :
                               :(empty(first(columns(t)), $ElType)) for (name, ElType) in zip(names, T.parameters)]
    return :(Table(NamedTuple{names}(tuple($(exprs...)))))
end

# Support Vector / deque interface (mutable-length vectors)

function Base.empty!(t::Table)
    map(empty!, columns(t))
    return t
end

function Base.pop!(t::Table)
    return map(pop!, columns(t))
end

function Base.push!(t::Table{<:NamedTuple{names}}, v::NamedTuple{names}) where {names}
    map(push!, columns(t), v)
    return t
end

function Base.append!(t::Table{<:NamedTuple{names}}, t2::Table{<:NamedTuple{names}}) where {names}
    map(append!, columns(t), columns(t2))
    return t
end

function Base.popfirst!(t::Table)
    return map(popfirst!, columns(t))
end

function Base.pushfirst!(t::Table{<:NamedTuple{names}}, v::NamedTuple{names}) where {names}
    map(pushfirst!, columns(t), v)
    return t
end

function Base.prepend!(t::Table{<:NamedTuple{names}}, t2::Table{<:NamedTuple{names}}) where {names}
    map(prepend!, columns(t), columns(t2))
    return t
end

function Base.deleteat!(t::Table, i)
    map(col -> deleteat!(col, i), columns(t))
    return t
end

function Base.insert!(t::Table{<:NamedTuple{names}}, i::Integer, v::NamedTuple{names}) where {names}
    map((col, val) -> insert!(col, i, val), columns(t), v)
    return t
end

function Base.splice!(t::Table, inds::Integer)
    return map(col -> splice!(col, inds), columns(t))
end

function Base.splice!(t::Table, inds::AbstractArray)
    return Table(map(col -> splice!(col, inds), columns(t)))
end

function Base.splice!(t::Table{<:NamedTuple{names}}, inds::Integer, ins::NamedTuple{names}) where {names}
    return map((col, vals) -> splice!(col, inds, vals), columns(t), ins)
end

function Base.splice!(t::Table{<:NamedTuple{names}}, inds::AbstractArray, ins::NamedTuple{names}) where {names}
    return Table(map((col, vals) -> splice!(col, inds, vals), columns(t), ins))
end

function Base.splice!(t::Table{<:NamedTuple}, inds::Integer, ins::AbstractVector{<:NamedTuple})
    return map((col, vals) -> splice!(col, inds, vals), columns(t), columns(ins))
end

function Base.splice!(t::Table{<:NamedTuple}, inds::AbstractArray, ins::AbstractVector{<:NamedTuple})
    return Table(map((col, vals) -> splice!(col, inds, vals), columns(t), columns(ins)))
end

# TODO splicing in an `AbstractArray{<:NamedTuple}` should be possible...

# Speedups for column-based storage

function Base.getindex(t::Table, inds::Union{AbstractArray, Colon}...)
    return Table(map(col -> getindex(col, inds...), columns(t)))
end

function Base.view(t::Table, inds::Union{AbstractArray, Colon}...)
    return Table(map(col -> view(col, inds...), columns(t)))
end

# Deprecated for .= syntax (via Base.Broadcast.materialize!)
# It seems `Ref` might be the new cool here. Could also consider `AbstractArray{<:NamedTuple, 0}`?
#function Base.setindex!(t::Table{<:NamedTuple{names}}, v::NamedTuple{names}, inds::Union{AbstractArray, Colon}...) where {names}
#    map((col, val) -> setindex!(col, val, inds...), columns(t), v)
#    return t
#end

function Base.setindex!(t::Table{<:NamedTuple{names}}, t2::Table{<:NamedTuple{names}}, inds::Union{AbstractArray, Colon}...) where {names}
    map((col, col2) -> setindex!(col, col2, inds...), columns(t), columns(t2))
    return t
end

# Private fields are never exposed since they can conflict with column names
Base.propertynames(t::Table, private::Bool=false) = columnnames(t)


@inline Base.vcat(t::Table) = Table(map(vcat, columns(t)))

@inline function Base.vcat(t::Table{<:NamedTuple{names}}, t2::Table{<:NamedTuple{names}}) where {names}
    return Table(map(vcat, columns(t), columns(t2)))
end

@inline function Base.vcat(t1::Table{<:NamedTuple{names}}, t2::Table{<:NamedTuple{names}}, ts::Table{<:NamedTuple{names}}...) where {names}
    return Table(map(vcat, columns(t1), columns(t2), map(columns, ts)...))
end


@inline Base.hcat(t::Table) = Table(map(hcat, columns(t)))

@inline function Base.hcat(t::Table{<:NamedTuple{names}}, t2::Table{<:NamedTuple{names}}) where {names}
    return Table(map(hcat, columns(t), columns(t2)))
end

@inline function Base.hcat(t1::Table{<:NamedTuple{names}}, t2::Table{<:NamedTuple{names}}, ts::Table{<:NamedTuple{names}}...) where {names}
    return Table(map(hcat, columns(t1), columns(t2), map(columns, ts)...))
end


function Base.hvcat(rows::Tuple{Vararg{Int}}, tables::Table{<:NamedTuple{names}}...) where {names}
    return Table(map((cols...,) -> hvcat(rows, cols...), map(columns, tables)...))
end

function Base.vec(t::Table{<:NamedTuple{names}}) where {names}
    return Table(map(vec, columns(t)))
end
