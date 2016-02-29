# ======================================
#    Fields
# ======================================
abstract AbstractField


"The default key is a special field referring to the intrinsic row-number of a (keyless) table"
immutable DefaultKey <: AbstractField
end
Base.show(io::IO,::DefaultKey) = print(io,"Row::$Int")
@inline Base.eltype(::Type{DefaultKey}) = Int
@inline Base.eltype(::DefaultKey) = Int
@inline name(::Type{DefaultKey}) = :Row
@inline name(::DefaultKey) = :Row

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
    if Name == :Row
        return :(error("Field name 'Row' is reserved"))
    else
        return nothing
    end
end
check_field(Name,T) = error("Field name $Name must be a Symbol and type $T must be a DataType")

"Extract the type parameter of a Field"
@inline Base.eltype{Name,T}(::Type{Field{Name,T}}) = T
@inline Base.eltype{Name,T}(::Field{Name,T}) = T
"Extract the name parameter of a Field"
@inline name{Name,T}(::Type{Field{Name,T}}) = Name
@inline name{Name,T}(::Field{Name,T}) = Name
@inline Base.length{Name,T}(::Field{Name,T}) = 1 # seems to be defined for scalars in Julia

Base.show{Name,T}(io::IO,::Field{Name,T}) = print(io,"$Name::$T")

# Create a cell or column from a field
@generated function Base.call{Name,T1,T2}(::Field{Name,T1},x::T2)
    if T1 == T2 # T2 is a scalar, clearly... but we have excluded automatic conversion...
        return :(Cell{$(Field{Name,T1}()),$T1}(x))
    else # T2 is probably a storage container
        return :(Column{$(Field{Name,T1}()),$T2}(x))
    end
end

macro field(x)
    if x.head != :(::) || length(x.args) != 2
        error("Expecting expression of form @field(:name :: Type)")
    end
    return :(Tables.Field{$(Expr(:quote,x.args[1])),$(esc(x.args[2]))}())
end
