# ======================================
#    Tables
# ======================================

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

"""
A table stores columns of data accessible by their field names.
"""
immutable Table{Names, StorageTypes <: Tuple} #<: AbstractTable{Index,DefaultKey()}
    data::StorageTypes

    function (::Type{Table{Names, StorageTypes}}){Names, StorageTypes <: Tuple}(data_in::Tuple, check_sizes::Type{Val{true}} = Val{true})
        check_table(Val{Names}, StorageTypes)
        ls = map(length, data_in)
        for i in 2:length(data_in)
            if ls[i] != ls[1]
                error("Column inputs must be same length.")
            end
        end
        new{Names, StorageTypes}(data_in)
    end

    function (::Type{Table{Names, StorageTypes}}){Names, StorageTypes}(data_in::Tuple, check_sizes::Type{Val{false}})
        check_table(Val{Names}, StorageTypes)
        new{Names, StorageTypes}(data_in)
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

@compat @generated function (::Type{Table{Names}}){Names, CheckSizes}(data::Tuple, ::Type{Val{CheckSizes}} = Val{true})
    if !isa(Names, Tuple) || eltype(Names) != Symbol || length(Names) != length(unique(Names))
        str = "Table parameter 1 (Names) is expected to be a tuple of unique symbols, got $Names"
        return :(error($str))
    end

    if length(Names) == length(data.parameters)
        return quote
            $(Expr(:meta,:inline))
            Table{Names, $data}(data, Val{CheckSizes})
        end
    else
        return :(error("Can't construct Table with $(length(Names)) columns with input $data"))
    end
end

@compat @generated function (::Type{Table{Names,StorageTypes}}){Names, StorageTypes <: Tuple}()
    exprs = [:($(StorageTypes.parameters[j])()) for j = 1:length(Names)]
    return Expr(:call, Table{Names, StorageTypes}, Expr(:tuple, exprs...))
end


# TODO think about conversions...
@compat (::Type{Table{Names,Types_new}}){Names, Types, Types_new}(t::Table{Names,Types}) = convert(Table{Names,Types_new}, t)

@generated function Base.convert{Names, Names_new, Types, Types_new <: Tuple}(::Type{Table{Names_new,Types_new}}, t::Table{Names,Types})
    if !isa(Names_new, Tuple) || eltype(Names_new) != Symbol || length(Names_new) != length(Names) || length(Names_new) != length(unique(Names_new))
        str = "Cannot convert $(length(Names)) columns to new names $(Names_new)."
        return :(error($str))
    end
    if length(Types_new.parameters) != length(Types.parameters)
        str = "Cannot convert $(length(Types.pareters)) columns to $(length(Types_new.parameters)) new types."
        return :(error($str))
    end
    exprs = [:(convert(Types_new.parameters[$j], t.data[$j])) for j = 1:length(Names)]
    return Expr(:call, Table{Names_new,Types_new}, Expr(:tuple, exprs...), Val{false})
end

@compat Base.:(==){Names, Types1, Types2}(table1::Table{Names, Types1}, table2::Table{Names, Types2}) = (table1.data == table2.data)
@compat @generated function Base.:(==){Names1, Types1, Names2, Types2}(table1::Table{Names1,Types1}, table2::Table{Names2,Types2})
    try
        order = permutator(Names1, Names2)
        expr = :( table1.data[$(order[1])] == table2.data[1] )
        for j = 2:length(Names1)
            expr = Expr(:call, :(&), expr, :( table1.data[$(order[j])] == table2.data[$j] ))
        end
        return expr
    catch
        return false
    end
end

rename{Names, NewNames}(table::Table{Names}, ::Type{Val{NewNames}}) = Table{NewNames}(table.data)

@generated function rename{Names, OldName, NewName}(t::Table{Names}, ::Type{Val{OldName}}, ::Type{Val{NewName}})
    j = columnindex(Names, OldName)

    NewNames = [Names...]
    NewNames[j] = NewName
    NewNames = (NewNames...)

    return :(Table{$NewNames}(t.data, Val{false}))
end

@inline Base.names{Names}(::Table{Names}) = Names
@inline Base.names{Names, Types <: Tuple}(::Type{Table{Names,Types}}) = Names
@inline Base.names{Names}(::Type{Table{Names}}) = Names
@generated function eltypes{Names, Types}(::Union{Table{Names,Types}, Type{Table{Names,Types}}})
    elem_types = map(eltype, Types.parameters)
    quote
        $(Expr(:meta, :inline))
        $(Expr(:curly, :Tuple, elem_types...))
    end
end
@inline storagetypes{Names, Types <: Tuple}(::Table{Names,Types}) = Types
@inline storagetypes{Names, Types <: Tuple}(::Type{Table{Names,Types}}) = Types

@inline nrow(t::Table) = length(t.data[1])
@inline ncol{Names}(::Table{Names}) = length(Names)
@inline ncol{Names,Types}(::Type{Table{Names,Types}}) = length(Names)
@inline ncol{Names}(::Type{Table{Names}}) = length(Names)

#############################################################################
# Indexing columns
#############################################################################
@generated function Base.getindex{Names, GetName}(t::Table{Names}, ::Type{Val{GetName}})
    if isa(GetName, Symbol)
        if GetName == :Row
            return quote
                $(Expr(:meta, :inline))
                1:nrow(t)
            end
        end

        j = columnindex(Names, GetName)

        return quote
            $(Expr(:meta, :inline))
            t.data[$j]
        end
    elseif isa(GetName, Tuple)
        inds = columnindex(Names, GetName)
        exprs = [:(t.data[$(inds[j])]) for j = 1:length(inds)]
        expr = Expr(:call, Table{GetName}, Expr(:tuple, exprs...))

        return quote
            $(Expr(:meta, :inline))
            $expr
        end
    else
        str = "Can't get column(s) named $Name"
        return :(error($str))
    end
end


#############################################################################
# iterating over rows
#############################################################################

# TODO don't assume all containers are compatible with each other... (e.g. different implementations of dictionaries).
# Probably should define some kind of table key for this

# TODO very strong assumption about columns being of same length. Probably
# should check in start? And hope the user doesn't change the column sizes
# differently? Or do the safe thing and get the user to wrap it in @inbounds??

Base.start(t::Table) = 1
@generated function Base.next{Names}(t::Table{Names}, state)
    exprs = [:(Base.unsafe_getindex(t.data[$i],state)) for i = 1:length(Names)]
    return Expr(:tuple, Expr(:call, Row{Names}, Expr(:tuple, exprs...)), :(state + 1))
