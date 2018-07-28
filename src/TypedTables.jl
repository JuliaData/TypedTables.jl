#__precompile__()

module TypedTables

using SplitApplyCombine

using Base: @propagate_inbounds, OneTo, Fix2

export Table, columns, columnames

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