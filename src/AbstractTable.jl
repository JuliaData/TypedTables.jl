abstract AbstractTable

#############################################################################
# Construction, conversion, etc
#############################################################################

@inline Base.convert{Tbl<:AbstractTable}(::Type{Tbl}, t::AbstractTable) = Tbl(get(t))

@inline rename{Tbl<:AbstractTable, Names}(t::Tbl, ::Type{Val{Names}}) = table_type(Tbl, Names)(get(t))
@generated function rename{OldName, NewName}(t::AbstractTable, ::Type{Val{OldName}}, ::Type{Val{NewName}})
    j = [nameindex(names(t), OldName)...]

    new_names = [names(t)...]
    new_names[j] = NewName
    new_names = (new_names...)

    return :($(table_type(t, new_names))(get(t)))
end

@generated function Base.copy(t::AbstractTable)
    exprs = [:(copy(get(t)[$j])) for j = 1:ncol(t)]
    return quote
        $(Expr(:meta, :inline))
        $(Expr(:call, table_type(t), Expr(:tuple, exprs...)))
    end
end


#############################################################################
# Reflection
#############################################################################

@inline Base.names{Tbl<:AbstractTable}(::Tbl) = names(Tbl)
@inline storagetypes{Tbl<:AbstractTable}(::Tbl) = storagetypes(Tbl)
@inline storagetypes{Tbl<:AbstractTable}(::Type{Tbl}) = Core.Inference.return_type(get, Tuple{Tbl})

@inline eltypes{Tbl<:AbstractTable}(::Tbl) = eltypes(Tbl)

@generated function eltypes{Tbl<:AbstractTable}(::Type{Tbl})
    storage = storagetypes(Tbl)
    elem_types = map(eltype, storage.parameters)
    quote
        $(Expr(:meta, :inline))
        $(Expr(:curly, :Tuple, elem_types...))
    end
end

@inline nrow{Tbl<:AbstractTable}(t::Tbl) = length(get(t)[1])
@inline ncol{Tbl<:AbstractTable}(::Tbl) = ncol(Tbl)
@inline Base.length{Tbl<:AbstractTable}(t::Tbl) = nrow(t)
@inline Base.endof{Tbl<:AbstractTable}(t::Tbl) = endof(get(t)[1])
@inline Base.isempty(t::AbstractTable) = isempty(get(t)[1])

@pure ncol{Tbl<:AbstractTable}(::Type{Tbl}) = length(names(Tbl))


#############################################################################
# Indexing columns
#############################################################################

@generated function Base.getindex{Name}(t::AbstractTable, ::Type{Val{Name}})
    ns = names(t)
    if isa(Name, Symbol)
        j = nameindex(ns, Name)

        return quote
            $(Expr(:meta, :inline))
            get(t)[$j]
        end
    elseif isa(Name, Tuple{Vararg{Symbol}})
        inds = nameindex(ns, Name)
        exprs = [:(get(t)[$(inds[j])]) for j = 1:length(inds)]
        return quote
            $(Expr(:meta, :inline))
            $(Expr(:call, table_type(t, Name), Expr(:tuple, exprs...)))
        end
    else
        str = "Can't get column(s) named $Name"
        return :(error($str))
    end
end

#############################################################################
# iterating over rows
#############################################################################

# There is a strong assumption that containers are vector-like with length() and getindex()
# TODO consider alternative iterator that takes iterables in lockstep (like zip)
# TODO consider computed containers without length() (similar to `UniformScaling`)
# (perhaps there could be a system of fallbacks?)

@inline function Base.start(t::AbstractTable)
    @boundscheck check_lengths(t)
    return 1
end
@generated function Base.next(t::AbstractTable, state)
    exprs = [:(Base.getindex(get(t)[$i],state)) for i = 1:ncol(t)]
    return quote
        $(Expr(:meta, :inline))
        @inbounds return ($(Expr(:call, row_type(t, names(t)), Expr(:tuple, exprs...))), state + 1)
    end
end
@inline Base.done(t::AbstractTable, state) = state > nrow(t)

@generated function check_lengths(t::AbstractTable)
    if ncol(t) <= 1
        return nothing
    end

    exprs = [quote
            if len != length(get(t)[$i])
                error("Column lengths don't match")
            end
        end for i = 2:ncol(t)]

    return quote
        $(Expr(:meta, :inline))
        len = length(get(t)[1])
        $(Expr, :block, exprs...)
    end
end



