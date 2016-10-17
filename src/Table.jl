# ======================================
#    Tables
# ======================================

"""
A table stores columns of data accessible by their field names.
"""
immutable Table{Names, StorageTypes <: Tuple} <: AbstractTable
    data::StorageTypes

    function Table(data_in::Tuple)
        check_table(Val{Names}, StorageTypes)
        new(data_in)
    end
end

@generated function check_table{Names, Types}(::Type{Val{Names}}, ::Type{Types})
    if !isa(Names, Tuple) || eltype(Names) != Symbol || length(Names) != length(unique(Names))
        str = "Table parameter 1 (Names) is expected to be a tuple of unique symbols, got $Names"
        return :(error($str))
    end
    if :Row ∈ Names
        return :( error("Field name cannot be :Row") )
    end
    N = length(Names)
    if length(Types.parameters) != N || reduce((a,b) -> a | !isa(b, DataType), false, Types.parameters)
        str = "Table parameter 2 (Types) is expected to be a Tuple{} of $N DataTypes, got $Types"
        return :(error($str))
    end
    for j = 1:N
        if eltype(Types.parameters[j]) == Types.parameters[j]
            warn("Column :$(Names[j]) storage type $(Types.parameters[j]) doesn't appear to be a storage container")
        end
    end

    return nothing
end

# Convenience constructors

(::Type{Table{Names}}){Names}(data::Tuple) = Table{Names, typeof(data)}(data)

@generated function (::Type{Table{Names,StorageTypes}}){Names, StorageTypes <: Tuple}()
    exprs = [:($(StorageTypes.parameters[j])()) for j = 1:length(StorageTypes.parameters)]
    return quote
        $(Expr(:meta, :inline))
        $(Expr(:call, Table{Names, StorageTypes}, Expr(:tuple, exprs...)))
    end
end

@generated function (::Type{Table{Names,StorageTypes}}){Names, StorageTypes <: Tuple}(len::Integer)
    exprs = [:($(StorageTypes.parameters[j])(len)) for j = 1:length(StorageTypes.parameters)]
    return quote
        $(Expr(:meta, :inline))
        $(Expr(:call, Table{Names, StorageTypes}, Expr(:tuple, exprs...)))
    end
end

@generated function (::Type{Table{Names}}){Names, ElTypes <: Tuple}(::Type{ElTypes})
    exprs = [:($(storage_type(ElTypes.parameters[j]))()) for j = 1:length(ElTypes.parameters)]
    return quote
        $(Expr(:meta, :inline))
        $(Expr(:call, Table{Names}, Expr(:tuple, exprs...)))
    end
end

@generated function (::Type{Table{Names}}){Names, ElTypes <: Tuple}(::Type{ElTypes}, len::Integer)
    exprs = [:($(storage_type(ElTypes.parameters[j]))(len)) for j = 1:length(ElTypes.parameters)]
    return quote
        $(Expr(:meta, :inline))
        $(Expr(:call, Table{Names}, Expr(:tuple, exprs...)))
    end
end

@inline get(t::Table) = t.data

@inline Base.names{Names, Types}(::Type{Table{Names,Types}}) = Names
@inline Base.names{Names}(::Type{Table{Names}}) = Names

macro Table(exprs...)
    N = length(exprs)
    names = Vector{Any}(N)
    values = Vector{Any}(N)
    for i = 1:N
        expr = exprs[i]
        if expr.head != :(=) && expr.head != :(kw) # strange Julia bug, see issue 7669
            error("A Expecting expression like @Table(name1::Type1 = value1, name2::Type2 = value2) or @Table(name1 = value1, name2 = value2)")
        end
        if isa(expr.args[1],Symbol)
            names[i] = (expr.args[1])
            values[i] = esc(expr.args[2])
        elseif isa(expr.args[1],Expr)
            if expr.args[1].head != :(::) || length(expr.args[1].args) != 2
                error("A Expecting expression like @Table(name1::Type1 = value1, name2::Type2 = value2) or @Table(name1 = value1, name2 = value2)")
            end
            names[i] = (expr.args[1].args[1])
            values[i] = esc(Expr(:call, :convert, expr.args[1].args[2], expr.args[2]))
        else
            error("A Expecting expression like @Table(name1::Type1 = value1, name2::Type2 = value2) or @Table(name1 = value1, name2 = value2)")
        end
    end

    tabletype = TypedTables.Table{(names...)}
    return Expr(:call, tabletype, Expr(:tuple, values...))
end

#=

# Some old concept code for allowing different kinds of "keys" for indexing,
# e.g. like a Dict.

#"""
#AbstractTable{Index,Key} represents tables with a given set of indices (a
#FieldIndex) and a key (either one of the fields in FieldIndex, or else
#DefaultKey(), which represents the intrinsic row number of a table)
#"""
#abstract AbstractTable{Index,Key}
#@inline index{Index,Key}(::AbstractTable{Index,Key}) = Index
#@inline eltypes{Index,Key}(::AbstractTable{Index,Key}) = eltypes(Index)
#@inline Base.names{Index,Key}(::AbstractTable{Index,Key}) = names(Index)
#@inline key{Index,Key}(::AbstractTable{Index,Key}) = Key
#@inline Base.keytype{Index,Key}(::AbstractTable{Index,Key}) = eltype(Key)
#@inline keyname{Index,Key}(::AbstractTable{Index,Key}) = name(Key)


"This is a fake 'storage container' for the field DefaultKey() in a Table"
immutable TableKey{Index,ElTypes,StorageTypes}
    parent::Ref{Table{Index,ElTypes,StorageTypes}}
end
Base.getindex{Index,ElTypes,StorageTypes,T}(k::TableKey{Index,ElTypes,StorageTypes},i::T) = getindex(1:length(k.parent.x),i)
Base.length{Index,ElTypes,StorageTypes}(k::TableKey{Index,ElTypes,StorageTypes}) = length(k.parent.x)
Base.endof{Index,ElTypes,StorageTypes}(k::TableKey{Index,ElTypes,StorageTypes}) = endof(k.parent.x)
Base.eltype(k::TableKey) = Int
Base.eltype{Index,ElTypes,StorageTypes}(k::Type{TableKey{Index,ElTypes,StorageTypes}}) = Int
Base.first{Index,ElTypes,StorageTypes}(::TableKey{Index,ElTypes,StorageTypes},i::Int) = 1
Base.next{Index,ElTypes,StorageTypes}(::TableKey{Index,ElTypes,StorageTypes},i::Int) = (i, i+1)
Base.done{Index,ElTypes,StorageTypes}(k::TableKey{Index,ElTypes,StorageTypes},i::Int) = (i-1) == length(k.parent.x)
Base.show(io::IO,k::TableKey) = show(io::IO,1:length(k.parent.x))
Base.copy(k::TableKey) = 1:length(k)
=#
