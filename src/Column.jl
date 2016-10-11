
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

@inline (::Type{Column{Name}}){Name, T}(::Type{T}) = Column{Name}(makestoragetype(T)())
@inline (::Type{Column{Name}}){Name, T}(::Type{T}, len::Integer) = Column{Name}(makestoragetype(T)(len))

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
#@inline Base.eltype{Name, StorageType}(::Type{Column{Name, StorageType}}) = eltype(StorageType)
#@inline storagetype{Name, StorageType}(::Type{Column{Name, StorageType}}) = StorageType

#=
@compat Base.:(==){Name}(col1::Column{Name}, col2::Column{Name}) = (col1.data == col2.data)

@inline rename{Name1, Name2, ElType}(x::Column{Name1, ElType}, ::Type{Val{Name2}}) = Column{Name2, ElType}(x.data)

@pure name{Name}(::Type{Column{Name}}) = Name
@pure name{Name, StorageType}(::Type{Column{Name, StorageType}}) = Name
@inline Base.eltype{Name, StorageType}(::Type{Column{Name, StorageType}}) = eltype(StorageType)
@inline storagetype{Name, StorageType}(::Type{Column{Name, StorageType}}) = StorageType

@inline nrow{Name, StorageType}(col::Column{Name, StorageType}) = length(col.data)
@inline ncol{Name, StorageType}(col::Column{Name, StorageType}) = 1
@inline ncol{C <: Column}(::Type{C}) = 1

Base.getindex{Name}(c::Column{Name}, ::Type{Val{Name}}) = c.data
Base.getindex{Name1, Name2}(c::Column{Name1}, ::Type{Val{Name2}}) = error("Tried to index column of name :$Name1 with name :$Name2")
Base.getindex{Name}(c::Column{Name}, ::Type{Val{:Row}}) = 1:length(c.data)

@inline Base.length{Name, StorageType}(col::Column{Name, StorageType}) = length(col.data)
Base.ndims{Name, StorageType}(col::Column{Name, StorageType}) = 1
Base.size{Name, StorageType}(col::Column{Name, StorageType}) = (length(col.data),)
Base.size{Name, StorageType}(col::Column{Name, StorageType}, i::Int) = i == 1 ? length(col.data) : error("Columns are one-dimensional")
Base.isempty{Name, StorageType}(col::Column{Name, StorageType}) = isempty(col.data)
Base.endof{Name, StorageType}(col::Column{Name, StorageType}) = endof(col.data)

# Iterators
Base.start{Name, StorageType}(col::Column{Name, StorageType}) = start(col.data)
Base.next{Name, StorageType}(col::Column{Name, StorageType}, i) = next(col.data, i)
Base.done{Name, StorageType}(col::Column{Name, StorageType}, i) = done(col.data, i)

# get/set index
Base.getindex{Name, StorageType}(col::Column{Name, StorageType}, idx::Int) = getindex(col.data, idx)
Base.getindex{Name, StorageType}(col::Column{Name, StorageType}, idx) = Column{Name}(getindex(col.data, idx))

Base.setindex!{Name, StorageType}(col::Column{Name, StorageType}, val::Cell{Name}, idx::Integer) = setindex!(col.data, val.data, idx)
Base.setindex!{Name, StorageType}(col::Column{Name, StorageType}, val::Column{Name}, idx) = setindex!(col.data, val.data, idx)
Base.setindex!{Name, StorageType}(col::Column{Name, StorageType}, val, idx) = setindex!(col.data, val, idx)

Base.unsafe_getindex{Name, StorageType}(col::Column{Name, StorageType}, idx::Int) = unsafe_getindex(col.data, idx)
Base.unsafe_getindex{Name, StorageType}(col::Column{Name, StorageType}, idx) = Column{Name}(unsafe_getindex(col.data, idx))

Base.unsafe_setindex!{Name, StorageType}(col::Column{Name, StorageType}, val::Cell{Name}, idx::Integer) = unsafe_setindex!(col.data, val.data, idx)
Base.unsafe_setindex!{Name, StorageType}(col::Column{Name, StorageType}, val::Column{Name}, idx) = unsafe_setindex!(col.data, val.data, idx)
Base.unsafe_setindex!{Name, StorageType}(col::Column{Name, StorageType}, val, idx) = unsafe_setindex!(col.data, val, idx)

