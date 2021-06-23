
struct DictTable{I, T <: NamedTuple, Data <: NamedTuple{<:Any, <:Tuple{Vararg{AbstractDictionary}}}, Inds <: AbstractIndices{I}} <: AbstractDictionary{I, T}
    data::Data
    indices::Inds

    function DictTable{I, T, Data, Inds}(data::NamedTuple, indices::AbstractIndices) where {I, T, Data, Inds}
        # All the data columns have to share tokens - copy if we have to
        data = map(data) do col
            if sharetokens(keys(col), indices)
                return col
            else
                out = similar(indices, eltype(col))
                copyto!(out, col)
                return out
            end
        end
        return new(data, indices)
    end
end

@generated function DictTable{I, T, NamedTuple{Names, Types}, Inds}() where {I, T, Inds, Names, Types}
    return quote
        inds = Inds()
        data = NamedTuple{Names, Types}(tuple($((:($(p)()) for p in Types.parameters)...)))
        DictTable{I, T, NamedTuple{Names, Types}, Inds}(data, inds)
    end
end


DictTable(ts...; kwargs...) = DictTable(removenothings_dict(merge(_columns(ts...), kwargs.data)))

_columns(t::DictTable) = columns(t)

@generated function removenothings_dict(nt::NamedTuple{names, T}) where {names, T}
    exprs = []
    newnames = []
    params = T.parameters
    for i in 1:length(params)
        if params[i] <: AbstractDictionary
            push!(newnames, names[i])
            push!(exprs, :(getfield(nt, $(QuoteNode(names[i])))))
        elseif params[i] !== Nothing
            error("Columns must be dictionaries, got $(params[i])")
        end
    end

    if length(names) == length(newnames)
        return :(nt)
    else
        return :(NamedTuple{$(tuple(newnames...))}(tuple($(exprs...))))
    end
end

function DictTable(cols::NamedTuple{names, <:Tuple{Vararg{AbstractDictionary}}}) where names
    if isempty(names)
        throw(MethodError(DictTable, Tuple{NamedTuple{(), Tuple{}}}))
    end
    indices = keys(cols[names[1]])
    I = eltype(indices)
    T = _eltypes(cols)
    return DictTable{I, T, typeof(cols), typeof(indices)}(cols, indices)
end

function DictTable{I, T}() where {I, T <: NamedTuple}
    indices = Indices{I}()
    cols = _similar(indices, T)
    return DictTable{I, T, typeof(cols), typeof(indices)}(cols, indices)
end

@generated function _similar(indices, ::Type{T}) where {T <: NamedTuple}
    exprs = (:(similar(indices, $V)) for V in T.parameters[2].parameters)
    return :(NamedTuple{$(T.parameters[1])}(tuple($(exprs...))))
end

Base.similar(t::DictTable) = similar(t, eltype(t))
function Base.similar(t::DictTable, ::Type{T}) where {T <: NamedTuple}
    return DictTable(_similar(keys(t), T))
end

Dictionaries.empty_type(::Type{DictTable{<:Any, <:Any, <:Any, Inds}}, ::Type{I}) where {I, Inds} = Dictionaries.empty_type(Inds, I)

@generated function Dictionaries.empty_type(::Type{<:DictTable{<:Any, <:Any, <:Any, Inds}}, ::Type{I}, ::Type{NamedTuple{Names, T}}) where {I, Names, T, Inds}
    return quote
        DictTable{I, NamedTuple{Names, T}, NamedTuple{Names, Tuple{$((:(Dictionaries.empty_type(Inds, I, $p)) for p in T.parameters)...)}}, Dictionaries.empty_type(Inds, I)}
    end
end

function Base.empty(t::DictTable{I, <:NamedTuple{names, <:Any}}) where {I, names}
    # Check if first element contains the keys (TODO expand search to any element?)
    if length(names) > 0
        first_name = names[1]
        cols = columns(t)
        first_col = cols[first_name]
        if first_col isa AbstractIndices{I}
            first_col = empty(first_col)
            cols = merge(NamedTuple{(first_name,)}((first_col,)), _similar(first_col, typeof(Base.tail(cols))))
            return DictTable(cols)
        end
    end
    return empty(t, I, eltype(t))
end

