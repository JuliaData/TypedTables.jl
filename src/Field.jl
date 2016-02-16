# ======================================
#    Fields
# ======================================
abstract AbstractField

"The default key is a special field referring to the intrinsic row-number of a (keyless) table"
immutable DefaultKey <: AbstractField
end
Base.show(io::IO,::DefaultKey) = print(io,"Default:$Int")
@inline eltype(::Type{DefaultKey}) = Int
@inline eltype(::DefaultKey) = Int
@inline name(::Type{DefaultKey}) = :Default
@inline name(::DefaultKey) = :Default


"""
A Field{Name,T}() is a singleton defining a name (as a symbol) and a data type.
"""
immutable Field{Name,T} <: AbstractField
    function Field()
        check_field(Val{Name},T)
        new{Name,T}()
    end
end

@generated function check_field{Name,T}(::Type{Val{Name}},::Type{T})
    if Name == :Default
        return :(error("Field name 'Default' is reserved"))
    else
        return nothing
    end
end
check_field(Name,T) = error("Field name $Name must be a Symbol and type $T must be a DataType")

"Extract the type parameter of a Field"
@inline eltype{Name,T}(::Type{Field{Name,T}}) = T
@inline eltype{Name,T}(::Field{Name,T}) = T
"Extract the name parameter of a Field"
@inline name{Name,T}(::Type{Field{Name,T}}) = Name
@inline name{Name,T}(::Field{Name,T}) = Name
@inline Base.length{Name,T}(::Field{Name,T}) = 1 # seems to be defined for scalars in Julia

Base.show{Name,T}(io::IO,::Field{Name,T}) = print(io,"$Name:$T")
