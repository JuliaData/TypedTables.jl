"""
A dense table stores the data as a vector of row-tuples.
"""
immutable DenseTable{Index,DataTypes} <: AbstractTable{Index,DefaultKey()}
    data::Vector{Row{Index,DataTypes}}

    function DenseTable(data_in)
        check_row(Index,DataTypes)
        new(data_in)
    end
end

DenseTable{Index}(::Index) = DenseTable{Index,eltypes(Index)}(Vector{Row{Index,eltypes(Index)}}())
DenseTable{Index,DataTypes}(::Index,data::Vector{DataTypes}) = DenseTable{Index,DataTypes}(Vector{Row{Index,DataTypes}}(data))
# Constructor that takes index and seperate values
# Conversion between Dense and normal Tables??
DenseTable{Index,StorageTypes}(table::Table{Index,StorageTypes}) = DenseTable(Index,collect(zip(table.data...)))



Base.length{Index,DataTypes}(table::DenseTable{Index,DataTypes}) = length(table.data)
Base.size{Index,DataTypes}(table::DenseTable{Index,DataTypes}) = (length(Index),length(table.data))
Base.size{Index,DataTypes}(table::DenseTable{Index,DataTypes},i::Int) = i == 1 ? length(Index) : (i == 2 ? length(table.data) : error("Tables are two-dimensional"))
Base.eltype{Index,DataTypes}(table::DenseTable{Index,DataTypes}) = eltype(table.data)

Base.push!{Index,DataTypes}(table::DenseTable{Index,DataTypes},row::Row{Index,DataTypes}) = push!(table.data,row)
Base.push!{Index,DataTypes}(table::DenseTable{Index,DataTypes},data_in::DataTypes) = push!(table.data,Row{Index,DataTypes}(data_in))
Base.push!{Index,DataTypes}(table::DenseTable{Index,DataTypes},data_in...) = push!(table,Row{Index,DataTypes}((data_in...))) # TODO probably slow
Base.append!{Index,DataTypes}(table::DenseTable{Index,DataTypes},table_in::DenseTable{Index,DataTypes}) = append!(table.data,table_in.data)
Base.append!{Index,DataTypes}(table::DenseTable{Index,DataTypes},rows::Vector{Row{Index,DataTypes}}) = append!(table.data,rows)

# Some output
function Base.summary{Index,DataTypes}(io::IO,table::DenseTable{Index,DataTypes})
    println(io,"$(length(table.data[1]))-row DenseTable with columns $Index")
end

function Base.show{Index,DataTypes}(io::IO,table::DenseTable{Index,DataTypes})
    summary(io,table)
    show(io,table.data)
end
