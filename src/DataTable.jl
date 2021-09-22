

struct DataTable{N} <: AbstractArray{DataRow{N}, N}
    index::Dict{Symbol, Int}
    columns::Vector{Symbol}
    data::Vector{AbstractArray{<:Any, N}}
end

# Construction
DataTable(; kwargs...) = DataTable{_ndims(kwargs.data)}(; kwargs...)
DataTable(ts::AbstractArray{<:Any, N}...; kwargs...) where {N} = DataTable{N}(ts...; kwargs...)

function DataTable{N}(ts...; kwargs...) where {N}
    index = Dict{Symbol, Int}()
    colnames = Vector{Symbol}()
    data = Vector{AbstractArray{<:Any,N}}()

    for t in ts
        for (colname, column) in pairs(columns(t))
            token = Base.ht_keyindex2!(index, colname)
            if token < 0
                # Add a new column
                push!(colnames, colname)
                push!(data, column)
                Base._setindex!(index, length(colnames), colname, -token)
            else
                # Replace the column (merge)
                @inbounds data[index.vals[token]] = column
            end
        end
    end

    for (colname, column) in kwargs
        token = Base.ht_keyindex2!(index, colname)
        if token < 0
            # Add a new column
            push!(colnames, colname)
            push!(data, column)
            Base._setindex!(index, length(colnames), colname, -token)
        else
            if column === nothing
                # Delete the column
                col_i = @inbounds index.vals[token]
                deleteat!(colnames, col_i)
                deleteat!(data, col_i)
                Base._delete!(index, token)
            else
                # Replace the column (merge)
                @inbounds data[index.vals[token]] = column
            end
        end
    end

    DataTable{N}(index, colnames, data)
end

# Conversion between other table types
Table(t::DataTable) = Table(NamedTuple(columns(t)))
FlexTable(t::DataTable) = Table(NamedTuple(columns(t)))

# Column names are a vector, in this case
columnnames(t::DataTable) = getfield(t, :columns)

# Basic access interface
Base.IndexStyle(::Type{<:DataTable}) = Base.IndexLinear()
@inline function Base.getindex(t::DataTable{N}, i::Int) where {N}
    # Check bounds here once during row construction, rather than during each cell access.
    @boundscheck checkbounds(getfield(t, :data)[1], i)
    return DataRow{N}(getfield(t, :index), getfield(t, :columns), getfield(t, :data), i)
end
Base.length(t::DataTable) = length(first(getfield(t, :data)))
Base.size(t::DataTable) = size(first(getfield(t, :data)))
Base.axes(t::DataTable) = axes(first(getfield(t, :data)))

function Base.getproperty(t::DataTable, s::Symbol)
    col_i = t.index[s]
    return @inbounds t.data[col_i]
end

# Tables.jl interface
Tables.istable(::Type{<:DataTable}) = true
Tables.rowaccess(::Type{<:DataTable}) = true 
Tables.columnaccess(::Type{<:DataTable}) = true
Tables.schema(t::DataTable) = Tables.Schema(getfield(t, :colnames), map(eltype, getfield(t, :data)))
Tables.materializer(::DataTable{N}) where {N} = Table  # Currently, all the Tables.jl stuff quickly becomes fully-typed... probably a bad idea!

"""
    columns(table::DataTable)

Convert a `DataTable` into `NamedTuple` of it's columns.
"""
@inline Tables.columns(t::DataTable) = NamedTuple{Tuple(getfield(t, :colnames))}(Tuple(getfield(t, :data))) # ??

@inline Tables.rows(t::DataTable) = Table(columns(t)) # ??

# show
Base.show(io::IO, ::MIME"text/plain", t::DataTable) = showtable(io, t)
Base.show(io::IO, t::DataTable) = showtable(io, t)