#############################################################################
# indexing rows
#############################################################################

@generated function Base.getindex(t::AbstractTable, i::Integer)
    exprs = [:(getindex(get(t)[$c], i)) for c = 1:ncol(t)]
    return quote
        $(Expr(:meta, :inline, :propagate_inbounds))
        $(Expr(:call, row_type(t, names(t)), Expr(:tuple, exprs...)))
    end
end
@generated function Base.getindex(t::AbstractTable, inds)
    exprs = [:(getindex(get(t)[$c], inds)) for c = 1:ncol(t)]
    return quote
        $(Expr(:meta, :inline, :propagate_inbounds))
        $(Expr(:call, table_type(t, names(t)), Expr(:tuple, exprs...)))
    end
end
@inline Base.getindex(t::AbstractTable, ::Colon) = t

@generated function Base.setindex!(t::AbstractTable, v::AbstractRow, i::Integer)
    if similarnames(t,v)
        order = names_perm(t, v)
        exprs = [:(setindex!(get(t)[$(order[c])], get(v)[$c], i)) for c = 1:ncol(t)]
        return quote
            $(Expr(:meta, :inline, :propagate_inbounds))
            $(Expr(:block, exprs...))
        end
    else
        error("Cannot match columns $(names(t)) with $(names(v))")
    end
end
@generated function Base.setindex!(t::AbstractTable, v::Tuple, i)
    if length(v.parameters) != ncol(t)
        str = "Cannot assign a $(length(v.parameters))-tuple to $(ncol(t)) columns"
        return :(error($str))
    end
    exprs = [:(setindex!(get(t)[$c], v[$c], i)) for c = 1:ncol(t)]
    return quote
        $(Expr(:meta, :inline, :propagate_inbounds))
        $(Expr(:block, exprs...))
    end
end
@generated function Base.setindex!(t::AbstractTable, v::AbstractTable, inds)
    if similarnames(t,v)
        order = names_perm(t, v)
        exprs = [:(setindex!(get(t)[$(order[c])], get(v)[$c], inds)) for c = 1:ncol(t)]
        return quote
            $(Expr(:meta, :inline, :propagate_inbounds))
            $(Expr(:block, exprs...))
        end
    else
        error("Cannot match columns $(names(t)) with $(names(v))")
    end
end


# head/tail
function head(t::AbstractTable, n = 5)
    if nrow(t) <= n
        return t
    else
        return t[1:n]
    end
end

function tail(t::AbstractTable, n = 5)
    if nrow(t) <= n
        return t
    else
        return t[end-n+1:end]
    end
end



#############################################################################
# Indexing with two variables
#############################################################################

@propagate_inbounds function Base.getindex{GetName}(t::AbstractTable, rowinds, ::Type{Val{GetName}})
    t[Val{GetName}][rowinds]
end

@propagate_inbounds function Base.setindex!{GetName}(t::AbstractTable, val, rowinds, ::Type{Val{GetName}})
    t[Val{GetName}][rowinds] = val
end

# Make it symmetric (#13)

@propagate_inbounds function Base.getindex{GetName}(t::AbstractTable, ::Type{Val{GetName}}, rowinds)
    t[Val{GetName}][rowinds]
end

@propagate_inbounds function Base.setindex!{GetName}(t::AbstractTable, val, ::Type{Val{GetName}}, rowinds)
    t[Val{GetName}][rowinds] = val
end

#############################################################################
# push, pop, etc
#############################################################################

@generated function Base.pop!(t::AbstractTable)
    exprs = [:(pop!(get(t)[$c])) for c = 1:ncol(t)]
    return Expr(:call, row_type(t), Expr(:tuple, exprs...))
end

@generated function Base.shift!(t::AbstractTable)
    exprs = [:(shift!(get(t)[$c])) for c = 1:ncol(t)]
    return Expr(:call, row_type(t), Expr(:tuple, exprs...))
end

@generated function Base.push!(t::AbstractTable, v::Tuple)
    if ncol(t) != length(v.parameters)
        str = "Cannot assign a $(length(v.parameters))-tuple to $(ncol(t)) columns"
        return :(error($str))
    end
    exprs = [:(push!(get(t)[$c], v[$c])) for c = 1:ncol(t)]
    return Expr(:block, exprs..., :t)
end
@generated function Base.push!(t::AbstractTable, r::AbstractRow)
    order = names_perm(names(t), names(r))
    exprs = [:(push!(get(t)[$(order[c])], get(r)[$c])) for c = 1:ncol(t)]
    return Expr(:block, exprs..., :t)
