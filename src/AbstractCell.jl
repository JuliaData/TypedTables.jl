
"""
    abstract AbstractCell

In the context of data tables, a cell is a single piece of data annotated by a
column (or field) name. This is an abstract type that defines the interface
necessary for a type to be a valid *TypedTables* cell object.

Required methods are:

    get(::Cell)
    name(::Type{Cell}) (should be `@pure`)
"""
abstract AbstractCell

@inline name{C<:AbstractCell}(::C) = name(C)
@inline Base.eltype{C<:AbstractCell}(::C) = eltype(C)
@inline Base.eltype{C<:AbstractCell}(::Type{C}) = Core.Inference.return_type(get, Tuple{C})

@inline nrow{C<:AbstractCell}(::C) = nrow(C)
@inline ncol{C<:AbstractCell}(::C) = ncol(C)
@inline Base.length{C<:AbstractCell}(::C) = length(C)

@pure nrow{C<:AbstractCell}(::Type{C}) = 1
@pure ncol{C<:AbstractCell}(::Type{C}) = 1
@pure Base.length{C<:AbstractCell}(::Type{C}) = 1

@generated function Base.getindex{C<:AbstractCell, Name}(c::C, ::Type{Val{Name}})
    if name(C) == Name
        return quote
            @_inline_meta
            get(c)
        end
    else
        error("Tried to index cell of field name :$(name(C)) with field name :$Name")
    end
end

Base.start(c::AbstractCell) = false # Similar iterators as Julia scalars
Base.next(c::AbstractCell, i::Bool) = (get(c), true)
Base.done(c::AbstractCell, i::Bool) = i
Base.endof(c::AbstractCell) = 1

Base.getindex(c::AbstractCell) = get(c)
Base.getindex(c::AbstractCell, i::Integer) = ((i == 1) ? get(c) : throw(BoundsError())) # This matches the behaviour of other scalars in Julia
Base.getindex(c::AbstractCell, ::Colon) = c

@generated function Base.:(==){C1<:AbstractCell, C2<:AbstractCell}(c1::C1, c2::C2)
    if name(C1) == name(C2)
        return quote
            @_inline_meta
            get(c1) == get(c2)
        end
    else
        return quote
            @_pure_meta
            false
        end
    end
end

@generated function Base.isapprox{C1<:AbstractCell, C2<:AbstractCell}(c1::C1, c2::C2; kwargs...)
    if name(C1) == name(C2)
        return quote
            @_inline_meta
            isapprox(get(c1), get(c2); kwargs...)
        end
    else
        return quote
            @_pure_meta
            false
        end
    end
end

Base.copy{C<:AbstractCell}(c::C) = C(copy(get(c)))

@inline Base.convert{C1<:AbstractCell, C2<:AbstractCell}(::Type{C1}, cell::C2) = C1(get(cell))
@inline rename{C<:AbstractCell, Name}(x::C, ::Type{Val{Name}}) = cell_type(C, Name)(get(x))