end
Base.done(t::Table, state) = state > nrow(t)


#############################################################################
# indexing rows
#############################################################################

@inline Base.length(t::Table) = nrow(t)
@inline Base.endof(t::Table) = nrow(t)
@inline Base.size(t::Table) = (nrow(t),)
@inline Base.size(t::Table, i::Integer) = i == 1 ? nrow(t) : error("Tables are one-dimensional storage containers of Rows. Consider using `ncol()`")
@inline Base.ndims(t::Table) = 1
@inline Base.isempty(t::Table) = isempty(t.data[1])

# head/tail
function head(t::Table, n = 5)
    if nrow(t) <= n
        return t
    else
        return t[1:n]
    end
end

function tail(t::Table, n = 5)
    if nrow(t) <= n
        return t
    else
        return t[end-n+1:end]
    end
end


@generated function Base.getindex{Names}(t::Table{Names}, i::Integer)
    exprs = [:(getindex(t.data[$c], i)) for c = 1:length(Names)]
    return Expr(:call, Row{Names}, Expr(:tuple, exprs...))
end
@generated function Base.getindex{Names}(t::Table{Names}, inds)
    exprs = [:(getindex(t.data[$c], inds)) for c = 1:length(Names)]
    return Expr(:call, Table{Names}, Expr(:tuple, exprs...))
end
Base.getindex{Names}(t::Table{Names}, ::Colon) = t

@generated function Base.setindex!{Names1,Names2}(t::Table{Names1}, v::Row{Names2}, i::Integer)
    if Names1 == Names2
        exprs = [:(setindex!(t.data[$c], v.data[$c], i)) for c = 1:length(Names1)]
        return Expr(:block, exprs...)
    else
        if length(Names1) != length(Names2)
            str = "Cannot assign $(length(v.parameters)) columns to $(length(Names)) columns"
            return :(error($str))
        end

        order = permutator(Names1, Names2)
        exprs = [:(setindex!(t.data[$(order[c])], v.data[$c], i)) for c = 1:length(Names1)]
        return Expr(:block, exprs...)
    end
end
@generated function Base.setindex!{Names}(t::Table{Names}, v::Tuple, i)
    if length(v.parameters) != length(Names)
        str = "Cannot assign a $(length(v.parameters))-tuple to $(length(Names)) columns"
        return :(error($str))
    end
    exprs = [:(setindex!(t.data[$c], v.data[$c], i)) for c = 1:length(Names)]
    return Expr(:block, exprs...)
end
@generated function Base.setindex!{Names1,Names2}(t::Table{Names1}, v::Table{Names2}, inds)
    if Names1 == Names2
        exprs = [:(setindex!(t.data[$c], v.data[$c], inds)) for c = 1:length(Names1)]
        return Expr(:block, exprs...)
    else
        if length(Names1) != length(Names2)
            str = "Cannot assign $(length(v.parameters)) columns to $(length(Names)) columns"
            return :(error($str))
        end

        order = permutator(Names1, Names2)
        exprs = [:(setindex!(t.data[$(order[c])], v.data[$c], inds)) for c = 1:length(Names1)]
        return Expr(:block, exprs...)
    end
end


@generated function Base.unsafe_getindex{Names}(t::Table{Names}, i::Integer)
    exprs = [:(Base.unsafe_getindex(t.data[$c], i)) for c = 1:length(Names)]
    return Expr(:call, Row{Names}, Expr(:tuple, exprs...))
end
@generated function Base.unsafe_getindex{Names}(t::Table{Names}, inds)
    exprs = [:(Base.unsafe_getindex(t.data[$c], inds)) for c = 1:length(Names)]
    return Expr(:call, Table{Names}, Expr(:tuple, exprs...))
end

@generated function Base.unsafe_setindex!{Names1,Names2}(t::Table{Names1}, v::Row{Names2}, i::Integer)
    if Names1 == Names2
        exprs = [:(Base.unsafe_setindex!(t.data[$c], v.data[$c], i)) for c = 1:length(Names1)]
        return Expr(:block, exprs...)
    else
        if length(Names1) != length(Names2)
            str = "Cannot assign $(length(v.parameters)) columns to $(length(Names)) columns"
            return :(error($str))
        end

        order = permutator(Names1, Names2)
        exprs = [:(Base.unsafe_setindex!(t.data[$(order[c])], v.data[$c], i)) for c = 1:length(Names1)]
        return Expr(:block, exprs...)
    end
end
@generated function Base.unsafe_setindex!{Names}(t::Table{Names}, v::Tuple, i)
    if length(v.parameters) != length(Names)
        str = "Cannot assign a $(length(v.parameters))-tuple to $(length(Names)) columns"
        return :(error($str))
    end
    exprs = [:(Base.unsafe_setindex!(t.data[$c], v.data[$c], i)) for c = 1:length(Names)]
    return Expr(:block, exprs...)
end
@generated function Base.unsafe_setindex!{Names1,Names2}(t::Table{Names1}, v::Table{Names2}, inds)
    if Names1 == Names2
        exprs = [:(Base.unsafe_setindex!(t.data[$c], v.data[$c], inds)) for c = 1:length(Names1)]
        return Expr(:block, exprs...)
    else
        if length(Names1) != length(Names2)
            str = "Cannot assign $(length(v.parameters)) columns to $(length(Names)) columns"
            return :(error($str))
        end

        order = permutator(Names1, Names2)
        exprs = [:(Base.unsafe_setindex!(t.data[$(order[c])], v.data[$c], inds)) for c = 1:length(Names1)]
        return Expr(:block, exprs...)
    end
end


#############################################################################
# Indexing with two variables
#############################################################################

@generated function Base.getindex{Names, GetName}(t::Table{Names}, rowinds, ::Type{Val{GetName}})
    if isa(GetName, Symbol)
        if GetName == :Row
            return quote
                $(Expr(:meta, :inline))
                (1:nrow(t))[rowinds]
            end
        end

        j = columnindex(Names, GetName)

        return quote
            $(Expr(:meta, :inline))
            t.data[$j][rowinds]
        end
    elseif isa(GetName, Tuple) && eltype(GetName) == Symbol && length(GetName) == length(unique(GetName))
        inds = columnindex(Names, GetName)
        exprs = [:(t.data[$(inds[j])][rowinds]) for j = 1:length(inds)]
        if rowinds <: Integer
            expr = Expr(:call, Row{GetName}, Expr(:tuple, exprs...))
        else
            expr = Expr(:call, Table{GetName}, Expr(:tuple, exprs...))
        end

        return quote
            $(Expr(:meta, :inline))
            $expr
        end
    else
        str = "Can't get column(s) named $Name"
        return :(error($str))
    end