end

@generated function Base.unshift!(t::AbstractTable, v::Tuple)
    if ncol(t) != length(v.parameters)
        str = "Cannot assign a $(length(v.parameters))-tuple to $(ncol(t)) columns"
        return :(error($str))
    end
    exprs = [:(unshift!(get(t)[$c], v[$c])) for c = 1:ncol(t)]
    return Expr(:block, exprs..., :t)
end
@generated function Base.unshift!(t::AbstractTable, r::AbstractRow)
    order = names_perm(names(t), names(r))
    exprs = [:(unshift!(get(t)[$(order[c])], get(r)[$c])) for c = 1:ncol(t)]
    return Expr(:block, exprs..., :t)
end

@generated function Base.append!(t::AbstractTable, v::Tuple)
    if ncol(t) != length(v.parameters)
        str = "Cannot assign a $(length(v.parameters))-tuple to $(ncol(t)) columns"
        return :(error($str))
    end
    exprs = [:(append!(get(t)[$c], v[$c])) for c = 1:ncol(t)]
    return Expr(:block, exprs..., :t)
end
@generated function Base.append!(t::AbstractTable, t2::AbstractTable)
    order = names_perm(names(t), names(t2))
    exprs = [:(append!(get(t)[$(order[c])], get(t2)[$c])) for c = 1:ncol(t)]
    return Expr(:block, exprs..., :t)
end

@generated function Base.prepend!(t::AbstractTable, v::Tuple)
    if ncol(t) != length(v.parameters)
        str = "Cannot assign a $(length(v.parameters))-tuple to $(ncol(t)) columns"
        return :(error($str))
    end
    exprs = [:(prepend!(get(t)[$c], v[$c])) for c = 1:ncol(t)]
    return Expr(:block, exprs..., :t)
end
@generated function Base.prepend!(t::AbstractTable, t2::AbstractTable)
    order = names_perm(names(t), names(t2))
    exprs = [:(prepend!(get(t)[$(order[c])], get(t2)[$c])) for c = 1:ncol(t)]
    return Expr(:block, exprs..., :t)
end

@generated function Base.insert!(t::AbstractTable, i::Integer, v::Tuple)
    if ncol(t) != length(v.parameters)
        str = "Cannot assign a $(length(v.parameters))-tuple to $(ncol(t)) columns"
        return :(error($str))
    end
    exprs = [:(insert!(get(t)[$c], i, v[$c])) for c = 1:ncol(t)]
    return Expr(:block, exprs..., :t)
end
@generated function Base.insert!(t::AbstractTable, i::Integer, r::AbstractRow)
    order = names_perm(names(t), names(r))
    exprs = [:(insert!(get(t)[$(order[c])], i, get(r)[$c])) for c = 1:ncol(t)]
    return Expr(:block, exprs..., :t)
end

@generated function Base.empty!(t::AbstractTable)
    exprs = [:(empty!(get(t)[$c])) for c = 1:ncol(t)]
    return Expr(:block, exprs..., :t)
end

@generated function Base.deleteat!(t::AbstractTable, i)
    exprs = [:(deleteat!(get(t)[$c], i)) for c = 1:ncol(t)]
    return Expr(:block, exprs..., :t)
end

@generated function Base.splice!(t::AbstractTable, i::Integer)
    exprs = [:(splice!(get(t)[$c], i)) for c = 1:ncol(t)]
    return Expr(:call, row_type(t), Expr(:tuple, exprs...))
end
@generated function Base.splice!(t::AbstractTable, i::Integer, v::Tuple)
    exprs = [:(splice!(get(t)[$c], i, v[$c])) for c = 1:ncol(t)]
    return Expr(:call, row_type(t), Expr(:tuple, exprs...))
end
@generated function Base.splice!(t::AbstractTable, i::Integer, v::Union{AbstractRow,AbstractTable})
    order = names_perm(names(v), names(t))
    exprs = [:(splice!(get(t)[$c], i, get(v)[$(order[c])])) for c = 1:ncol(t)]
    return Expr(:call, row_type(t), Expr(:tuple, exprs...))
end
@generated function Base.splice!(t::AbstractTable, i)
    exprs = [:(splice!(get(t)[$c], i)) for c = 1:ncol(t)]
    return Expr(:call, table_type(t), Expr(:tuple, exprs...))
