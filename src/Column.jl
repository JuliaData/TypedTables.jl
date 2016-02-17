
"""
A Column is a vector (or other store) of data annotated by a Field name
"""
immutable Column{F, StorageType}
    data::StorageType
    function Column(x::StorageType)
        check_Column(F,StorageType)
        new(x)
    end
end
@generated Column{F<:Field,StorageType}(::F,x::StorageType) = :(Column{$(F()),$StorageType}(x))
@generated Column{Name,T}(::Field{Name,T}) = :(Column{$(Field{Name,T}()),Vector{T}}(Vector{T}()))
@generated Column{F,CellType}(x::Cell{F,CellType}...) = :(Column{$(F()),Vector{$(eltype(F))}}([x[i].data for i=1:length(x)]))
@generated Column{Name,T}(::Field{Name,T},x::T...) = :(Column{$(Field{Name,T}()),Vector{T}}([x...]))

@generated function check_Column{F,StorageType}(::F,::Type{StorageType})
    if !isa(F(),Field)
        return :(error("Field $F should be an instance of field"))
    elseif eltype(StorageType) != eltype(F())
        return :(error("Elements of StorageType $StorageType do not match fieldtype $F"))
    else
        return nothing
    end
end

function Base.show{F,StorageType}(io::IO,x::Column{F,StorageType})
    print(io, "Column $F")
    show(x.data)
end


@inline name{F,StorageType}(::Column{F,StorageType}) = name(F)
@inline name{F,StorageType}(::Type{Column{F,StorageType}}) = name(F)
@inline Base.eltype{F,StorageType}(::Column{F,StorageType}) = eltype(StorageType)
@inline Base.eltype{F,StorageType}(::Type{Column{F,StorageType}}) = eltype(StorageType)
@inline field{F,StorageType}(::Column{F,StorageType}) = F
@inline field{F,StorageType}(::Type{Column{F,StorageType}}) = F

@inline rename{F1,F2,StorageType}(x::Column{F1,StorageType},::F2) = rename(x,F1,F2())
@generated function rename{F1,F1_type,F2,StorageType}(x::Column{F1,StorageType},::F1_type,::F2)
    if F1_type() == F1
        return :(Column{$(F2()),StorageType}(x.data))
    else
        str = "Cannot rename: can't find field $F1"
        return :(error($str))
    end
end

# Vector-like introspection
Base.length{F,StorageType}(col::Column{F,StorageType}) = length(col.data)
ncol{F,StorageType}(col::Column{F,StorageType}) = 1
nrow{F,StorageType}(col::Column{F,StorageType}) = length(col.data)
Base.ndims{F,StorageType}(col::Column{F,StorageType}) = 1
Base.size{F,StorageType}(col::Column{F,StorageType}) = (length(col.data),)
Base.size{F,StorageType}(col::Column{F,StorageType},i::Int) = i == 1 ? length(col.data) : error("Columns are one-dimensional")
@generated Base.eltype{F,StorageType}(col::Column{F,StorageType}) = :($(eltype(StorageType)))
Base.isempty{F,StorageType}(col::Column{F,StorageType}) = isempty(col.data)
Base.endof{F,StorageType}(col::Column{F,StorageType}) = endof(col.data)

# Iterators
Base.start{F,StorageType}(col::Column{F,StorageType}) = 1
Base.next{F,StorageType}(col::Column{F,StorageType},i) = (col.data[i],i+1)
Base.done{F,StorageType}(col::Column{F,StorageType},i) = (i-1 == length(col.data))

# get/set index
Base.getindex{F,StorageType}(col::Column{F,StorageType},idx::Int) = Cell(F,getindex(col.data,idx))
Base.getindex{F,StorageType}(col::Column{F,StorageType},idx) = Column(F,getindex(col.data,idx))

Base.setindex!{F,StorageType}(col::Column{F,StorageType},val::Cell{F},idx::Int) = setindex!(col.data,val.data,idx)
Base.setindex!{F,StorageType}(col::Column{F,StorageType},val::Column{F},idx) = setindex!(col.data,val.data,idx)
Base.setindex!{F,StorageType}(col::Column{F,StorageType},val,idx::Int) = setindex!(col.data,val,idx)
Base.setindex!{F,StorageType}(col::Column{F,StorageType},val::StorageType,idx) = setindex!(col.data,val,idx)