end

@generated function Base.unsafe_getindex{Names, GetName}(t::Table{Names}, rowinds, ::Type{Val{GetName}})
    if isa(GetName, Symbol)
        if GetName == :Row
            return quote
                $(Expr(:meta, :inline))
                Base.unsafe_getindex(1:nrow(t), rowinds)
            end
        end

        j = columnindex(Names, GetName)

        return quote
            $(Expr(:meta, :inline))
            Base.unsafe_getindex(t.data[$j], rowinds)
        end
    elseif isa(GetName, Tuple) && eltype(GetName) == Symbol && length(GetName) == length(unique(GetName))
        inds = columnindex(Names, GetName)
        exprs = [:(Base.unsafe_getindex(t.data[$(inds[j])], rowinds)) for j = 1:length(inds)]
        if rowinds <: Integer
            expr = Expr(:call, Row{GetName}, Expr(:tuple, exprs...))
        else
            expr = Expr(:call, Table{GetName}, Expr(:tuple, exprs...))
        end

        return quote
            $(Expr(:meta, :inline))
            $expr
        end
    else
        str = "Can't get column(s) named $Name"
        return :(error($str))
    end
end

@generated function Base.setindex!{Names, GetName}(t::Table{Names}, value, rowinds, ::Type{Val{GetName}})
    if isa(GetName, Symbol)
        j = columnindex(Names, GetName)
        if value <: Union{Cell, Column}
            return quote
                $(Expr(:meta, :inline))
                t.data[$j][rowinds] = value.data
            end
        else
            return quote
                $(Expr(:meta, :inline))
                t.data[$j][rowinds] = value
            end
        end
    elseif isa(GetName, Tuple) && eltype(GetName) == Symbol && length(GetName) == length(unique(GetName))
        inds = columnindex(Names, GetName)
        if value <: Union{Row, Table}
            order = permutator(names(value), GetName)
            exprs = [:(t.data[$(inds[j])][rowinds] = value.data[$(order[j])]) for j = 1:length(inds)]
            return Expr(:block, Expr(:meta, :inline), exprs...)
        elseif value <: Tuple && length(value.parameters) == length(inds)
            exprs = [:(t.data[$(inds[j])][rowinds] = value[$j]) for j = 1:length(inds)]
            return Expr(:block, Expr(:meta, :inline), exprs...)
        else
            str = "Can't set columns $GetName with a $value"
            return :(error($str))
        end
    else
        str = "Can't set column(s) named $Name"
        return :(error($str))
    end
end

@generated function Base.unsafe_setindex!{Names, GetName}(t::Table{Names}, value, rowinds, ::Type{Val{GetName}})
    if isa(GetName, Symbol)
        j = columnindex(Names, GetName)
        if value <: Union{Cell, Column}
            return quote
                $(Expr(:meta, :inline))
                Base.unsafe_setindex!(t.data[$j], value.data, rowinds)
            end
        else
            return quote
                $(Expr(:meta, :inline))
                Base.unsafe_setindex!(t.data[$j], value, rowinds)
            end
        end
    elseif isa(GetName, Tuple) && eltype(GetName) == Symbol && length(GetName) == length(unique(GetName))
        inds = columnindex(Names, GetName)
        if value <: Union{Row, Table}
            order = permutator(names(value), GetName)
            exprs = [:(Base.unsafe_setindex!(t.data[$(inds[j])], value.data[$(order[j])], rowinds)) for j = 1:length(inds)]
            return Expr(:block, Expr(:meta, :inline), exprs...)
        elseif value <: Tuple && length(value.parameters) == length(inds)
            exprs = [:(Base.unsafe_setindex!(t.data[$(inds[j])], value[$j], rowinds)) for j = 1:length(inds)]
            return Expr(:block, Expr(:meta, :inline), exprs...)
        else
            str = "Can't set columns $GetName with a $value"
            return :(error($str))
        end
    else
        str = "Can't set column(s) named $Name"
        return :(error($str))
    end
end

Base.getindex{Names}(t::Table{Names}, inds, ::Colon) = t[inds]
Base.unsafe_getindex{Names}(t::Table{Names}, inds, ::Colon) = Base.unsafe_getindex(t, inds)
Base.setindex!{Names}(t::Table{Names}, value, inds, ::Colon) = Base.setindex!(t, value, inds)
Base.unsafe_setindex!{Names}(t::Table{Names}, value, inds, ::Colon) = Base.unsafe_setindex!(t, value, inds)



#############################################################################
# push, pop, etc
#############################################################################

@generated function Base.pop!{Names}(t::Table{Names})
    exprs = [:(pop!(t.data[$c])) for c = 1:length(Names)]
    return Expr(:call, Row{Names}, Expr(:tuple, exprs...))
end

@generated function Base.shift!{Names}(t::Table{Names})
    exprs = [:(shift!(t.data[$c])) for c = 1:length(Names)]
    return Expr(:call, Row{Names}, Expr(:tuple, exprs...))
end

@generated function Base.push!{Names}(t::Table{Names}, v::Tuple)
    if length(Names) != length(v.parameters)
        str = "Cannot assign a $(length(v.parameters))-tuple to $(length(Names)) columns"
        return :(error($str))
    end
    exprs = [:(push!(t.data[$c], v[$c])) for c = 1:length(Names)]
    return Expr(:block, exprs..., :t)
end
@generated function Base.push!{Names1,Names2}(t::Table{Names1}, r::Row{Names2})
    order = permutator(Names1, Names2)
    exprs = [:(push!(t.data[$(order[c])], r.data[$c])) for c = 1:length(Names1)]
    return Expr(:block, exprs..., :t)
end

@generated function Base.unshift!{Names}(t::Table{Names}, v::Tuple)
    if length(Names) != length(v.parameters)
        str = "Cannot assign a $(length(v.parameters))-tuple to $(length(Names)) columns"
        return :(error($str))
    end
    exprs = [:(unshift!(t.data[$c], v[$c])) for c = 1:length(Names)]
    return Expr(:block, exprs..., :t)
end
@generated function Base.unshift!{Names1,Names2}(t::Table{Names1}, r::Row{Names2})
    order = permutator(Names1, Names2)
    exprs = [:(unshift!(t.data[$(order[c])], r.data[$c])) for c = 1:length(Names1)]
    return Expr(:block, exprs..., :t)
end

