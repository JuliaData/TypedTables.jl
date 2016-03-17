
"""
A Column is a vector (or other store) of data annotated by a Field name
"""
immutable Column{F, ElType, StorageType}
    data::StorageType
    function Column(x::StorageType)
        check_Column(F,ElType,StorageType)
        new(x)
    end
end
@generated Column{F<:Field,StorageType}(::F,x::StorageType) = :(Column{$(F()),$(eltype(F())),$StorageType}(x) )
@generated Column{Name,T}(::Field{Name,T}) = :(Column{$(Field{Name,T}()),T,$(makestoragetype(T))}($(makestoragetype(T))()) )
@generated Column{Name,T}(::Field{Name,T},x::T...) = :(Column{$(Field{Name,T}()),T,$(makestoragetype(T))}($(makestoragetype(T))([x...])) )

@generated Column{F,ElType}(x::Cell{F,ElType}...) = :(Column{$(F),$ElType,$(makestoragetype(ElType))}($(makestoragetype(ElType))($ElType[x[i].data for i=1:length(x)])) )

@generated function Base.call{Name,T1,T2}(::Field{Name,T1},x::T2)
    if eltype(T2) == T1 # We have another method for creating a cell if T1==T2
        return :(Column{$(Field{Name,T1}()),$T1,$T2}(x))
    else
        str = "Can't instantiate a Cell or Column of $(Field{Name,T1}()) with a $T2"
    end
end

makestoragetype{T}(::Type{Nullable{T}}) = NullableVector{T}
makestoragetype{T}(::Type{T}) = Vector{T}


Base.convert{F,ElType,StorageType}(::Type{Ref{StorageType}},x::Column{F,ElType,Ref{StorageType}}) = x.data # Not even possible, but it stops a silly ambiguity warning
Base.convert{F,ElType,StorageType}(::Type{StorageType},x::Column{F,ElType,StorageType}) = x.data

@generated function check_Column{F,ElType,StorageType}(::F,::Type{ElType},::Type{StorageType})
    if !isa(F(),Field)
        return :(error("Field $F should be an instance of field"))
    elseif eltype(F()) != ElType
        return :(error("ElType $ElType do not match fieldtype $F"))
    elseif eltype(StorageType) != eltype(F())
        return :(error("Elements of StorageType $StorageType do not match fieldtype $F"))
    else
        return nothing
    end
end

function Base.show{F,ElType,StorageType}(io::IO,x::Column{F,ElType,StorageType})
    if isempty(x)
        print(io, "Empty ")
    end
    println(io, "Column $F")
    Base.showarray(x.data,header=false)
end

=={F,ElType,StorageType}(col1::Column{F,ElType,StorageType},col2::Column{F,ElType,StorageType}) = (col1.data == col2.data)


@inline name{F,ElType,StorageType}(::Column{F,ElType,StorageType}) = name(F)
@inline name{F,ElType,StorageType}(::Type{Column{F,ElType,StorageType}}) = name(F)
@inline Base.eltype{F,ElType,StorageType}(::Column{F,ElType,StorageType}) = eltype(StorageType)
@inline Base.eltype{F,ElType,StorageType}(::Type{Column{F,ElType,StorageType}}) = eltype(StorageType)
@inline field{F,ElType,StorageType}(::Column{F,ElType,StorageType}) = F
@inline field{F,ElType,StorageType}(::Type{Column{F,ElType,StorageType}}) = F

@inline samefield{F1,F2}(x::Column{F1},y::Column{F2}) = samefield(F1,F2)
@inline samefield{F1,F2}(x::Cell{F1},y::Column{F2}) = samefield(F1,F2)
@inline samefield{F1,F2}(x::Column{F1},y::Cell{F2}) = samefield(F1,F2)
@inline samefield{F1<:Field,F2}(x::F1,y::Column{F2}) = samefield(F1(),F2)
@inline samefield{F1,F2<:Field}(x::Column{F1},y::F2) = samefield(F1,F2())

@inline rename{F1,F2,ElType,StorageType}(x::Column{F1,ElType,StorageType},::F2) = rename(x,F1,F2())
@generated function rename{F1,F1_type,F2,ElType,StorageType}(x::Column{F1,ElType,StorageType},::F1_type,::F2)
    if F1_type() == F1
        return :(Column{$(F2()),ElType,StorageType}(x.data))
    else
        str = "Cannot rename: can't find field $F1"
        return :(error($str))
    end
end

