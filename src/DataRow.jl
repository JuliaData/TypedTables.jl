"""
    DataRow(index, colnames, data, i)

A `DataRow` is used as a reference to a row of a `DataTable`. It behaves similary to a
`NamedTuple`, except relies on a dynamic hash map and dynamic typing, and supports mutation
(which mutates the parent `DataTable`).
"""
struct DataRow{N}
    index::Dict{Symbol, Int}
    colnames::Vector{Symbol}
    data::Vector{AbstractArray{<:Any, N}}
    i::Int # Assume DataTable is IndexLinear...
end

# Interface like a NamedTuple
function Base.getproperty(r::DataRow, s::Symbol)
    col_i = getfield(r, :index)[s]
    return @inbounds getfield(r, :data)[col_i][getfield(r, :i)] # We have already checked bounds of r.i
end
Base.propertynames(r::DataRow) = getfield(r, :colnames)

@inline Base.getindex(r::DataRow, s::Symbol) = getproperty(r, s)
@inline Base.iterate(r::DataRow, s...) = iterate(r.data, s...)
@inline Base.length(r::DataRow) = length(getfield(r, :data))
@inline Base.keys(r::DataRow) = getfield(r, :data)
@inline Base.haskey(r::DataRow, s::Symbol) = haskey(getfield(r, :index), s::Symbol)
@inline Base.pairs(r::DataRow) = zip(getfield(r, :colnames), getfield(r, :data))

# We can mutate the elements by mutating the DataTable
function Base.setproperty!(r::DataRow, s::Symbol, v)
    col_i = getfield(r, :index)[s]
    @inbounds getfield(r, :data)[col_i][getfield(r, :i)] = v
    return r
end
@inline Base.setindex!(r::DataRow, v, s::Symbol) = setproperty!(r, s, v)

# Can convert to a NamedTuple
NamedTuple(r::DataRow) = NamedTuple{Tuple(getfield(r, :colnames))}(Tuple(map(x -> getindex(x, getfield(r, :i)), getfield(r, :data))))

# show
# TODO this printing should probably only be the "compact" form, otherwise maybe we should
# differentiate a bit from NamedTuple?
Base.show(io::IO, t::DataRow) = show(io, MIME"text/plain"(), r)
function Base.show(io::IO, ::MIME"text/plain", r::DataRow)
    colnames = getfield(r, :colnames)
    data = getfield(r, :data)
    index = getfield(r, :i)
    print(io, "(")
    for (i, colname) in enumerate(colnames)
        print(io, colname)
        print(io, " = ")
        print(io, data[i][index])
        if i == 1 || i < length(data)
            print(io, ", ")
        end
    end
    print(io, ")")
end