@generated function Base.append!{Names}(t::Table{Names}, v::Tuple)
    if length(Names) != length(v.parameters)
        str = "Cannot assign a $(length(v.parameters))-tuple to $(length(Names)) columns"
        return :(error($str))
    end
    exprs = [:(append!(t.data[$c], v[$c])) for c = 1:length(Names)]
    return Expr(:block, exprs..., :t)
end
@generated function Base.append!{Names1,Names2}(t::Table{Names1}, t2::Table{Names2})
    order = permutator(Names1, Names2)
    exprs = [:(append!(t.data[$(order[c])], t2.data[$c])) for c = 1:length(Names1)]
    return Expr(:block, exprs..., :t)
end

@generated function Base.prepend!{Names}(t::Table{Names}, v::Tuple)
    if length(Names) != length(v.parameters)
        str = "Cannot assign a $(length(v.parameters))-tuple to $(length(Names)) columns"
        return :(error($str))
    end
    exprs = [:(prepend!(t.data[$c], v[$c])) for c = 1:length(Names)]
    return Expr(:block, exprs..., :t)
end
@generated function Base.prepend!{Names1,Names2}(t::Table{Names1}, t2::Table{Names2})
    order = permutator(Names1, Names2)
    exprs = [:(prepend!(t.data[$(order[c])], t2.data[$c])) for c = 1:length(Names1)]
    return Expr(:block, exprs..., :t)
end

@generated function Base.insert!{Names}(t::Table{Names}, i::Integer, v::Tuple)
    if length(Names) != length(v.parameters)
        str = "Cannot assign a $(length(v.parameters))-tuple to $(length(Names)) columns"
        return :(error($str))
    end
    exprs = [:(insert!(t.data[$c], i, v[$c])) for c = 1:length(Names)]
    return Expr(:block, exprs..., :t)
end
@generated function Base.insert!{Names1,Names2}(t::Table{Names1}, i::Integer, r::Row{Names2})
    order = permutator(Names1, Names2)
    exprs = [:(insert!(t.data[$(order[c])], i, r.data[$c])) for c = 1:length(Names1)]
    return Expr(:block, exprs..., :t)
end

@generated function Base.empty!{Names}(t::Table{Names})
    exprs = [:(empty!(t.data[$c])) for c = 1:length(Names)]
    return Expr(:block, exprs..., :t)
end

@generated function Base.deleteat!{Names}(t::Table{Names}, i)
    exprs = [:(deleteat!(t.data[$c], i)) for c = 1:length(Names)]
    return Expr(:block, exprs..., :t)
end

@generated function Base.splice!{Names}(t::Table{Names}, i::Integer)
    exprs = [:(splice!(t.data[$c], i)) for c = 1:length(Names)]
    return Expr(:call, Row{Names}, Expr(:tuple, exprs...))
end
@generated function Base.splice!{Names}(t::Table{Names}, i::Integer, v::Tuple)
    exprs = [:(splice!(t.data[$c], i, v[$c])) for c = 1:length(Names)]
    return Expr(:call, Row{Names}, Expr(:tuple, exprs...))
end
@generated function Base.splice!{Names1,Names2}(t::Table{Names1}, i::Integer, v::Union{Row{Names2},Table{Names2}})
    order = permutator(Names2, Names1)
    exprs = [:(splice!(t.data[$c], i, v.data[$(order[c])])) for c = 1:length(Names1)]
    return Expr(:call, Row{Names1}, Expr(:tuple, exprs...))
end
@generated function Base.splice!{Names}(t::Table{Names}, i)
    exprs = [:(splice!(t.data[$c], i)) for c = 1:length(Names)]
    return Expr(:call, Table{Names}, Expr(:tuple, exprs...))
end
@generated function Base.splice!{Names}(t::Table{Names}, i, v::Tuple)
    exprs = [:(splice!(t.data[$c], i, v[$c])) for c = 1:length(Names)]
    return Expr(:call, Table{Names}, Expr(:tuple, exprs...))
end
@generated function Base.splice!{Names1,Names2}(t::Table{Names1}, i, v::Union{Row{Names2},Table{Names2}})
    order = permutator(Names2, Names1)
    exprs = [:(splice!(t.data[$c], i, v.data[$(order[c])])) for c = 1:length(Names1)]
    return Expr(:call, Table{Names1}, Expr(:tuple, exprs...))
end

# Vertically concatenate rows and tables into tables
@generated function Base.vcat{Names}(t1::Union{Row{Names}, Table{Names}})
    exprs = [:(vcat(t1.data[$c])) for c = 1:length(Names)]
    return Expr(:call, Table{Names}, Expr(:tuple, exprs...))
end

# TODO still problem with mixed Row-Table vcat inherited from Base scalar-Vector vcat
@generated function Base.vcat{Names1, Names2}(t1::Union{Row{Names1}, Table{Names1}}, t2::Union{Row{Names2}, Table{Names2}})
    if Names1 == Names2
        exprs = [:(vcat(t1.data[$c], t2.data[$c])) for c = 1:length(Names1)]
        return Expr(:call, Table{Names1}, Expr(:tuple, exprs...))
    else
        if length(Names1) != length(Names2)
            str = "Cannot match $(length(v.parameters)) columns to $(length(Names)) columns"
        end

        order = permutator(Names1, Names2)
        exprs = [:(vcat(t1.data[$c], t2.data[$(order[c])])) for c = 1:length(Names1)]
        return Expr(:call, Table{Names1}, Expr(:tuple, exprs...))
    end
end

Base.vcat{Names1, Names2}(t1::Union{Row{Names1}, Table{Names1}}, t2::Union{Row{Names2}, Table{Names2}}, ts::Union{Row, Table}...) = vcat(vcat(t1, t2), ts...)

# Horizontally concatenate columns and tables into tables
@generated Base.hcat{Name}(c::Column{Name}) = :( Table{$((Name,))}((c.data,)) )
Base.hcat(t::Table) = t

@generated function Base.hcat(r1::Union{Column,Table}, r2::Union{Column,Table})
    names1 = (r1 <: Column ? (name(r1),) : names(r1))
    names2 = (r2 <: Column ? (name(r2),) : names(r2))

    if length(intersect(names1, names2)) != 0
        str = "Column names are not distinct. Got $names1 and $names2"
        return :(error($str))
    end

    newnames = (names1..., names2...)
    exprs1 = r1 <: Column ? [:(r1.data)] : [:(r1.data[$j]) for j = 1:length(names1)]
    exprs2 = r2 <: Column ? [:(r2.data)] : [:(r2.data[$j]) for j = 1:length(names2)]
    exprs = vcat(exprs1, exprs2)

    return Expr(:call, Table{newnames}, Expr(:tuple, exprs...))
