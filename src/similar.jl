"""
    cell_type(InType, [name])

Returns a subtype of `AbstractCell` that is similar to `InType` but optionally
with modified fieldname `name`. The element type of the cell remains undefined.
"""
@pure cell_type{C<:Union{AbstractCell, AbstractColumn}}(::Type{C}) = cell_type(C, name(C))
@pure function cell_type{R<:Union{AbstractRow, AbstractTable}}(::Type{R})
    if ncol(R) == 1
        return cell_type(R, names(R)[1])
    else
        error("Can't find cell type corresponding with multi-column type $R")
    end
end

# Defaults to `Cell`
@pure cell_type{C<:Union{AbstractCell, AbstractColumn}}(::Type{C}, newname::Symbol) = Cell{newname}
@pure cell_type{R<:Union{AbstractRow, AbstractTable}}(::Type{R}, newname::Symbol) = Cell{newname}

"""
    column_type(InType, [name])

Returns a subtype of `AbstractColumn` that is similar to `InType` but optionally
with modified fieldname `name`. The storage type of the column remains undefined.
"""
@pure column_type{C<:Union{AbstractCell, AbstractColumn}}(::Type{C}) = column_type(C, name(C))
@pure function column_type{R<:Union{AbstractRow, AbstractTable}}(::Type{R})
    if ncol(R) == 1
        return column_type(R, names(R)[1])
    else
        error("Can't find column type corresponding with multi-column type $R")
    end
end

# Defaults to `Cell`
@pure column_type{C<:Union{AbstractCell, AbstractColumn}}(::Type{C}, newname::Symbol) = Column{newname}
@pure column_type{R<:Union{AbstractRow, AbstractTable}}(::Type{R}, newname::Symbol) = Column{newname}

"""
    row_type(InType, [names])

Returns a subtype of `AbstractRow` that is similar to `InType` but optionally
with modified fieldname `names = (name1, name2, ...)`. The element types remain
undefined.
"""
@pure row_type{C<:Union{AbstractCell, AbstractColumn}}(::Type{C}) = row_type(C, (name(C),))
@pure row_type{R<:Union{AbstractRow, AbstractTable}}(::Type{R}) = row_type(R, names(R))

# Defaults to `Row`
@pure row_type{C<:Union{AbstractCell, AbstractColumn}}(::Type{C}, newnames::Tuple{Vararg{Symbol}}) = Row{newnames}
@pure row_type{R<:Union{AbstractRow, AbstractTable}}(::Type{R}, newnames::Tuple{Vararg{Symbol}}) = Row{newnames}

"""
    table_type(InType, [names])

Returns a subtype of `AbstractTable` that is similar to `InType` but optionally
with modified fieldname `names = (name1, name2, ...)`. The storage types remain
undefined.
"""
@pure table_type{C<:Union{AbstractCell, AbstractColumn}}(::Type{C}) = table_type(C, (name(C),))
@pure table_type{Tbl<:Union{AbstractRow, AbstractTable}}(::Type{Tbl}) = table_type(R, names(R))

# Defaults to `Table`
@pure table_type{C<:Union{AbstractCell, AbstractColumn}}(::Type{C}, newnames::Tuple{Vararg{Symbol}}) = Table{newnames}
@pure table_type{Tbl<:Union{AbstractRow, AbstractTable}}(::Type{Tbl}, newnames::Tuple{Vararg{Symbol}}) = Table{newnames}



#
# Some sensible defaults for compact storage for large amounts of data
#

storage_type{T}(::Type{T}) = Vector{T}
storage_type{N<:Nullable}(::Type{N}) = NullableVector{eltype(N)}
storage_type(::Type{Bool}) = BitVector

@pure storage_types{Types<:Tuple}(::Type{Types}) = Tuple{map(storage_type, Types.parameters)...}
