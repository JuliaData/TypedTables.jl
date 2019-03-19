module TypedTables

using Unicode
using Tables
using SplitApplyCombine

using Base: @propagate_inbounds, @pure, OneTo, Fix2
import Tables.columns, Tables.rows

export @Compute, @Select
export Table, FlexTable, columns, rows, columnnames, showtable

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

# The following code causes newer versions of Julia to hang in precompilation
# and the workaround should not be needed after JuliaLang/julia#30577 was
# merged.
if VERSION < v"1.2.0-DEV.291"
    # Workaround for JuliaLang/julia#29970
    let
        for n in 1:32
            Ts = [Symbol("T$i") for i in 1:n]
            xs = [:(x[$i]) for i in 1:n]
            NT = :(Core.NamedTuple{names, Tuple{$(Ts...)}})
            eval(quote
                $NT(x::Tuple{$(Ts...)}) where {names, $(Ts...)} = $(Expr(:new, NT, xs...))
            end)
        end
    end
end

include("properties.jl")
include("Table.jl")
include("FlexTable.jl")
include("columnops.jl")
include("show.jl")

end # module