end

Base.hcat(t1::Union{Column,Table}, t2::Union{Column,Table}, ts::Union{Column,Table}...) = hcat(hcat(t1, t2), ts...)

# copy
@generated function Base.copy{Names}(t::Table{Names})
    exprs = [:(copy(t.data[$j])) for j = 1:length(Names)]
    return Expr(:call, Table{Names}, Expr(:tuple, exprs...))
end

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

@generated Table{Index<:FieldIndex,StorageTypes<:Tuple}(::Index,data_in::StorageTypes,check_sizes::Union{Type{Val{true}},Type{Val{false}}} = Val{true}) = :(Table{$(Index()),$(eltypes(Index)),$StorageTypes}(data_in,check_sizes) )
@generated Table{Index<:FieldIndex}(::Index,check_sizes::Union{Type{Val{true}},Type{Val{false}}} = Val{true}) = :(Table{$(Index()),$(eltypes(Index)),$(makestoragetypes(eltypes(Index)))}(instantiate_tuple($(makestoragetypes(eltypes(Index)))),check_sizes) )
@generated Table{Index,ElTypes}(row::Row{Index,ElTypes},check_sizes::Union{Type{Val{true}},Type{Val{false}}} = Val{true}) = :(Table{Index,ElTypes,$(makestoragetypes(ElTypes))}(ntuple(i->[row.data[i]],$(length(Index))),check_sizes) )
@generated Table{F,ElType,StorageType}(col::Column{F,ElType,StorageType},check_sizes::Union{Type{Val{true}},Type{Val{false}}} = Val{true}) = :(Table{$(FieldIndex(F)),Tuple{ElType},Tuple{StorageType}}((col.data,),check_sizes) )

@generated function Base.call{Fields,StorageTypes<:Tuple}(Index::FieldIndex{Fields},x::StorageTypes)
    if StorageTypes == eltypes(Index)
        return :(Row{$(Index()),$StorageTypes}(x))
    end

    try
        check_table(Index(),eltypes(Index),StorageTypes)
        return :(Table{$(Index()),$(eltypes(Index)),$StorageTypes}(x))
    catch
        str = "Can't instantiate a Row or Table having index $(Index()) with data of types $StorageTypes."
        error(str)
    end
end
Base.call{Fields}(::FieldIndex{Fields},x...) = error("Must instantiate Row with a tuple of type $(eltypes(Index)) or a Table with a tuple of appropriate storage containers")

@generated function makestoragetypes{T<:Tuple}(::Type{T})
    eltypes = T.parameters
    storagetypes = Vector{DataType}(length(eltypes))
    for i = 1:length(eltypes)
        storagetypes[i] = makestoragetype(eltypes[i])
    end
    return :(Tuple{$(storagetypes...)} )
end

Base.convert{Index,DataTypes<:Tuple,StorageTypes<:Tuple}(::Type{StorageTypes},x::Table{Index,DataTypes,StorageTypes}) = x.data

=={Index,ElTypes,StorageType}(table1::Table{Index,ElTypes,StorageType},table2::Table{Index,ElTypes,StorageType}) = (table1.data == table2.data)
function =={Index1,ElTypes1,StorageType1,Index2,ElTypes2,StorageType2}(table1::Table{Index1,ElTypes1,StorageType1},table2::Table{Index2,ElTypes2,StorageType2})
    if samefields(Index1,Index2)
        idx = Index2[Index1]
        for i = 1:length(Index1)
            if table1.data[i] != table2.data[idx[i]]
                return false
            end
        end
        return true
    else
        return false
    end
end

# Conversion between Dense and normal Tables??
# Some more convient versions. (a) One that takes pairs of fields and storage.
#                              (b) A macro @table(x=[1,2,3],y=["a","b","c"]) -> Table(Field{:x,eltype([1,2,3)}()=>[1,2,3], Field{:y,eltype{["a","b","c"]}()=>["a","b","c"])


# Data from the index
Base.names{Index}(table::Table{Index}) = names(Index)
Base.names{Index,ElTypes,StorageTypes}(table::Type{Table{Index,ElTypes,StorageTypes}}) = names(Index)
eltypes{Index}(table::Table{Index}) = eltypes(Index)
eltypes{Index,ElTypes,StorageTypes}(table::Type{Table{Index,ElTypes,StorageTypes}}) = eltypes(Index)
storagetypes{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = StorageTypes
storagetypes{Index,ElTypes,StorageTypes}(table::Type{Table{Index,ElTypes,StorageTypes}}) = StorageTypes

@generated rename{Index,ElTypes,StorageTypes,NewIndex<:FieldIndex}(table::Table{Index,ElTypes,StorageTypes}, new_names::NewIndex) = :( Table{$(rename(Index,NewIndex())),$ElTypes,$StorageTypes}(table.data, Val{false}) )
@generated rename{Index,ElTypes,DataTypes,OldFields,NewFields}(table::Table{Index,ElTypes,DataTypes}, old_names::OldFields, ::NewFields) = :(Table($(rename(Index,OldFields(),NewFields())),table.data, Val{false}))

# Vector-like introspection
Base.length{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = length(table.data[1])
Base.length{Index}(table::Table{Index,Tuple{},Tuple{}}) = 0

@generated ncol{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = :($(length(Index)))
nrow{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = length(table.data[1])
Base.size{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = (length(table.data[1]),length(Index))
Base.size{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},i::Int) = i == 2 ? length(Index) : (i == 1 ? length(table.data[1]) : error("Tables are two-dimensional"))
@generated Base.eltype{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = :($(eltypes(Index)))
Base.isempty{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = isempty(table.data[1])
Base.endof{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = endof(table.data[1])
index{Index}(table::Table{Index}) = Index

samefields{Index1,Index2}(::Table{Index1},::Table{Index2}) = samefields(Index1,Index2)
samefields{Index1,Index2}(::Row{Index1},::Table{Index2}) = samefields(Index1,Index2)
samefields{Index1,Index2}(::Table{Index1},::Row{Index2}) = samefields(Index1,Index2)
samefields{Index1<:FieldIndex,Index2}(::Index1,::Table{Index2}) = samefields(Index1(),Index2)
samefields{Index1,Index2<:FieldIndex}(::Table{Index1},::Index2) = samefields(Index1,Index2())

# Iterators
Base.start{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = 1
Base.next{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},i) = (table[i],i+1)
Base.done{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},i) = (i-1 == length(table))

# get/set index (not fast... use generated functions?)
Base.getindex{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},idx::Int) = Row{Index,ElTypes}(ntuple(i->getindex(table.data[i],idx),length(Index)))
Base.getindex{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},idx) = Table{Index,ElTypes,StorageTypes}(ntuple(i->getindex(table.data[i],idx),length(Index)))

Base.setindex!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},val::Row{Index},idx::Int) = (for i = 1:length(Index); setindex!(table.data[i],val.data[i],idx); end; val)
Base.setindex!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},val::Table{Index,ElTypes, StorageTypes},idx) = (for i = 1:length(Index); setindex!(table.data[i],val.data[i],idx); end; val)

