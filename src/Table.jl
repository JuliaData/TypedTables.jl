# ======================================
#    Tables
# ======================================

"""
AbstractTable{Index,Key} represents tables with a given set of indices (a
FieldIndex) and a key (either one of the fields in FieldIndex, or else
DefaultKey(), which represents the intrinsic row number of a table)
"""
abstract AbstractTable{Index,Key}
@inline index{Index,Key}(::AbstractTable{Index,Key}) = Index
@inline eltypes{Index,Key}(::AbstractTable{Index,Key}) = eltypes(Index)
@inline Base.names{Index,Key}(::AbstractTable{Index,Key}) = names(Index)
@inline key{Index,Key}(::AbstractTable{Index,Key}) = Key
@inline Base.keytype{Index,Key}(::AbstractTable{Index,Key}) = eltype(Key)
@inline keyname{Index,Key}(::AbstractTable{Index,Key}) = name(Key)

"""
A table stores the data as a vector of row-tuples.
"""
immutable Table{Index, ElTypes <: Tuple, StorageTypes <: Tuple} <: AbstractTable{Index,DefaultKey()}
    data::StorageTypes

    function Table(data_in, check_sizes::Type{Val{true}} = Val{true})
        check_table(Index,ElTypes,StorageTypes)
        ls = map(length,data_in)
        for i in 2:length(data_in)
            if ls[i] != ls[1]
                error("Column inputs must be same length.")
            end
        end
        new(data_in)
    end

    function Table(data_in, check_sizes::Type{Val{false}})
        check_table(Index,ElTypes,StorageTypes)
        new(data_in)
    end
end

@generated function check_table{Index <: FieldIndex, ElTypes <: Tuple, StorageTypes <: Tuple}(::Index,::Type{ElTypes},::Type{StorageTypes})
    try
        types = (eltypes(Index).parameters...)
        given_eltypes = (ElTypes.parameters...)
        storage_eltypes = ntuple(i->eltype(StorageTypes.parameters[i]), length(StorageTypes.parameters))
        if types == given_eltypes
            if types == storage_eltypes
                return nothing
            else
                str = "Storage types $StorageTypes do not match Index $Index"
                return :(error($str))
            end
        else
            str = "Element types $ElTypes do not match Index $Index"
            return :(error($str))
        end
    catch
        return :(error("Error with table parameters"))
    end
end

function check_table(a,b)
    error("Error with table parameters")
end

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
