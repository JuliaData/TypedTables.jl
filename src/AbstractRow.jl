"""
    abstract AbstractCell

In the context of data tables, a cell is a single piece of data annotated by a
column (or field) name. This is an abstract type that defines the interface
necessary for a type to be a valid *TypedTables* cell object.

Required methods are:

    get(::MyRow)
    names(::Type{MyRow}) (should be `@pure`)

and a constructor that takes a tuple of data (in the same order as names). You
may also wish to define a pure function for

    TypedTables.row_type{R<:MyRow,N}(::Type{R}, names::NTuple{N,Symbol})
"""

abstract AbstractRow

@inline Base.names{R<:AbstractRow}(::R) = names(R)
@inline eltypes{R<:AbstractRow}(::R) = eltypes(R)
@inline eltypes{R<:AbstractRow}(::Type{R}) = Core.Inference.return_type(get, Tuple{R})

@inline Base.convert{R<:AbstractRow}(::Type{R}, row::AbstractRow) = R(get(row))
@inline rename{R<:AbstractRow, Names}(row::R, ::Type{Val{Names}}) = row_type(R, Names)(get(row))
@generated function rename{OldName, NewName}(row::AbstractRow, ::Type{Val{OldName}}, ::Type{Val{NewName}})
    j = [nameindex(names(row), OldName)...]

    new_names = [names(row)...]
    new_names[j] = NewName
    new_names = (new_names...)

    return :(row_type($row, $new_names)(get(row)))
end

@inline nrow{R<:AbstractRow}(::R) = nrow(R)
@inline ncol{R<:AbstractRow}(::R) = ncol(R)
@inline Base.length{R<:AbstractRow}(::R) = length(R)

@pure nrow{R<:AbstractRow}(::Type{R}) = 1
@pure ncol{R<:AbstractRow}(::Type{R}) = length(names(R))
@pure Base.length{R<:AbstractRow}(::Type{R}) = 1

@generated function Base.getindex{Name}(row::AbstractRow, ::Type{Val{Name}})
    ns = names(row)
    if isa(Name, Symbol)
        j = nameindex(ns, Name)

        return quote
            $(Expr(:meta, :inline))
            get(row)[$j]
        end
    elseif isa(Name, Tuple{Vararg{Symbol}})
        inds = nameindex(ns, Name)
        exprs = [:(data[$(inds[j])]) for j = 1:length(inds)]
        return quote
            $(Expr(:meta, :inline))
            data = get(row)
            $(Expr(:call, row_type(row, Name), Expr(:tuple, exprs...)))
        end
    else
        str = "Can't get column(s) named $Name"
        return :(error($str))
    end
end


@generated function Base.:(==)(row1::AbstractRow, row2::AbstractRow)
    if !similarnames(row1, row2)
        return false
    elseif ncol(row1) == 0
        return true
    end

    order = names_perm(row1, row2)
    expr = :( data1[$(order[1])] == data2[1] )
    for j = 2:ncol(row1)
        expr = Expr(:call, :(&), expr, :( data1[$(order[j])] == data2[$j] ))
    end

    return quote
        $(Expr(:meta, :inline))
        data1 = get(row1)
        data2 = get(row2)
        $expr
    end
end

@generated function Base.isapprox(row1::AbstractRow, row2::AbstractRow; kwargs...)
    if !similarnames(row1, row2)
        return false
    elseif ncol(row1) == 0
        return true
    end

    order = names_perm(row1, row2)
    expr = :( isapprox(data1[$(order[1])], data2[1]) )
    for j = 2:ncol(row1)
        expr = Expr(:call, :(&), expr, :( isapprox(data1[$(order[j])], data2[$j], kwargs...) ))
    end

    return quote
        $(Expr(:meta, :inline))
        data1 = get(row1)
        data2 = get(row2)
        $expr
    end
end


@inline Base.endof(::AbstractRow) = 1

Base.start(r::AbstractRow) = false
Base.next(r::AbstractRow, state) = (r, true)
Base.done(r::AbstractRow, state) = state

Base.getindex(r::AbstractRow) = r
Base.getindex(r::AbstractRow, i::Integer) = i == 1 ? r : error("Cannot index Row at $i")
Base.getindex(r::AbstractRow, ::Colon) = r

@generated function permutecols{Names}(r::AbstractRow, ::Type{Val{Names}})
    ns = names(r)
    if ns == Names
        return :(r)
    else
        if !(isa(Names, Tuple)) || eltype(Names) != Symbol || length(Names) != length(ns) || length(Names) != length(unique(Names))
            str = "New column names $Names do not match existing names $ns"
            return :(error($str))
        end

        order = names_perm(ns, Names)

        exprs = [:(data[$(order[j])]) for j = 1:length(Names)]
        return quote
            $(Expr(:meta, :inline))
            data = get(r)
            $(Expr(:call, row_type(r, Names), Expr(:tuple, exprs...)))
        end
    end
end


# Horizontally concatenate cells and rows into rows
Base.hcat(c::AbstractCell) = row_type(typeof(c))((get(c),))
Base.hcat(r::AbstractRow) = r

@generated function Base.hcat(r1::Union{AbstractCell,AbstractRow}, r2::Union{AbstractCell,AbstractRow})
    names1 = (r1 <: Cell ? (name(r1),) : names(r1))
    names2 = (r2 <: Cell ? (name(r2),) : names(r2))

    if length(intersect(names1, names2)) != 0
        str = "Column names are not distinct. Got $names1 and $names2"
        return :(error($str))
    end

    newnames = (names1..., names2...)
    exprs = vcat([:(data1[$j]) for j = 1:length(names1)], [:(data2[$j]) for j = 1:length(names2)])

    return quote
        $(Expr(:meta, :inline))
        data1 = get(r1)
        data2 = get(r2)
        $(Expr(:call, Row{newnames}, Expr(:tuple, exprs...)))
    end
end

@inline Base.hcat(r1::Union{AbstractCell,AbstractRow}, r2::Union{AbstractCell,AbstractRow}, rs::Union{AbstractCell,AbstractRow}...) = hcat(hcat(r1, r2), rs...)

@generated function Base.copy(r::AbstractRow)
    exprs = [:(copy(data[$j])) for j = 1:ncol(r)]
    return quote
        $(Expr(:meta, :inline))
        data = get(r)
        $(Expr(:call, row_type(r), Expr(:tuple, exprs...)))
    end
end
