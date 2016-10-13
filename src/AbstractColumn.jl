"""
    abstract AbstractColumn

In the context of data tables, a column is a single collection of data annotated
by a column (or field) name. This is an abstract type that defines the interface
necessary for a type to be a valid *TypedTables* column object.

Required methods are:

    get(::Column)
    name(::Type{Column}) (should be `@pure`)
"""
abstract AbstractColumn

@inline name{C<:AbstractColumn}(::C) = name(C)
@inline Base.eltype{C<:AbstractColumn}(::C) = eltype(C)
@inline Base.eltype{C<:AbstractColumn}(::Type{C}) = eltype(Core.Inference.return_type(get, Tuple{C}))
@inline storagetype{C<:AbstractColumn}(::C) = storagetype(C)
@inline storagetype{C<:AbstractColumn}(::Type{C}) = Core.Inference.return_type(get, Tuple{C})

@inline Base.convert{C<:AbstractColumn}(::Type{C}, col::AbstractColumn) = C(get(col))
@inline rename{C<:AbstractColumn, Name}(x::C, ::Type{Val{Name}}) = column_type(C, Name)(get(x))
# TODO: 3 argument rename?
Base.copy{C<:AbstractColumn}(col::C) = C(copy(get(col)))

@inline nrow{C<:AbstractColumn}(c::C) = length(get(c))
@inline ncol{C<:AbstractColumn}(::C) = ncol(C)
@inline Base.length{C<:AbstractColumn}(c::C) = length(get(c))

@pure ncol{C<:AbstractColumn}(::Type{C}) = 1

@generated function Base.getindex{C<:AbstractColumn, Name}(c::C, ::Type{Val{Name}})
    if name(C) == Name
        return quote
            @_inline_meta
            get(c)
        end
    else
        error("Tried to index column of field name :$(name(C)) with field name :$Name")
    end
end

Base.start(c::AbstractColumn) = start(get(c))
Base.next(c::AbstractColumn, i) = next(get(c), i)
Base.done(c::AbstractColumn, i) = done(get(c), i)
Base.endof(c::AbstractColumn) = endof(get(c))
Base.ndims(col::AbstractColumn) = 1
Base.isempty(col::AbstractColumn) = isempty(get(col))

# get/set index
@inline Base.getindex(col::AbstractColumn, idx::Int) = getindex(get(col), idx)
@inline Base.getindex{C <: AbstractColumn}(col::C, idx) = C(getindex(get(col), idx))

@inline Base.setindex!(col::AbstractColumn, val, idx) = setindex!(get(col), val, idx)
@generated function Base.setindex!(col::AbstractColumn, val::AbstractCell, idx::Integer)
    if name(col) == name(val)
        return quote
            @_inline_meta
            setindex!(get(col), get(val), idx)
        end
    else
        error("Tried to set index column of field name :$(name(col)) with field name :$(name(val))")
    end
end
@generated function Base.setindex!(col::AbstractColumn, val::AbstractColumn, idx)
    if name(col) == name(val)
        return quote
            @_inline_meta
            setindex!(get(col), get(val), idx)
        end
    else
        error("Tried to set index column of field name :$(name(col)) with field name :$(name(val))")
    end
end


# Mutators: push!, append!, pop!, etc
Base.pop!(col::AbstractColumn) = pop!(get(col))
Base.shift!(col::AbstractColumn) = shift!(get(col))

Base.push!(col::AbstractColumn, data_in) = (push!(get(col), data_in); col)
@generated function Base.push!(col::AbstractColumn, val::AbstractCell)
    if name(col) == name(val)
        return quote
            @_inline_meta
            push!(get(col), get(val))
        end
    else
        error("Column with name :$(name(col)) doesn't match cell with name :$(name(val))")
    end
end

Base.unshift!(col::AbstractColumn, data_in) = (unshift!(get(col), data_in); col)
@generated function Base.unshift!(col::AbstractColumn, val::AbstractCell)
    if name(col) == name(val)
        return quote
            @_inline_meta
            unshift!(get(col), get(val))
        end
    else
        error("Column with name :$(name(col)) doesn't match cell with name :$(name(val))")
    end
end