Base.unsafe_getindex{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},idx::Int) = Row{Index, ElTypes}(ntuple(i->unsafe_getindex(table.data[i],idx),length(Index)))
Base.unsafe_getindex{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},idx) = Table{Index,ElTypes,StorageTypes}(ntuple(i->Base.unsafe_getindex(table.data[i],idx),length(Index)))
Base.unsafe_setindex!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},val::Row{Index},idx::Int) = for i = 1:length(Index); Base.unsafe_setindex!(table.data[i],val.data[i],idx); end
Base.unsafe_setindex!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},val::Table{Index,StorageTypes},idx) = for i = 1:length(Index); Base.unsafe_setindex!(table.data[i],val.data[i],idx); end


# Push, append, pop
function Base.push!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},row::Row{Index,ElTypes})
    for i = 1:length(Index)
        push!(table.data[i],row.data[i])
    end
    table
end
@inline Base.push!{Index,ElTypes,StorageTypes,Index2,ElTypes2}(table::Table{Index,ElTypes,StorageTypes},row::Row{Index2,ElTypes2}) = push!(table,row[Index])
@inline Base.push!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},data_in::ElTypes) = push!(table, Row{Index,ElTypes}(data_in))
function Base.append!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},table_in::Table{Index,ElTypes,StorageTypes})
    for i in 1:length(Index)
        append!(table.data[i],table_in.data[i])
    end
end
@inline Base.append!{Index,ElTypes,StorageTypes,Index2,ElTypes2,StorageTypes2}(table::Table{Index,ElTypes,StorageTypes},table_in::Table{Index2,ElTypes2,StorageTypes2}) = append!(table,table_in[Index])
function Base.append!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},data_in::StorageTypes)
    ls = map(length,data_in)
    for i in 2:length(Index)
        if ls[i] != ls[1]
            error("Column inputs must be same length.")
        end
    end

    for i in 1:length(data_in)
        append!(table.data[i],data_in[i])
    end
end
function Base.prepend!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},table_in::Table{Index,ElTypes,StorageTypes})
    for i in 1:length(Index)
        prepend!(table.data[i],table_in.data[i])
    end
end
@inline Base.prepend!{Index,ElTypes,StorageTypes,Index2,ElTypes2,StorageTypes2}(table::Table{Index,ElTypes,StorageTypes},table_in::Table{Index2,ElTypes2,StorageTypes2}) = prepend!(table,table_in[Index])
function Base.prepend!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},data_in::StorageTypes)
    ls = map(length,data_in)
    for i in 2:length(Index)
        if ls[i] != ls[1]
            error("Column inputs must be same length.")
        end
    end

    for i in 1:length(data_in)
        prepend!(table.data[i],data_in[i])
    end
end
function Base.unshift!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},row::Row{Index,ElTypes})
    for i = 1:length(Index)
        unshift!(table.data[i],row.data[i])
    end
    table
end
@inline Base.unshift!{Index,ElTypes,StorageTypes,Index2,ElTypes2}(table::Table{Index,ElTypes,StorageTypes},row::Row{Index2,ElTypes2}) = unshift!(table,row[Index])
@inline Base.unshift!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},data_in::ElTypes) = unshift!(table, Row{Index,ElTypes}(data_in))
function Base.pop!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes})
    return Row{Index,eltypes(Index)}(ntuple(i->pop!(table.data[i]),length(Index)))
end
function Base.shift!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes})
    return Row{Index,eltypes(Index)}(ntuple(i->shift!(table.data[i]),length(Index)))
end
function Base.empty!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes})
    for i = 1:length(Index)
        empty!(table.data[i])
    end
end

