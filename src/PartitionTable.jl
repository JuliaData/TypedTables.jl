struct PartitionTable{Name, I, T, Data <: AbstractDictionary} <: AbstractDictionary{I, T}
    data::Data
end

keynames(t::DictTable) = (keyname(t),)

function PartitionTable{Name}(data::AbstractDictionary) where {Name}
    return PartitionTable{Name, NamedTuple{(Name, keynames(data)...), _merge_types(Tuple{keytype(data)}, Tuple{keytype(eltype(data))})}, NamedTuple{(Name, columnnames(data)...), _merge_types(Tuple{keytype(data)}, Tuple{eltype(eltype(data))})}, typeof(data)}(data)
end

@generated function _merge_types(::Type{T1}, ::Type{T2}) where {T1, T2}
    return :(Tuple{($((T1.parameters..., T2.parameters...)...))})
end

function keys(t)