Base.append!(col::AbstractColumn, data_in) = (append!(get(col), data_in); col)
@generated function Base.append!(col::AbstractColumn, val::AbstractColumn)
    if name(col) == name(val)
        return quote
            @_inline_meta
            append!(get(col), get(val))
        end
    else
        error("Column with name :$(name(col)) doesn't match column with name :$(name(val))")
    end
end

Base.prepend!(col::AbstractColumn, data_in) = (prepend!(get(col), data_in); col)
@generated function Base.prepend!(col::AbstractColumn, val::AbstractColumn)
    if name(col) == name(val)
        return quote
            @_inline_meta
            prepend!(get(col), get(val))
        end
    else
        error("Column with name :$(name(col)) doesn't match column with name :$(name(val))")
    end
end

Base.insert!(col::AbstractColumn, i::Integer, v) = (insert!(get(col), i, v); col)
@generated function Base.insert!(col::AbstractColumn, i::Integer, val::AbstractCell)
    if name(col) == name(val)
        return quote
            @_inline_meta
            insert!(get(col), i, get(val))
        end
    else
        error("Column with name :$(name(col)) doesn't match cell with name :$(name(val))")
    end
end

Base.deleteat!(col::AbstractColumn, i) = (deleteat!(get(col), i); col)

Base.splice!(col::AbstractColumn, i::Integer) = splice!(get(col), i)
Base.splice!(col::AbstractColumn, i::Integer, r) = splice!(get(col), i, r)
@generated function Base.splice!(col::AbstractColumn, i::Integer, val::Union{AbstractCell, AbstractColumn})
    if name(col) == name(val)
        return quote
            @_inline_meta
            splice!(get(col), i, get(val))
        end
    else
        error("Column with name :$(name(col)) doesn't match cell with name :$(name(val))")
    end
end

Base.splice!{C<:AbstractColumn}(col::C, i) = C(splice!(get(col), i))
@generated function Base.splice!{C<:AbstractColumn}(col::C, i::Integer, val::Union{AbstractCell, AbstractColumn})
    if name(col) == name(val)
        return quote
            @_inline_meta
            C(splice!(get(col), i, get(val)))
        end
    else
        error("Column with name :$(name(col)) doesn't match cell with name :$(name(val))")
    end
end

Base.empty!(col::AbstractColumn) = (empty!(get(col)); col)

# unique/unique! (union, etc??)

@inline Base.sort{C<:AbstractColumn}(col::C; kwargs...) = C(sort(get(col); kwargs...))
@inline Base.sort!(col::AbstractColumn; kwargs...) = (sort!(get(col); kwargs...); col)

# Concatenate cells and columns into columns
Base.vcat(col::AbstractColumn) = col
Base.vcat(c::AbstractCell) = column_type(typeof(c))(vcat(get(c)))
function Base.vcat(c1::Union{AbstractCell, AbstractColumn}, c2::Union{AbstractCell, AbstractColumn})
    column_type(typeof(c1))(vcat(get(c1), get(c2)))
end
@generated function Base.vcat(c1::Union{AbstractCell, AbstractColumn}, c2::Union{AbstractCell, AbstractColumn}, cs::Union{AbstractCell, AbstractColumn}...)
    # Do our best to help inference here
    exprs = [:(cs[$j].data) for j = 1:length(cs)]
    vcat_expr = Expr(:call, :vcat, :(get(c1)), :(get(c2)), exprs...)
    return quote
        $(Expr(:meta, :inline))
        $(Expr(:call, column_type(c1), vcat_expr))
    end
end

@generated function Base.:(==){C1<:AbstractColumn, C2<:AbstractColumn}(col1::C1, col2::C2)
    if name(C1) == name(C2)
        return quote
            @_inline_meta
            get(col1) == get(col2)
        end
    else
        return quote
            @_pure_meta
            false
        end
    end
end

@generated function Base.isapprox{C1<:AbstractColumn, C2<:AbstractColumn}(col1::C1, col2::C2; kwargs...)
    if name(C1) == name(C2)
        return quote # Do elementwise approximation not linear-algebra style
            @_inline_meta
            all(map((val1,val2)->isapprox(val1, val2; kwargs...), get(col1), get(col2)))
        end
    else
        return quote
            @_pure_meta
            false
        end
    end
end
