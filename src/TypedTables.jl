module TypedTables

using Tables
using SplitApplyCombine

using Base: @propagate_inbounds, OneTo, Fix2
import Tables.columns, Tables.rows

export Table, columns, rows, columnames

# GetProperty
struct GetProperty{name}
end
@inline GetProperty(name::Symbol) = GetProperty{name}()

@inline function Base.getproperty(sym::Symbol)
	return GetProperty(sym)
end

@inline (::GetProperty{name})(x) where {name} = getproperty(x, name)

# Resultant element type of given column arrays
@generated function _eltypes(a::NamedTuple{names, T}) where {names, T <: Tuple{Vararg{AbstractArray}}}
    Ts = []
    for V in T.parameters
        push!(Ts, eltype(V))
    end
    return NamedTuple{names, Tuple{Ts...}}
end

_ndims(a::NamedTuple{<:Any, T}) where {T} = _ndims(T)
_ndims(::Type{<:Tuple{Vararg{AbstractArray{<:Any, n}}}}) where {n} = n

include("Table.jl")
include("columnops.jl")

end # module