# Vector-like introspection
Base.length{F,ElType,StorageType}(col::Column{F,ElType,StorageType}) = length(col.data)
ncol{F,ElType,StorageType}(col::Column{F,ElType,StorageType}) = 1
nrow{F,ElType,StorageType}(col::Column{F,ElType,StorageType}) = length(col.data)
Base.ndims{F,ElType,StorageType}(col::Column{F,ElType,StorageType}) = 1
Base.size{F,ElType,StorageType}(col::Column{F,ElType,StorageType}) = (length(col.data),)
Base.size{F,ElType,StorageType}(col::Column{F,ElType,StorageType},i::Int) = i == 1 ? length(col.data) : error("Columns are one-dimensional")
Base.isempty{F,ElType,StorageType}(col::Column{F,ElType,StorageType}) = isempty(col.data)
Base.endof{F,ElType,StorageType}(col::Column{F,ElType,StorageType}) = endof(col.data)

# Iterators
Base.start{F,ElType,StorageType}(col::Column{F,ElType,StorageType}) = start(col.data)
Base.next{F,ElType,StorageType}(col::Column{F,ElType,StorageType},i) = next(col.data,i)
Base.done{F,ElType,StorageType}(col::Column{F,ElType,StorageType},i) = done(col.data,i)

# get/set index
Base.getindex{F,ElType,StorageType}(col::Column{F,ElType,StorageType},idx::Int) = getindex(col.data,idx)
Base.getindex{F,ElType,StorageType}(col::Column{F,ElType,StorageType},idx) = Column(F,getindex(col.data,idx))

# Union seems to fail... annoying! (because of the Cell/Cell combination doesn't use all template parameters, that function signature is not callable...)
#Base.setindex!{F,ElType,StorageType}(col::Column{F,ElType,StorageType},val::Union{Column{F,ElType,StorageType},Cell{F,ElType}},idx) = setindex!(col.data,val.data,idx)
#Base.setindex!{F,ElType,StorageType}(col::Column{F,ElType,StorageType},val::Union{ElType,StorageType},idx) = setindex!(col.data,val,idx)
Base.setindex!{F,ElType}(col::Column{F,ElType,ElType},val::ElType,idx) = setindex!(col.data,val,idx) # To make Julia happy (maybe error??)
Base.setindex!{F,ElType,StorageType}(col::Column{F,ElType,StorageType},val::Cell{F,ElType},idx) = setindex!(col.data,val.data,idx)
Base.setindex!{F,ElType,StorageType}(col::Column{F,ElType,StorageType},val::ElType,idx) = setindex!(col.data,val,idx)
Base.setindex!{F,ElType,StorageType}(col::Column{F,ElType,StorageType},val::Column{F,ElType,StorageType},idx) = setindex!(col.data,val.data,idx)
Base.setindex!{F,ElType,StorageType}(col::Column{F,ElType,StorageType},val::StorageType,idx) = setindex!(col.data,val,idx)

Base.unsafe_getindex{F,ElType,StorageType}(col::Column{F,ElType,StorageType},idx::Int) = Cell(F,Base.unsafe_getindex(col.data,idx))
Base.unsafe_getindex{F,ElType,StorageType}(col::Column{F,ElType,StorageType},idx) = Column(F,Base.unsafe_getindex(col.data,idx))

# Union seems to fail... annoying!
#Base.unsafe_setindex!{F,ElType,StorageType}(col::Column{F,ElType,StorageType},val::Union{Column{F,ElType,StorageType},Cell{F,ElType}},idx) = Base.unsafe_setindex!(col.data,val.data,idx)
#Base.unsafe_setindex!{F,ElType,StorageType}(col::Column{F,ElType,StorageType},val::Union{ElType,StorageType},idx) = Base.unsafe_setindex!(col.data,val,idx)
Base.unsafe_setindex!{F,ElType}(col::Column{F,ElType,ElType},val::ElType,idx) = Base.unsafe_setindex!(col.data,val,idx) # To make Julia happy (maybe error??)
Base.unsafe_setindex!{F,ElType,StorageType}(col::Column{F,ElType,StorageType},val::Cell{F,ElType},idx) = Base.unsafe_setindex!(col.data,val.data,idx)
Base.unsafe_setindex!{F,ElType,StorageType}(col::Column{F,ElType,StorageType},val::ElType,idx) = Base.unsafe_setindex!(col.data,val,idx)
Base.unsafe_setindex!{F,ElType,StorageType}(col::Column{F,ElType,StorageType},val::Column{F,StorageType},idx) = Base.unsafe_setindex!(col.data,val.data,idx)
Base.unsafe_setindex!{F,ElType,StorageType}(col::Column{F,ElType,StorageType},val::StorageType,idx) = Base.unsafe_setindex!(col.data,val,idx)

