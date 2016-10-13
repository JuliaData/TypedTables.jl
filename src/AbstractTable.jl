abstract AbstractTable

@inline Base.names{Tbl<:AbstractTable}(::Tbl) = names(Tbl)
@inline eltypes{Tbl<:AbstractTable}(::Tbl) = eltypes(Tbl)
@inline eltypes{Tbl<:AbstractTable}(::Type{Tbl}) = Core.Inference.return_type(get, Tuple{Tbl})

@inline Base.convert{Tbl<:AbstractTable}(::Type{Tbl}, t::AbstractTable) = Tbl(get(t))

@inline rename{Tbl<:AbstractTable, Names}(t::Tbl, ::Type{Val{Names}}) = table_type(Tbl, Names)(get(t))
@generated function rename{OldName, NewName}(t::AbstractTable, ::Type{Val{OldName}}, ::Type{Val{NewName}})
    j = [nameindex(names(row), OldName)...]

    new_names = [names(row)...]
    new_names[j] = NewName
    new_names = (new_names...)

    return :($(table_type(t, new_names))(get(t)))
end

rename{Names, NewNames}(table::Table{Names}, ::Type{Val{NewNames}}) = Table{NewNames}(table.data)

@generated function rename{Names, OldName, NewName}(t::Table{Names}, ::Type{Val{OldName}}, ::Type{Val{NewName}})
    j = columnindex(Names, OldName)

    NewNames = [Names...]
    NewNames[j] = NewName
    NewNames = (NewNames...)

    return :(Table{$NewNames}(t.data, Val{false}))
end



@generated function Base.:(==)(t1::AbstractTable, t2::AbstractTable)
    if !similarnames(t1, t2)
        return false
    elseif ncol(t1) == 0
        return true
    end

    order = names_perm(t1, t2)
    expr = :( data1[$(order[1])] == data2[1] )
    for j = 2:ncol(t1)
        expr = Expr(:call, :(&), expr, :( data1[$(order[j])] == data2[$j] ))
    end

    return quote
        $(Expr(:meta, :inline))
        data1 = get(t1)
        data2 = get(t2)
        $expr
    end
end

@generated function Base.isapprox(t1::AbstractTable, t2::AbstractTable; kwargs...)
    if !similarnames(t1, t2)
        return false
    elseif ncol(t1) == 0
        return true
    end

    order = names_perm(t1, t2)
    expr = :( all(map((val1,val2)->isapprox(val1, val2; kwargs...), data1[$(order[1])], data2[1])) )
    for j = 2:ncol(row1)
        expr = Expr(:call, :(&), expr, :( all(map((val1,val2)->isapprox(val1, val2; kwargs...), data1[$(order[j])], data2[j])) ))
    end

    return quote
        $(Expr(:meta, :inline))
        data1 = get(t1)
        data2 = get(t2)
        $expr
    end
end
