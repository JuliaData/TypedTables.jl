
"""
A Column is a vector (or similar store) of data annotated by a column name
"""
immutable Column{Name, StorageType} <: AbstractColumn
    data::StorageType
    function Column{T}(x::T)
        check_Column(Val{Name}, StorageType)
        new(convert(StorageType, x))
    end
end

@inline (::Type{Column{Name}}){Name, StorageType}(x::StorageType) = Column{Name, StorageType}(x)

# Some convenience constructors
@inline (::Type{Column{Name,StorageType}}){Name, StorageType}() = Column{Name, StorageType}(StorageType())
@inline (::Type{Column{Name,StorageType}}){Name, StorageType}(len::Integer) = Column{Name, StorageType}(StorageType(len))

@inline (::Type{Column{Name}}){Name, T}(::Type{T}) = Column{Name}(storage_type(T)())
@inline (::Type{Column{Name}}){Name, T}(::Type{T}, len::Integer) = Column{Name}(storage_type(T)(len))

@generated function check_Column{Name, StorageType}(::Type{Val{Name}}, ::Type{StorageType})
    if !isa(Name, Symbol)
        return :( error("Field name $Name should be a Symbol") )
    elseif Name == :Row
        return :( error("Field name cannot be :Row") )
    elseif eltype(StorageType) == StorageType
        warn("Column :$Name storage type $StorageType doesn't appear to be a storage container")
    end
    return nothing
end

@inline Base.get(c::Column) = c.data
@pure name{Name}(::Type{Column{Name}}) = Name
@pure name{Name, StorageType}(::Type{Column{Name, StorageType}}) = Name

# @Column and @Cell are very similar
macro Column(expr)
    if expr.head != :(=) && expr.head != :(kw) # strange Julia bug, see issue 7669
        error("A Expecting expression like @Column(name::Type = value) or @Column(name = value)")
    end
    local field
    value = expr.args[2]
    if isa(expr.args[1], Symbol)
        name = expr.args[1]
        return :( TypedTables.Column{$(QuoteNode(name))}($(esc(value))) )
    elseif isa(expr.args[1],Expr)
        if expr.args[1].head != :(::) || length(expr.args[1].args) != 2 || !isa(expr.args[1].args[1], Symbol)
            error("B Expecting expression like @Column(name::Type = value) or @Column(name = value)")
        end
        name = expr.args[1].args[1]
        eltype = expr.args[1].args[2]
        field = :( TypedTables.Column{$(QuoteNode(name)), $(esc(eltype))}($(esc(value))) )
    else
        error("C Expecting expression like @Column(name::Type = value) or @Column(name = value)")
    end
end

similar_type{C<:AbstractCell}(::C, ::Type{AbstractColumn}) = Column{name(C), eltype(C)} # default AbstractColumn type