function Base.empty(t::DictTable, ::Type{I}, ::Type{T}) where {I, T <: NamedTuple}
    indices = empty(keys(t), I)
    return DictTable(_similar(indices, T))
end

Base.keys(d::DictTable) = getfield(d, :indices)
Tables.columns(d::DictTable) = getfield(d, :data)
@inline Tables.rows(t::DictTable) = t

Base.getproperty(d::DictTable, s::Symbol) = getproperty(columns(d), s)

# Private fields are never exposed since they can conflict with column names
Base.propertynames(t::DictTable, private::Bool=false) = columnnames(t)

Tables.istable(::Type{<:DictTable}) = true
Tables.rowaccess(::Type{<:DictTable}) = true
Tables.columnaccess(::Type{<:DictTable}) = true
Tables.schema(::DictTable{<:Any, T}) where {T} = Tables.Schema(T)
Tables.materializer(::DictTable) = DictTable

function Dictionaries.istokenassigned(d::DictTable, t)
    return all(col -> istokenassigned(col, t), columns(d))
end

function Dictionaries.gettokenvalue(d::DictTable, t)
    return map(col -> gettokenvalue(col, t), columns(d))
end

function Dictionaries.issettable(d::DictTable)
    return all(col -> issettable(col), columns(d))
end

function Dictionaries.settokenvalue!(d::DictTable{I, V}, t, val::V) where {I, V}
    foreach((col, v) -> settokenvalue!(col, t, v), columns(d), val)
    return d
end

function Dictionaries.isinsertable(d::DictTable)
    return all(col -> isinsertable(col), columns(d))
end

function Dictionaries.gettoken!(d::DictTable{I}, i::I) where {I}
    return gettoken!(keys(d), i, map(tokenized, columns(d)))
end

function Dictionaries.deletetoken!(d::DictTable, t)
    return deletetoken!(keys(d), t, map(tokenized, columns(d)))
end

function Base.empty!(d::DictTable)
    empty!(keys(d), map(tokenized, columns(d)))
    return d
end

columnnames(::AbstractDictionary{<:Any, <:NamedTuple{names}}) where {names} = names

@generated function keyname(::DictTable{<:Any, <:Any, Data, Inds}) where { Data, Inds }
    params = Data.parameters[2].parameters
    for i in 1:length(params)
        if params[i] === Inds
            return QuoteNode(Data.parameters[1][i])
        end
    end
    return nothing
end

# show
function Base.show(io::IO, ::MIME"text/plain", t::DictTable)
    if get(io, :compact, false)
        invoke(show, Tuple{typeof(io), MIME"text/plain", AbstractDictionary}, io, MIME"text/plain"(), t)
    else
        showtable(io, t, keyname(t))
    end
end

# function Base.show(io::IO, t::DictTable)
#     if get(io, :compact, false)
#         invoke(show, Tuple{typeof(io), AbstractDictionary}, io, t)
#     else
#         showtable(io, t, keyname(t))
#     end
# end

propertytype(::DictTable) = DictTable
(::GetProperties{()})(t::DictTable) = FillDictionary(keys(t), (;))

# filter!

function Base.filter!(pred, t::DictTable)
    pred2 = token -> pred(map(col -> gettokenvalue(col, token), columns(t)))
    Dictionaries._filter!(pred2, keys(t), map(tokenized, columns(t)))
    return t
end

# Column-based operations: Some operations on rows are faster when considering columns

Base.map(::typeof(identity), t::DictTable) = copy(t)

Base.map(::typeof(merge), t::DictTable) = copy(t)

function Base.map(::typeof(merge), t1::DictTable, t2::DictTable)
    return copy(DictTable(merge(columns(t1), columns(t2))))
end

function Base.map(f::GetProperty, t::DictTable)
    return copy(f(t))
end

@inline function Base.map(f::GetProperties, t::DictTable)
    return copy(f(t))
end

@inline function Base.map(f::Compute{names}, t::DictTable) where {names}
    # minimize number of columns before iterating over the rows
    map(f, GetProperties(names)(t))
end


@inline function Base.map(f::Compute{names}, t::DictTable{<:Any, <:NamedTuple{names}}) where {names}
    # efficient to iterate over rows with a minimal number of columns
    if length(names) == 1 # unwrap in the simple cases
        return map(f.f, getproperty(names[1])(t))
    elseif length(names) == 2
        return map(f.f, getproperty(names[1])(t), getproperty(names[2])(t))
    end

    invoke(map, Tuple{Function, typeof(t)}, f, t)