Base.unsafe_getindex{F,StorageType}(col::Column{F,StorageType},idx::Int) = Cell(F,Base.unsafe_getindex(col.data,idx))
Base.unsafe_getindex{F,StorageType}(col::Column{F,StorageType},idx) = Column(F,Base.unsafe_getindex(col.data,idx))
Base.unsafe_setindex!{F,StorageType}(col::Column{F,StorageType},val::Cell{F},idx::Int) = Base.unsafe_setindex!(col.data,val.data,idx)
Base.unsafe_setindex!{F,StorageType}(col::Column{F,StorageType},val::Column{F},idx) = Base.unsafe_setindex!(col.data,val.data,idx)
Base.unsafe_setindex!{F,StorageType}(col::Column{F,StorageType},val,idx::Int) = Base.unsafe_setindex!(col.data,val,idx)
Base.unsafe_setindex!{F,StorageType}(col::Column{F,StorageType},val::StorageType,idx) = Base.unsafe_setindex!(col.data,val,idx)

# Mutators: Push!, append!, pop!, etc
Base.push!{F}(col::Column{F},cell::Cell{F}) = push!(col.data,cell.data)
Base.push!{F,DataType}(col::Column{F},data_in::DataType) = push!(col.data,data_in)
Base.append!{F,StorageType}(col::Column{F,StorageType},col_in::Column{F,StorageType}) = append!(col.data,col_in.data)
Base.append!{F,StorageType}(col::Column{F,StorageType},data_in::StorageType) = append!(col.data,data_in)
Base.pop!{F,StorageType}(col::Column{F,StorageType}) = pop!(col.data)

Base.unshift!{F}(col::Column{F},cell::Cell{F}) = unshift!(col.data,cell.data)
Base.unshift!{F,DataType}(col::Column{F},data_in::DataType) = unshift!(col.data,data_in)
Base.prepend!{F,StorageType}(col::Column{F,StorageType},col_in::Column{F,StorageType}) = prepend!(col.data,col_in.data)
Base.prepend!{F,StorageType}(col::Column{F,StorageType},data_in::StorageType) = prepend!(col.data,data_in)
Base.shift!{F,StorageType}(col::Column{F,StorageType}) = shift!(col.data)

Base.empty!{F,StorageType}(col::Column{F,StorageType}) = empty!(col.data)


# insert!, splice!, deleteat!
# resize! ?
# unique! (union, etc??)


# Some non-mutating functions
# something like join.... union? similarly for joins: outer, left, etc. Also, find.

Base.copy{F,StorageType}(col::Column{F,StorageType}) = Column{F,StorageType}(copy(col.data))
Base.deepcopy{F,StorageType}(col::Column{F,StorageType}) = Column{F,StorageType}(copy(col.data))

# Fix vcat for more or less than 2 arguments.
Base.vcat{F,CellType}(cell1::Cell{F,CellType},cell2::Cell{F,CellType}) = Column{F,Vector{CellType}}(vcat(cell1.data,cell2.data))
Base.vcat{F,StorageType,CellType}(cell1::Cell{F,CellType},col2::Column{F,StorageType}) = Column{F,StorageType}(vcat(cell1.data,col2.data))
Base.vcat{F,StorageType,CellType}(col1::Column{F,StorageType},cell2::Cell{F,CellType}) = Column{F,StorageType}(vcat(col1.data,cell2.data))
@generated Base.vcat{F,StorageType}(col1::Column{F,StorageType},col2::Column{F,StorageType}) = :(Column{$F,$StorageType}(vcat(col1.data,col2.data)))


# Currently @column and @cell do the same thing, by calling field
macro column(expr)
    if expr.head != :(=) && expr.head != :(kw) # strange Julia bug, see issue 7669
        error("Expecting expression like @column(name::Type = value) or @column(field = value)")
    end
    local field
    if isa(expr.args[1],Symbol)
        field = expr.args[1]
    elseif isa(expr.args[1],Expr)
        if expr.args[1].head != :(::) || length(expr.args[1].args) != 2
            error("Expecting expression like @column(name::Type = value) or @cell(field = value)")
        end
        field = :(Tables.Field{$(Expr(:quote,expr.args[1].args[1])),$(expr.args[1].args[2])}())
    else
        error("Expecting expression like @column(name::Type = value) or @cell(field = value)")
    end
    value = expr.args[2]
    return :($field($value))
end