# Mutators: Push!, append!, pop!, etc
Base.push!{F}(col::Column{F},cell::Cell{F}) = push!(col.data,cell.data)
Base.push!{F,ElType}(col::Column{F,ElType},data_in::ElType) = push!(col.data,data_in)
Base.append!{F,ElType,StorageType}(col::Column{F,ElType,StorageType},col_in::Column{F,ElType,StorageType}) = append!(col.data,col_in.data)
Base.append!{F,ElType,StorageType}(col::Column{F,ElType,StorageType},data_in::StorageType) = append!(col.data,data_in)
Base.pop!{F,ElType,StorageType}(col::Column{F,ElType,StorageType}) = pop!(col.data)

Base.unshift!{F}(col::Column{F},cell::Cell{F}) = unshift!(col.data,cell.data)
Base.unshift!{F,ElType}(col::Column{F,ElType},data_in::ElType) = unshift!(col.data,data_in)
Base.prepend!{F,ElType,StorageType}(col::Column{F,ElType,StorageType},col_in::Column{F,ElType,StorageType}) = prepend!(col.data,col_in.data)
Base.prepend!{F,ElType,StorageType}(col::Column{F,ElType,StorageType},data_in::StorageType) = prepend!(col.data,data_in)
Base.shift!{F,ElType,StorageType}(col::Column{F,ElType,StorageType}) = shift!(col.data)

Base.empty!{F,ElType,StorageType}(col::Column{F,ElType,StorageType}) = empty!(col.data)

# insert!, splice!, deleteat!
# resize! ?
# unique/unique! (union, etc??)

Base.sort{F, ElType, StorageType}(col::Column{F, ElType, StorageType}; kwargs...) = Column{F, ElType, StorageType}(sort(col.data; kwargs...))
Base.sort!{F, ElType, StorageType}(col::Column{F, ElType, StorageType}; kwargs...) = sort!(col.data; kwargs...)

#function Base.unique{F, ElType, StorageType}(col::Column{F, ElType, StorageType}; kwargs...)
#    tmp = sort(col)
#
#        Column{F, ElType, StorageType}(unique(col.data; kwargs...))
#
#end
Base.sort!{F, ElType, StorageType}(col::Column{F, ElType, StorageType}; kwargs...) = sort!(col.data; kwargs...)


# Some non-mutating functions
# something like join.... union? similarly for joins: outer, left, etc. Also, find.

Base.copy{F,ElType,StorageType}(col::Column{F,ElType,StorageType}) = Column{F,ElType,StorageType}(copy(col.data))
Base.deepcopy{F,ElType,StorageType}(col::Column{F,ElType,StorageType}) = Column{F,ElType,StorageType}(deepcopy(col.data))

# Concatenate cells and columns into colums
Base.vcat{F,ElType}(cell::Cell{F,ElType}) = Column{F,ElType,Vector{ElType}}([cell.data])
Base.vcat{F,ElType,StorageType}(col::Column{F,ElType,StorageType}) = Column{F,ElType,Vector{ElType}}(col.data)

Base.vcat{F,ElType}(cell1::Cell{F,ElType},cell2::Cell{F,ElType}) = Column{F,ElType,Vector{ElType}}(vcat(cell1.data,cell2.data))
Base.vcat{F,StorageType,ElType}(cell1::Cell{F,ElType},col2::Column{F,ElType,StorageType}) = Column{F,ElType,StorageType}(vcat(cell1.data,col2.data))
Base.vcat{F,StorageType,ElType}(col1::Column{F,ElType,StorageType},cell2::Cell{F,ElType}) = Column{F,ElType,StorageType}(vcat(col1.data,cell2.data))
Base.vcat{F,ElType,StorageType}(col1::Column{F,ElType,StorageType},col2::Column{F,ElType,StorageType}) = Column{F,ElType,StorageType}(vcat(col1.data,col2.data))

Base.vcat{F,ElType}(c1::Cell{F,ElType},c2::Cell{F,ElType},cs::Cell{F,ElType}...) = vcat(vcat(c1,c2),cs...)
Base.vcat{F,ElType,StorageType}(c1::Union{Cell{F,ElType},Column{F,ElType,StorageType}},c2::Union{Cell{F,ElType},Column{F,ElType,StorageType}},cs::Union{Cell{F,ElType},Column{F,ElType,StorageType}}...) = vcat(vcat(c1,c2),cs...)


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
        field = :(TypedTables.Field{$(Expr(:quote,expr.args[1].args[1])),$(expr.args[1].args[2])}())
    else
        error("Expecting expression like @column(name::Type = value) or @cell(field = value)")
    end
    value = expr.args[2]
    return :(TypedTables.Column($(esc(field)),$(esc(value))))
end
