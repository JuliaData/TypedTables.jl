
"""
A dense key table stores the data as a single dictionary of row-tuples.
"""
immutable DenseKeyTable{Index,DataTypes,Key,KeyType} <: AbstractTable{Index,Key}
    data::Dict{KeyType,Row{Index,DataTypes}}

    function DenseKeyTable(data_in)
        check_row(Index,DataTypes)
        check_key(Key,KeyType)
        new(data_in)
    end
end