# Mutators: push!, append!, pop!, etc
Base.pop!(col::Column) = pop!(col.data)
Base.shift!(col::Column) = shift!(col.data)

Base.push!(col::Column, data_in) = (push!(col.data, data_in); col)
Base.push!{Name}(col::Column{Name}, cell::Cell{Name}) = (push!(col.data, cell.data); col)
Base.push!{Name}(col::Column{Name}, i::Integer, cell::Cell) = error("Column with name :$Name don't match cell with name :$(name(cell))")
Base.unshift!(col::Column, data_in) = (unshift!(col.data, data_in); col)
Base.unshift!{Name}(col::Column{Name}, cell::Cell{Name}) = (unshift!(col.data, cell.data); col)
Base.unshift!{Name}(col::Column{Name}, i::Integer, cell::Cell) = error("Column with name :$Name don't match cell with name :$(name(cell))")

Base.append!(col::Column, data_in) = (append!(col.data, data_in); col)
Base.append!{Name}(col::Column{Name}, cell::Column{Name}) = (append!(col.data, cell.data); col)
Base.append!{Name}(col::Column{Name}, i::Integer, cell::Cell) = error("Column with name :$Name don't match column with name :$(name(cell))")
Base.prepend!(col::Column, data_in) = (prepend!(col.data, data_in); col)
Base.prepend!{Name}(col::Column{Name}, cell::Column{Name}) = (prepend!(col.data, cell.data); col)
Base.prepend!{Name}(col::Column{Name}, i::Integer, cell::Cell) = error("Column with name :$Name don't match column with name :$(name(cell))")

Base.insert!(col::Column, i::Integer, v) = (insert!(col.data, i, v); col)
Base.insert!{Name}(col::Column{Name}, i::Integer, cell::Cell{Name}) = (insert!(col.data, i, cell.data); col)
Base.insert!{Name}(col::Column{Name}, i::Integer, cell::Cell) = error("Column with name :$Name don't match cell with name :$(name(cell))")
Base.deleteat!(col::Column, i) = (deleteat!(col.data, i); col)
Base.splice!{Name}(col::Column{Name}, i::Integer) = splice!(col.data, i)
Base.splice!{Name}(col::Column{Name}, i::Integer, r) = splice!(col.data, i, r)
Base.splice!{Name}(col::Column{Name}, i) = Column{Name}(splice!(col.data, i))
Base.splice!{Name}(col::Column{Name}, i, r) = Column{Name}(splice!(col.data, i, r))

Base.empty!(col::Column) = (empty!(col.data); col)

# unique/unique! (union, etc??)

Base.sort{Name, StorageType}(col::Column{Name, StorageType}; kwargs...) = Column{Name, StorageType}(sort(col.data; kwargs...))
Base.sort!(col::Column; kwargs...) = (sort!(col.data; kwargs...); col)

# Concatenate cells and columns into colums
Base.vcat{Name}(c1::Union{Cell{Name}, Column{Name}}) = Column{Name}(vcat(c1.data))
Base.vcat{Name}(c1::Union{Cell{Name}, Column{Name}}, c2::Union{Cell{Name}, Column{Name}}) = Column{Name}(vcat(c1.data, c2.data))
@generated function Base.vcat{Name}(c1::Union{Cell{Name}, Column{Name}}, c2::Union{Cell{Name}, Column{Name}}, cs::Union{Cell{Name}, Column{Name}}...)
    # Do our best to help inference here
    exprs = [:(cs[$j].data) for j = 1:length(cs)]
    vcat_expr = Expr(:call, :vcat, :(c1.data), :(c2.data), exprs...)
    return Expr(:call, Column{Name}, vcat_expr)
end

# copy
Base.copy{Name, StorageType}(col::Column{Name, StorageType}) = Column{Name, StorageType}(copy(col.data))
=#
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