# copies
Base.copy{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = Table{Index,ElTypes,StorageTypes}(copy(table.data))
Base.deepcopy{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = Table{Index,ElTypes,StorageTypes}(deepcopy(table.data))

# Some output
function Base.summary{Index,ElTypes,StorageTypes}(io::IO,table::Table{Index,ElTypes,StorageTypes})
    println(io,"$(ncol(table))-column × $(nrow(table))-row Table{$Index,$StorageTypes}")
end


head(t::Table, n = 5) = length(t) >= n ? t[1:n] : t
tail(t::Table, n = 5) = length(t) >= n ? t[end-n+1:end] : t

# Can create a subtable easily by selecting columns
@generated Base.getindex{Index,ElTypes,StorageTypes,F<:Field}(table::Table{Index,ElTypes,StorageTypes},::F) = :( table.data[$(Index[F()])] )
Base.getindex{Index,ElTypes,StorageTypes,F<:DefaultKey}(table::Table{Index,ElTypes,StorageTypes},::F) = 1:length(table.data[1])

@generated function Base.getindex{Index,ElTypes,StorageTypes,NewIndex<:FieldIndex}(table::Table{Index,ElTypes,StorageTypes},::NewIndex) # Need special possibility for DefaultKey, which may or many not exist in array
    if issubset(NewIndex(),Index+DefaultKey())
        str = "("
        for i = 1:length(NewIndex())
            if NewIndex()[i] == DefaultKey()
                str *= "TableKey{Index,ElTypes,StorageTypes}(Ref(table))"
            else
                str *= "table.data[$(Index[NewIndex()[i]])]"
            end
            if i < length(NewIndex()) || i == 1
                str *= ","
            end
        end
        str *= ")"

        return :(Table(NewIndex(),$(parse(str))))
    else
        str = "Cannot index $NewIndex from table with indices $Index"
        return :(error($str))
    end
end

@generated function Base.getindex{Index,DataTypes,StorageTypes,I}(table::Table{Index,DataTypes,StorageTypes},::Type{Val{I}})
    if isa(I, Int) # TODO: Figure out if this one can be made faster... seems to be some overhead in creating the new Column (similarly for Table below)
        return :( $(Expr(:meta,:inline)); $(Column{Index[I],DataTypes.parameters[I],StorageTypes.parameters[I]})(table.data[$I]) )
    elseif isa(I, Symbol)
        if I == name(DefaultKey)
            return :( 1:length(table) )
        else
            return :( table.data[$(Index[Val{I}])] )
        end
    elseif isa(I, Tuple)
        l_I = length(I)
        if isa(I, NTuple{l_I, Int})
            expr = Expr(:tuple, ntuple(i-> :(table.data[$(I[i])]), l_I)...)
            return :( Table($(Index[Val{I}]), $expr, Val{false}) )
        elseif isa(I, NTuple{l_I, Symbol})
            expr = Expr(:tuple, ntuple(i -> I[i] == name(DefaultKey) ? :( 1:length(table) ) : :(table.data[$(Index[Val{I[i]}])]), l_I)...)
            return :( Table($(Index[Val{Index[Val{I}]}]), $expr, Val{false}) )
        else
            str = "Can't index Table with fields $Fields with a Val{$I}"
            return :(error($str))
        end
    else # e.g. UnitRange{Int} and other methods of indexing a Tuple
        str = "Can't index Table with fields $Fields with a Val{$I}"
        return :(error($str))
    end
end

# Simultaneously indexing by single row and column
@generated Base.getindex{Index,ElTypes,StorageTypes,F<:Field}(table::Table{Index,ElTypes,StorageTypes},idx::Int,::F) = :( table.data[$(Index[F()])][idx] )
Base.getindex{Index,ElTypes,StorageTypes,F<:DefaultKey}(table::Table{Index,ElTypes,StorageTypes},idx::Int,::F) = idx

@generated function Base.getindex{Index,ElTypes,StorageTypes,NewIndex<:FieldIndex}(table::Table{Index,ElTypes,StorageTypes},idx::Int,::NewIndex) # Need special possibility for DefaultKey, which may or many not exist in array
    if issubset(NewIndex(),Index+DefaultKey())
        str = "("
        for i = 1:length(NewIndex())
            if NewIndex()[i] == DefaultKey()
                str *= "idx"
            else
                str *= "table.data[$(Index[NewIndex()[i]])][idx]"
            end
            if i < length(NewIndex()) || i == 1
                str *= ","
            end
        end
        str *= ")"

        return :(Row(NewIndex(),$(parse(str))))
    else
        str = "Cannot index $NewIndex from table with indices $Index"
        return :(error($str))
    end
end

@generated function Base.getindex{Index,DataTypes,StorageTypes,I}(table::Table{Index,DataTypes,StorageTypes},idx::Int,::Type{Val{I}})
    if isa(I, Int) # TODO: Figure out if this one can be made faster... seems to be some overhead in creating the new Column (similarly for Table below)
        return :( $(Expr(:meta,:inline)); $(Cell{Index[I],DataTypes.parameters[I]})(table.data[$I][idx]) )
    elseif isa(I, Symbol)
        if I == name(DefaultKey)
            return :( (1:length(table))[idx] )
        else
            return :( table.data[$(Index[Val{I}])][idx] )
        end
    elseif isa(I, Tuple)
        l_I = length(I)
        if isa(I, NTuple{l_I, Int})
            expr = Expr(:tuple, ntuple(i-> :(table.data[$(I[i])][idx]), l_I)...)
            return :( Row($(Index[Val{I}]), $expr) )
        elseif isa(I, NTuple{l_I, Symbol})
            expr = Expr(:tuple, ntuple(i -> :(table.data[$(Index[Val{I[i]}])][idx]), l_I)...)
            return :( Row($(Index[Val{Index[Val{I}]}]), $expr) )
        else
            str = "Can't index Table with fields $Fields with a Val{$I}"
            return :(error($str))
        end
    else # e.g. UnitRange{Int} and other methods of indexing a Tuple
        str = "Can't index Table with fields $Fields with a Val{$I}"
        return :(error($str))
    end
end

# Simultaneously indexing by multiple rows and column
@generated Base.getindex{Index,ElTypes,StorageTypes,F<:Field}(table::Table{Index,ElTypes,StorageTypes},idx,::F) = :( table.data[$(Index[F()])][idx] )
Base.getindex{Index,ElTypes,StorageTypes,F<:DefaultKey}(table::Table{Index,ElTypes,StorageTypes},idx,::F) = (1:length(table.data[1]))[idx]

@generated function Base.getindex{Index,ElTypes,StorageTypes,NewIndex<:FieldIndex}(table::Table{Index,ElTypes,StorageTypes},idx,::NewIndex) # Need special possibility for DefaultKey, which may or many not exist in array
    if issubset(NewIndex(),Index+DefaultKey())
        str = "("
        for i = 1:length(NewIndex())
            if NewIndex()[i] == DefaultKey()
                str *= "TableKey{Index,StorageTypes}(Ref(table))"
            else
                str *= "table.data[$(Index[NewIndex()[i]])][idx]"
            end
            if i < length(NewIndex()) || i == 1
                str *= ","
            end
        end
        str *= ")"

        return :(Table(NewIndex(),$(parse(str))))
    else
        str = "Cannot index $NewIndex from table with indices $Index"
        return :(error($str))
    end
end

@generated function Base.getindex{Index,DataTypes,StorageTypes,I}(table::Table{Index,DataTypes,StorageTypes},idx,::Type{Val{I}})
    if isa(I, Int) # TODO: Figure out if this one can be made faster... seems to be some overhead in creating the new Column (similarly for Table below)
        return :( $(Expr(:meta,:inline)); $(Column{Index[I],DataTypes.parameters[I],StorageTypes.parameters[I]})(table.data[$I][idx]) )
    elseif isa(I, Symbol)
        if I == name(DefaultKey)
            return :( (1:length(table))[idx] )
        else
            return :( table.data[$(Index[Val{I}])][idx] )
        end
    elseif isa(I, Tuple)
        l_I = length(I)
        if isa(I, NTuple{l_I, Int})
            expr = Expr(:tuple, ntuple(i-> :(table.data[$(I[i])][idx]), l_I)...)
            return :( Table($(Index[Val{I}]), $expr, Val{false}) )
        elseif isa(I, NTuple{l_I, Symbol})
            expr = Expr(:tuple, ntuple(i -> :(table.data[$(Index[Val{I[i]}])][idx]), l_I)...)
            return :( Table($(Index[Val{Index[Val{I}]}]), $expr, Val{false}) )
        else
            str = "Can't index Table with fields $Fields with a Val{$I}"
            return :(error($str))
        end
    else # e.g. UnitRange{Int} and other methods of indexing a Tuple
        str = "Can't index Table with fields $Fields with a Val{$I}"
        return :(error($str))
    end
end

Base.getindex{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},idx,::Colon) = table[idx]

function Base.filter!{Index,ElTypes,StorageTypes}(idx::Vector{Bool}, table::Table{Index,ElTypes,StorageTypes})
    for i = 1:ncol(table)
        tmp = table.data[i][idx]
        resize!(table.data[i],length(tmp))
        table.data[i][:] = tmp
    end
    table
end

# TODO - sub() returns table/row with sub as data elements.


# Concatenate rows and tables into tables
@inline Base.vcat(row::Row) = Table(row)
@inline Base.vcat(table::Table) = table

@generated Base.vcat{Index}(row1::Row{Index},row2::Union{Row{Index},Table{Index}}) = :( Table{Index,$(eltypes(Index)),$(makestoragetypes(eltypes(Index)))}(ntuple(i->vcat(row1.data[i],row2.data[i]),$(length(Index)))) )
@generated Base.vcat{Index}(table1::Table{Index},table2::Union{Row{Index},Table{Index}}) = :( Table{Index,$(eltypes(table1)),$(storagetypes(table1))}(ntuple(i->vcat(table1.data[i],table2.data[i]),length(Index))) )

# Otherwise, fields don't match...
function Base.vcat{Index1,Index2}(x1::Union{Row{Index1},Table{Index1}}, x2::Union{Row{Index2},Table{Index2}})
    if samefields(Index1, Index2)
        vcat(x1, x2[Index1])
    else
        error("Indices $Index1 and $Index2 don't match")
    end
end

# More than two inputs
Base.vcat(c1::Union{Row,Table},c2::Union{Row,Table},c3::Union{Row,Table}) = vcat(vcat(c1,c2),c3)
Base.vcat(c1::Union{Row,Table},c2::Union{Row,Table},c3::Union{Row,Table},cs...) = vcat(vcat(c1,c2),c3,cs...)


# Concatenate columns and tables into tables
# Generated functions appear to be needed for speed...
Base.hcat{F,ElType,StorageType}(col::Column{F,ElType,StorageType}) = Table(col)
Base.hcat{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = table

@generated Base.hcat{F1,ElType1,Storage1,F2,ElType2,Storage2}(col1::Column{F1,ElType1,Storage1},col2::Column{F2,ElType2,Storage2}) = :( Table{$(FieldIndex{(F1,F2)}()),$(Tuple{ElType1,ElType2}),$(Tuple{Storage1,Storage2})}((col1.data,col2.data)) )
@generated function Base.hcat{F1,ElType1,Storage1,Index2,ElTypes2,StorageTypes2}(col1::Column{F1,ElType1,Storage1},table2::Table{Index2,ElTypes2,StorageTypes2})
    Index = F1 + Index2
    ElTypes = eltypes(Index)
    StorageTypes = Tuple{Storage1 ,StorageTypes2.parameters...}

    :(Table{$Index,$ElTypes,$StorageTypes}((col1.data, table2.data...)) )
end
@generated function Base.hcat{Index1,ElTypes1,StorageTypes1,F2,ElType2,Storage2}(table1::Table{Index1,ElTypes1,StorageTypes1},col2::Column{F2,ElType2,Storage2})
    Index = Index1 + F2
    ElTypes = eltypes(Index)
    StorageTypes = Tuple{StorageTypes1.parameters..., Storage2}

    :(Table{$Index,$ElTypes,$StorageTypes}((table1.data..., col2.data)) )
end
@generated function Base.hcat{Index1,ElTypes1,StorageTypes1,Index2,ElTypes2,StorageTypes2}(table1::Table{Index1,ElTypes1,StorageTypes1},table2::Table{Index2,ElTypes2,StorageTypes2})
    Index = Index1 + Index2
    ElTypes = eltypes(Index)
    StorageTypes = Tuple{StorageTypes1.parameters..., StorageTypes2.parameters...}

    :(Table{$Index,$ElTypes,$StorageTypes}((table1.data..., table2.data...)) )
end

# Strangely I get dispatch problems for Column->Table but not Cell->Row. Solution is to make sure this is at least as spececific in its templating as those above...
@inline Base.hcat{F1,ElType1,Storage1,F2,ElType2,Storage2}(in1::Column{F1,ElType1,Storage1},in2::Column{F2,ElType2,Storage2},ins::Union{Column,Table}...) = hcat(hcat(in1,in2),ins...)
@inline Base.hcat{F1,ElType1,Storage1,Index2,ElTypes2,StorageTypes2}(in1::Column{F1,ElType1,Storage1},in2::Table{Index2,ElTypes2,StorageTypes2},ins::Union{Column,Table}...) = hcat(hcat(in1,in2),ins...)
@inline Base.hcat{Index1,ElTypes1,StorageTypes1,F2,ElType2,Storage2}(in1::Table{Index1,ElTypes1,StorageTypes1},in2::Column{F2,ElType2,Storage2},ins::Union{Column,Table}...) = hcat(hcat(in1,in2),ins...)
@inline Base.hcat{Index1,ElTypes1,StorageTypes1,Index2,ElTypes2,StorageTypes2}(in1::Table{Index1,ElTypes1,StorageTypes1},in2::Table{Index2,ElTypes2,StorageTypes2},ins::Union{Column,Table}...) = hcat(hcat(in1,in2),ins...)



macro table(exprs...)
    N = length(exprs)
    field = Vector{Any}(N)
    value = Vector{Any}(N)
    for i = 1:N
        expr = exprs[i]
        if expr.head != :(=) && expr.head != :(kw) # strange Julia bug, see issue 7669
            error("A Expecting expression like @table(name::Type = value) or @table(field = value)")
        end
        if isa(expr.args[1],Symbol)
            field[i] = expr.args[1]
        elseif isa(expr.args[1],Expr)
            if expr.args[1].head != :(::) || length(expr.args[1].args) != 2
                field[i] = expr.args[1]
            else
                field[i] = :(TypedTables.Field{$(Expr(:quote,expr.args[1].args[1])),$(expr.args[1].args[2])}())
            end
        else
            error("C Expecting expression like @table(name::Type = value) or @table(field = value)")
        end
        value[i] = expr.args[2]
    end

    fields = Expr(:tuple,field...)
    values = Expr(:tuple,value...)

    return :(TypedTables.Table(TypedTables.FieldIndex{$(esc(fields))}(),$(esc(values))))
end



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
