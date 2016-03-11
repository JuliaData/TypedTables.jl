
"""
A key table stores the data as a set of dictionaries for each field.
"""
immutable KeyTable{Index,StorageTypes,Key,KeyType} <: AbstractTable{Index,Key}
    data::Dict{KeyType,StorageTypes}

    function KeyTable(data_in)
        check_table(Index,StorageTypes)
        check_key(Key,KeyType)
        new(data_in)
    end
end

@generated check_key{Key,KeyType}(::Key,::Type{KeyType}) = (eltype(Key()) == KeyType) ? (return nothing) : (str = "KeyType $KeyType doesn't match Key $Key"; return :(error(str)))