end

@generated function Base.map(s::Select{names}, t::DictTable) where {names}
    exprs = [:($(names[i]) = map(s.fs[$i], t)) for i in 1:length(names)]

    return :(DictTable($(Expr(:tuple, exprs...))))
end

SplitApplyCombine.mapview(::typeof(merge), t::DictTable) = t

function SplitApplyCombine.mapview(::typeof(merge), t1::DictTable, t2::DictTable)
    return DictTable(merge(columns(t1), columns(t2)))
end

@inline function SplitApplyCombine.mapview(f::GetProperty, t::DictTable)
    return f(t)
end

@inline function SplitApplyCombine.mapview(f::GetProperties, t::DictTable)
    return f(t)
end

@inline function SplitApplyCombine.mapview(f::Compute{names}, t::DictTable) where {names}
    # minimize number of columns before iterating over the rows
    mapview(f, GetProperties(names)(t))
end

@inline function SplitApplyCombine.mapview(f::Compute{names}, t::DictTable{<:Any, <:NamedTuple{names}}) where {names}
    # efficient to iterate over rows with a minimal number of columns
    if length(names) == 1 # unwrap in the simple cases (consider 2-argument version)
        return mapview(f.f, getproperty(names[1])(t))
    end

    invoke(mapview, Tuple{Function, typeof(t)}, f, t)
end

@generated function SplitApplyCombine.mapview(s::Select{names}, t::DictTable) where {names}
    exprs = [:($(names[i]) = mapview(s.fs[$i], t)) for i in 1:length(names)]

    return :(DictTable($(Expr(:tuple, exprs...))))
end

function Indexing.getindices(t::DictTable, inds::AbstractIndices)
    return DictTable(map(col -> getindices(col, inds), columns(t)))
end

function Base.view(t::DictTable, inds::AbstractIndices)
    return DictTable(map(col -> view(col, inds), columns(t)))
end

@inline function Broadcast.broadcasted(::Dictionaries.DictionaryStyle, ::typeof(merge), ts::DictTable...) where {N}
	return DictTable(merge(map(columns, ts)...))
end

@inline function Broadcast.broadcasted(::Dictionaries.DictionaryStyle, f::GetProperty, t::DictTable) where {N}
    return f(t)
end

@inline function Broadcast.broadcasted(::Dictionaries.DictionaryStyle, f::GetProperties, t::DictTable) where {N}
    return DictTable(f(t))
end

@inline function Broadcast.broadcasted(::Dictionaries.DictionaryStyle, f::Compute, t::DictTable) where {N}
    return map(f, t)
end

@inline function Broadcast.broadcasted(::Dictionaries.DictionaryStyle, f::Select, t::DictTable) where {N}
    return map(f, t)
end

# findall

function Base.findall(f::GetProperty, t::DictTable)
    return findall(identity, f(t))
end

function Base.findall(f::Compute{names}, t::DictTable) where {names}
    # minimize number of columns before iterating over the rows
    return findall(f, GetProperties(names)(t))
end

function Base.findall(f::Compute{names}, t::DictTable{<:NamedTuple{names}}) where {names}
    # efficient to iterate over rows with a minimal number of columns
    if length(names) == 1 # unwrap in the simple cases
        return findall(f.f, getproperty(names[1])(t))
    end

    invoke(findall, Tuple{Function, typeof(t)}, f, t)
end

#
# grouping
#

function SplitApplyCombine.group(groups::AbstractDictionary, values::DictTable)
    I = eltype(groups)
    T = eltype(values)
    D = Dictionaries.empty_type(typeof(values), keytype(values), T)

    indices = keys(values)
    out = empty(groups, I, D)

    if sharetokens(groups, values)
        @inbounds for token in tokens(groups)
            group = gettokenvalue(groups, token)
            key = gettokenvalue(indices, token)
            value = gettokenvalue(values, token)
            insert!(get!(D, out, group), key, value)
        end
    else
        if length(groups) != length(values)
            throw(KeyError("Indices must match"))
        end

        for (i, group) in pairs(groups)
            value = values[i]
            insert!(get!(D, out, group), i, value)
        end
    end

    return out
end