end
@generated function Base.splice!(t::AbstractTable, i, v::Tuple)
    exprs = [:(splice!(get(t)[$c], i, v[$c])) for c = 1:ncol(t)]
    return Expr(:call, table_type, Expr(:tuple, exprs...))
end
@generated function Base.splice!(t::AbstractTable, i, v::Union{AbstractRow,AbstractTable})
    order = names_perm(names(v), names(t))
    exprs = [:(splice!(get(t)[$c], i, get(v)[$(order[c])])) for c = 1:ncol(t)]
    return Expr(:call, table_type(t), Expr(:tuple, exprs...))
end


#############################################################################
# Vertically concatenate rows and tables into tables
#############################################################################

# TODO still problem with mixed Row-Table vcat inherited from Base scalar-Vector vcat?

Base.vcat(t::AbstractTable) = t

@generated function Base.vcat(r::AbstractRow)
    exprs = [:(vcat(get(r)[$c])) for c = 1:ncol(r)]
    return quote
        @_inline_meta
        $(Expr(:call, table_type(r), Expr(:tuple, exprs...)))
    end
end


@generated function Base.vcat(t1::Union{AbstractRow, AbstractTable}, t2::Union{AbstractRow, AbstractTable})
    if similarnames(t1, t2)
        order = names_perm(t1, t2)
        exprs = [:(vcat(get(t1)[$(order[c])], get(t2)[$c])) for c = 1:ncol(t1)]
        return Expr(:call, table_type(t1), Expr(:tuple, exprs...))
    else
        error("Cannot match $(ncol(t2)) columns to $(ncol(t1)) columns")
    end
end

@inline Base.vcat(t1::Union{AbstractRow, AbstractTable}, t2::Union{AbstractRow, AbstractTable}, ts::Union{AbstractRow, AbstractTable}...) = vcat(vcat(t1, t2), ts...)


#############################################################################
# Horizontally concatenate columns and tables into tables
#############################################################################

Base.hcat(c::AbstractColumn) = table_type(typeof(c))((get(c),))
Base.hcat(t::AbstractTable) = t

@generated function Base.hcat(t1::Union{AbstractColumn,AbstractTable}, t2::Union{AbstractColumn,AbstractTable})
    names1 = (t1 <: Column ? (name(t1),) : names(t1))
    names2 = (t2 <: Column ? (name(t2),) : names(t2))

    if length(intersect(names1, names2)) != 0
        str = "Column names are not distinct. Got $names1 and $names2"
        return :(error($str))
    end

    newnames = (names1..., names2...)
    exprs1 = t1 <: Column ? [:(get(t1))] : [:(get(t1)[$j]) for j = 1:length(names1)]
    exprs2 = t2 <: Column ? [:(get(t2))] : [:(get(t2)[$j]) for j = 1:length(names2)]
    exprs = vcat(exprs1, exprs2)

    return Expr(:call, table_type(t1, newnames), Expr(:tuple, exprs...))
end

@inline Base.hcat(t1::Union{AbstractColumn,AbstractTable}, t2::Union{AbstractColumn,AbstractTable}, ts::Union{AbstractColumn,AbstractTable}...) = hcat(hcat(t1, t2), ts...)


#############################################################################
# Equality
#############################################################################

@generated function Base.:(==)(t1::AbstractTable, t2::AbstractTable)
    if !similarnames(t1, t2)
        return false
    elseif ncol(t1) == 0
        return true
    end

    order = names_perm(t1, t2)
    expr = :( data1[$(order[1])] == data2[1] )
    for j = 2:ncol(t1)
        expr = Expr(:call, :(&), expr, :( data1[$(order[j])] == data2[$j] ))
    end

    return quote
        $(Expr(:meta, :inline))
        data1 = get(t1)
        data2 = get(t2)
        $expr
    end
end

@generated function Base.isapprox(t1::AbstractTable, t2::AbstractTable; kwargs...)
    if !similarnames(t1, t2)
        return false
    elseif ncol(t1) == 0
        return true
    end

    order = names_perm(t1, t2)
    expr = :( all(map((val1,val2)->isapprox(val1, val2; kwargs...), data1[$(order[1])], data2[1])) )
    for j = 2:ncol(row1)
        expr = Expr(:call, :(&), expr, :( all(map((val1,val2)->isapprox(val1, val2; kwargs...), data1[$(order[j])], data2[j])) ))
    end

    return quote
        $(Expr(:meta, :inline))
        data1 = get(t1)
        data2 = get(t2)
        $expr
    end
end
