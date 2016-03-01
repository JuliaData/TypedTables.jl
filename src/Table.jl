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

@generated Table{Index<:FieldIndex,StorageTypes<:Tuple}(::Index,data_in::StorageTypes,check_sizes::Union{Type{Val{true}},Type{Val{false}}} = Val{true}) = :(Table{$(Index()),$(eltypes(Index)),$StorageTypes}(data_in,check_sizes))
@generated Table{Index<:FieldIndex}(::Index,check_sizes::Union{Type{Val{true}},Type{Val{false}}} = Val{true}) = :(Table{$(Index()),$(eltypes(Index)),$(makestoragetypes(eltypes(Index)))}($(instantiate_tuple(makestoragetypes(eltypes(Index)))),check_sizes))
@generated Table{Index<:FieldIndex}(::Index,check_sizes::Union{Type{Val{true}},Type{Val{false}}} = Val{true}) = :(Table{$(Index()),$(eltypes(Index)),$(makestoragetypes(eltypes(Index)))}($(instantiate_tuple(makestoragetypes(eltypes(Index)))),check_sizes))


@generated function makestoragetypes{T<:Tuple}(::Type{T})
    eltypes = T.parameters
    storagetypes = Vector{DataType}(length(eltypes))
    for i = 1:length(eltypes)
        storagetypes[i] = makestoragetype(eltypes[i])
    end
    return :(Tuple{$(storagetypes...)} )
end



=={F,ElTypes,StorageType}(table1::Table{F,ElTypes,StorageType},table2::Table{F,ElTypes,StorageType}) = (table1.data == table2.data)


# Conversion between Dense and normal Tables??
# Some more convient versions. (a) One that takes pairs of fields and storage.
#                              (b) A macro @table(x=[1,2,3],y=["a","b","c"]) -> Table(Field{:x,eltype([1,2,3)}()=>[1,2,3], Field{:y,eltype{["a","b","c"]}()=>["a","b","c"])


# Data from the index
Base.names{Index}(table::Table{Index}) = names(Index)
eltypes{Index}(table::Table{Index}) = eltypes(Index)
@generated rename{Index,ElTypes,StorageTypes,NewIndex<:FieldIndex}(table::Table{Index,ElTypes,StorageTypes}, new_names::NewIndex) = :( Table{$(rename(Index,NewIndex())),$ElTypes,$StorageTypes}(table.data, Val{false}) )
@generated rename{Index,ElTypes,DataTypes,OldFields,NewFields}(table::Table{Index,ElTypes,DataTypes}, old_names::OldFields, ::NewFields) = :(Table($(rename(Index,OldFields(),NewFields())),table.data, Val{false}))

# Vector-like introspection
Base.length{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = length(table.data[1])
@generated ncol{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = :($(length(Index)))
nrow{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = length(table.data[1])
Base.size{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = (length(table.data[1]),length(Index))
Base.size{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},i::Int) = i == 2 ? length(Index) : (i == 1 ? length(table.data[1]) : error("Tables are two-dimensional"))
@generated Base.eltype{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = :($(eltypes(Index)))
Base.isempty{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = isempty(table.data[1])
Base.endof{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = endof(table.data[1])
index{Index}(table::Table{Index}) = Index


# Iterators
Base.start{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = 1
Base.next{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},i) = (table[i],i+1)
Base.done{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},i) = (i-1 == length(table))

# get/set index
Base.getindex{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},idx::Int) = Row(Index,ntuple(i->getindex(table.data[i],idx),length(Index)))
Base.getindex{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},idx) = Table(Index,ntuple(i->getindex(table.data[i],idx),length(Index)))

Base.setindex!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},val::Row{Index},idx::Int) = (for i = 1:length(Index); setindex!(table.data[i],val.data[i],idx); end; val)
Base.setindex!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},val::Table{Index,ElTypes, StorageTypes},idx) = (for i = 1:length(Index); setindex!(table.data[i],val.data[i],idx); end; val)

Base.unsafe_getindex{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},idx::Int) = Row(Index,ntuple(i->unsafe_getindex(table.data[i],idx),length(Index)))
Base.unsafe_getindex{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},idx) = Table(Index,ntuple(i->Base.unsafe_getindex(table.data[i],idx),length(Index)))
Base.unsafe_setindex!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},val::Row{Index},idx::Int) = for i = 1:length(Index); Base.unsafe_setindex!(table.data[i],val.data[i],idx); end
Base.unsafe_setindex!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},val::Table{Index,StorageTypes},idx) = for i = 1:length(Index); Base.unsafe_setindex!(table.data[i],val.data[i],idx); end


# Push, append, pop
function Base.push!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},row::Row{Index,ElTypes})
    for i = 1:length(Index)
        push!(table.data[i],row.data[i])
    end
    table
end
@inline Base.push!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},data_in::ElTypes) = push!(table, Row{Index,ElTypes}(data_in))
@inline Base.push!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},data_in...) = push!(table,((data_in...))) # TODO check if slow?
function Base.append!{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes},table_in::Table{Index,ElTypes,StorageTypes})
    for i in 1:length(Index)
        append!(table.data[i],table_in.data[i])
    end
end
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
    println(io,"$(ncol(table))-column, $(nrow(table))-row Table{$Index,$StorageTypes}")
end

#  ┌─┬┐
#  ├─┼┤
#  │ ││
#  └─┴┘


_displaysize(io) = haskey(io, :displaysize) ? io[:displaysize] : _displaysize(io.io)

function Base.show{Index,ElTypes,StorageTypes}(io::IO,table::Table{Index,ElTypes,StorageTypes})
    summary(io,table)
    s = Base.tty_size()
    l = max(5,div(s[1],5))

    if length(table) > 2*l
        for i = 1:l
            println(io,i," ",table[i])
        end
        for i = 0:ncol(table)
            print("⋮  ")
        end
        println()
        for i = endof(table)-l:endof(table)
            if i == endof(table)
                print(io,i," ",table[i])
            else
                println(io,i," ",table[i])
            end
        end
    else
        for i = 1:length(table)
            if i == endof(table)
                print(io,i," ",table[i])
            else
                println(io,i," ",table[i])
            end
        end
    end
end

function Base.showall{Index,ElTypes,StorageTypes}(io::IO,table::Table{Index,ElTypes,StorageTypes})
    summary(io,table)
    for i = 1:length(table)
        if i == endof(table)
            print(io,i," ",table[i])
        else
            println(io,i," ",table[i])
        end
    end
end

head(t::Table, n = 5) = length(t) >= n ? t[1:n] : t
tail(t::Table, n = 5) = length(t) >= n ? t[end-n+1:end] : t

# Can create a subtable easily by selecting columns
Base.getindex{Index,ElTypes,StorageTypes,F<:Field}(table::Table{Index,ElTypes,StorageTypes},::F) = table.data[Index[F()]]
Base.getindex{Index,ElTypes,StorageTypes,F<:DefaultKey}(table::Table{Index,ElTypes,StorageTypes},::F) = 1:length(table.data[1])
Base.getindex{Index,ElTypes,StorageTypes,NewIndex<:FieldIndex}(table::Table{Index,ElTypes,StorageTypes},::NewIndex) = table.data[Index[NewIndex]] # Probably

@generated function Base.getindex{Index,ElTypes,StorageTypes,NewIndex<:FieldIndex}(table::Table{Index,ElTypes,StorageTypes},::NewIndex) # Need special possibility for DefaultKey, which may or many not exist in array
    if issubset(NewIndex(),Index+DefaultKey())
        str = "("
        for i = 1:length(NewIndex())
            if NewIndex()[i] == DefaultKey()
                str *= "TableKey{Index,StorageTypes}(Ref(table))"
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

macro table(exprs...)
    N = length(exprs)
    field = Vector{Any}(N)
    value = Vector{Any}(N)
    for i = 1:N
        expr = exprs[i]
        if expr.head != :(=) && expr.head != :(kw) # strange Julia bug, see issue 7669
            error("A Expecting expression like @cell(name::Type = value) or @cell(field = value)")
        end
        if isa(expr.args[1],Symbol)
            field[i] = expr.args[1]
        elseif isa(expr.args[1],Expr)
            if expr.args[1].head != :(::) || length(expr.args[1].args) != 2
                error("B Expecting expression like @cell(name::Type = value) or @cell(field = value)")
            end
            field[i] = :(Tables.Field{$(Expr(:quote,expr.args[1].args[1])),$(expr.args[1].args[2])}())
        else
            error("C Expecting expression like @cell(name::Type = value) or @cell(field = value)")
        end
        value[i] = expr.args[2]
    end

    fields = Expr(:tuple,field...)
    values = Expr(:tuple,value...)

    return :(Tables.Table(Tables.FieldIndex{$(esc(fields))}(),$(esc(values))))
end



"This is a fake 'storage container' for the field DefaultKey() in a Table"
immutable TableKey{Index,ElTypes,StorageTypes}
    parent::Ref{Table{Index,ElTypes,StorageTypes}}
end
Base.getindex{Index,ElTypes,StorageTypes,T}(k::TableKey{Index,ElTypes,StorageTypes},i::T) = getindex(1:length(k.parent.x),i)
Base.length{Index,ElTypes,StorageTypes}(k::TableKey{Index,ElTypes,StorageTypes}) = length(k.parent.x)
Base.eltype(k::TableKey) = Int
Base.eltype{Index,ElTypes,StorageTypes}(k::Type{TableKey{Index,ElTypes,StorageTypes}}) = Int
Base.first{Index,ElTypes,StorageTypes}(::TableKey{Index,ElTypes,StorageTypes},i::Int) = 1
Base.next{Index,ElTypes,StorageTypes}(::TableKey{Index,ElTypes,StorageTypes},i::Int) = (i, i+1)
Base.done{Index,ElTypes,StorageTypes}(k::TableKey{Index,ElTypes,StorageTypes},i::Int) = (i-1) == length(k.parent.x)
Base.show(io::IO,k::TableKey) = show(io::IO,1:length(k.parent.x))
Base.copy(k::TableKey) = 1:length(k)

"""
A dense table stores the data as a vector of row-tuples.
"""
immutable DenseTable{Index,DataTypes} <: AbstractTable{Index,DefaultKey()}
    data::Vector{Row{Index,DataTypes}}

    function DenseTable(data_in)
        check_row(Index,DataTypes)
        new(data_in)
    end
end

DenseTable{Index}(::Index) = DenseTable{Index,eltypes(Index)}(Vector{Row{Index,eltypes(Index)}}())
DenseTable{Index,DataTypes}(::Index,data::Vector{DataTypes}) = DenseTable{Index,DataTypes}(Vector{Row{Index,DataTypes}}(data))
# Constructor that takes index and seperate values
# Conversion between Dense and normal Tables??
DenseTable{Index,StorageTypes}(table::Table{Index,StorageTypes}) = DenseTable(Index,collect(zip(table.data...)))



Base.length{Index,DataTypes}(table::DenseTable{Index,DataTypes}) = length(table.data)
Base.size{Index,DataTypes}(table::DenseTable{Index,DataTypes}) = (length(Index),length(table.data))
Base.size{Index,DataTypes}(table::DenseTable{Index,DataTypes},i::Int) = i == 1 ? length(Index) : (i == 2 ? length(table.data) : error("Tables are two-dimensional"))
Base.eltype{Index,DataTypes}(table::DenseTable{Index,DataTypes}) = eltype(table.data)

Base.push!{Index,DataTypes}(table::DenseTable{Index,DataTypes},row::Row{Index,DataTypes}) = push!(table.data,row)
Base.push!{Index,DataTypes}(table::DenseTable{Index,DataTypes},data_in::DataTypes) = push!(table.data,Row{Index,DataTypes}(data_in))
Base.push!{Index,DataTypes}(table::DenseTable{Index,DataTypes},data_in...) = push!(table,Row{Index,DataTypes}((data_in...))) # TODO probably slow
Base.append!{Index,DataTypes}(table::DenseTable{Index,DataTypes},table_in::DenseTable{Index,DataTypes}) = append!(table.data,table_in.data)
Base.append!{Index,DataTypes}(table::DenseTable{Index,DataTypes},rows::Vector{Row{Index,DataTypes}}) = append!(table.data,rows)

# Some output
function Base.summary{Index,DataTypes}(io::IO,table::DenseTable{Index,DataTypes})
    println(io,"$(length(table.data[1]))-row DenseTable with columns $Index")
end

function Base.show{Index,DataTypes}(io::IO,table::DenseTable{Index,DataTypes})
    summary(io,table)
    show(io,table.data)
end


"""
A key table stores the data as a set of dictionaries for each field.
"""
immutable KeyTable{Index,StorageTypes,Key,KeyType} <: AbstractTable{Index,Key}
    data::Dict{KeyType,StorageTypes}

    function KeyTable(data_in)
        check_table(Index,StorageTypes)
        check_key(Key,KeyType)
        new(data_in)
    end
end

@generated check_key{Key,KeyType}(::Key,::Type{KeyType}) = (eltype(Key()) == KeyType) ? (return nothing) : (str = "KeyType $KeyType doesn't match Key $Key"; return :(error(str)))

"""
A dense key table stores the data as a single dictionary of row-tuples.
"""
immutable DenseKeyTable{Index,DataTypes,Key,KeyType} <: AbstractTable{Index,Key}
    data::Dict{KeyType,Row{Index,DataTypes}}

    function DenseKeyTable(data_in)
        check_row(Index,DataTypes)
        check_key(Key,KeyType)
        new(data_in)
    end
end



#=

"""
A typed table is a vector list of several named fields. Each row of the table is
implemented as a fully-typed tuple (which may automatically expanded by Julia
for alignment purposes). Use of strides allows us to
"""
immutable TypedTable{FieldNames <: Tuple, FieldTypes <: Tuple} <: DenseVector{FieldTypes}
    data::Vector{FieldTypes}

    function TypedTable(data_in::Vector{FieldTypes})
        check_typedtable_params(FieldNames,FieldTypes)
        new(data_in)
    end
end

"Check that the parameters to a TypedTable are OK"
@generated function check_typedtable_params{FieldNames <: Tuple,FieldTypes <: Tuple}(::Type{FieldNames},::Type{FieldTypes})
    fnp = FieldNames.parameters
    ftp = FieldTypes.parameters

    if length(fnp) != length(ftp)
        return :(error("Malformed TypeTable{$FieldNames,$FieldTypes}: different number of field names and field types"))
    end

    if length(fnp) != length(unique(fnp))
        return :(error("Malformed TypeTable{$FieldNames,$FieldTypes}: field names must be unique"))
    end

    try
        for i = 1:length(fnp)
            fnp[i]::Symbol
        end
    catch
        return :(error("Malformed TypeTable{$FieldNames,$FieldTypes}: FieldNames must be Symbols"))
    end

    try
        for i = 1:length(ftp)
            ftp[i]::Type
        end
    catch
        return :(error("Malformed TypeTable{$FieldNames,$FieldTypes}: FieldTypes must be Types"))
    end

    return nothing
end

# Scalar indexing returns a row as a tuple (we *could* have a decorated type??)
Base.getindex(tt::TypedTable,i::Int) = tt.data[i]
Base.unsafe_getindex(tt::TypedTable,i::Int) = Base.unsafe_getindex(tt.data,i)

# For ranges, etc, create a new TypedTable with just those rows
Base.getindex{TT <: TypedTable}(tt::TT,i) = TT(tt.data[i])
Base.unsafe_getindex{TT <: TypedTable}(tt::TT,i) = TT(Base.unsafe_getindex(tt.data,i))

# Can overwrite rows with setindex!
Base.setindex!{FieldNames,FieldTypes}(tt::TypedTable{FieldNames,FieldTypes},i,val::Union{FieldTypes,Vector{FieldTypes}}) = setindex!(tt.data[x],i,val)
Base.setindex!{FieldNames,FieldTypes}(tt::TypedTable{FieldNames,FieldTypes},i,val::TypedTable{FieldNames,FieldTypes}) = setindex!(tt.data[x],i,val.data)

Base.unsafe_setindex!{FieldNames,FieldTypes}(tt::TypedTable{FieldNames,FieldTypes},i,val::Union{FieldTypes,Vector{FieldTypes}}) = Base.unsafe_setindex!(tt.data[x],i,val)
Base.unsafe_setindex!{FieldNames,FieldTypes}(tt::TypedTable{FieldNames,FieldTypes},i,val::TypedTable{FieldNames,FieldTypes}) = Base.unsafe_setindex!(tt.data[x],i,val.data)

# Copy, etc
Base.copy{FieldNames,FieldTypes}(tt::TypedTable{FieldNames,FieldTypes}) = TypedTable{FieldNames,FieldTypes}(copy(t.data))
Base.deepcopy{FieldNames,FieldTypes}(tt::TypedTable{FieldNames,FieldTypes}) = TypedTable{FieldNames,FieldTypes}(deepcopy(t.data))

# Some Vector-like characteristics
Base.eltype{FieldNames,FieldTypes}(::TypedTable{FieldNames,FieldTypes}) = FieldTypes
Base.length{FieldNames,FieldTypes}(tt::TypedTable{FieldNames,FieldTypes}) = length(tt.data)
Base.size{FieldNames,FieldTypes}(tt::TypedTable{FieldNames,FieldTypes},i) = size(tt.data,i)
Base.size{FieldNames,FieldTypes}(tt::TypedTable{FieldNames,FieldTypes}) = (size(tt.data,1),)
Base.elsize{FieldNames,FieldTypes}(::TypedTable{FieldNames,FieldTypes}) = sizeof(FieldTypes)
Base.ndims{FieldNames,FieldTypes}(::TypedTable{FieldNames,FieldTypes}) = 1

=#

#=
"""
TableRow - a single row of a TypedTable
"""
immutable TableRow{FieldNames <: Tuple, FieldTypes <: Tuple}
    data::FieldTypes

    function TypedTable(data_in::FieldTypes)
        check_typedtable_params(FieldNames,FieldTypes) # Luckily, can use same function
        new(data_in)
    end
end

Base.getindex{FieldNames,FieldTypes}(tr::TableRow{FieldNames,FieldTypes},i::Int) = tr.data[i]
@generated function Base.getindex{ColumnName,FieldNames,FieldTypes}(tr::TableRow{FieldNames,FieldTypes},::Type{Val{ColumnName}})
    fnp = FieldNames.parameters
    for j = 1:length(fnp)
        if fnp[j] == ColumnName
            return :(Base.getfield(tr.data,$j))
        end
    end
    return :(error("The column $ColumnName doesn't exist in the row with fields $FieldNames"))
end
# More than one column: give a new row, no?
# No setindex - they are immutable in this context

@generated function Base.convert{OldNames <: Tuple, OldTypes <: Tuple, NewNames,NewTypes}(::Type{TableRow{NewNames,NewTypes}},tr::TableRow{OldNames,OldTypes})
    if NewNames == OldNames && NewTypes == OldTypes
        return :(TypedTable{$NewNames,$NewTypes}(tr.data))
    end

    # Can reorder the fields
    newnames = [NewNames.parameters[i] for i = 1:length(NewNames.parameters)]
    oldnames = [OldNames.parameters[i] for i = 1:length(NewNames.parameters)]

    permuation = [(x = find(aa->newnames[i]==aa,oldnames); length(x) == 1 ? x[1] : 0) for i=1:length(newnames)]

    if length(newnames) == length(oldnames) && sum(find(x->x==0,permutation)) == 0
        # A simple permutation
    end
    # Should add the ability to add/remove fields if things are Nullable (with appropriate run-time checks for removing nullables).

    return :(error("Can't convert TypedTable{$OldNames,$OldTypes} into TypedTable{$NeWNames,$NewTypes}"))
end

#function Tuple_to_tuple{T <: Tuple}(in::T)
#end

#function tuple_to_Tuple(in)
#end =#

# Need a function (constructor) to make a typedtable from raw data (multiple columns)
#function TypedTable{FieldNames <: Tuple, FieldTypes <: Tuple}(varargs...)
#end

# Probably want a function to convert one TypedTable to another
# These could do the following: create a copy, create a permutation, create a
# copy with less columns, create a copy with additional columns
# (need to specify some default value, use a nullable type, or provide a full vector of data)
# or any combination of the above. All but additional columns make sense from
# `convert` (unless you consider columns an inexact error??)

# Need a way of extracting more than one column as a view. (A copy version could be defined
# as removing columns from a table). We would want our own "SubTable"-type thing, like SubColumn
# (might *also* want a view of the vectorized data of a normal/full TypedTable?)

#=

"""
A single column of a table that can be accessed and modified like any vector
(mutating the parent table in the process).
"""
immutable SubColumn{ColumnName, FieldNames <: Tuple, FieldTypes <: Tuple, IndexType}
    parent::TypedTable{FieldNames,FieldTypes}
    idx::IndexType

    function SubColumn(p::TypedTable{FieldNames,FieldTypes},i::IndexType)
        check_subcolumn_params(Val{ColumnName},FieldNames,FieldTypes,IndexType)
        new(p,i)
    end
end

"Check that the parameters to a TypedTable are OK"
@generated function check_subcolumn_params{ColumnName, FieldNames <: Tuple, FieldTypes <: Tuple, IndexType}(::Type{Val{ColumnName}}, ::Type{FieldNames}, ::Type{FieldTypes}, ::Type{IndexType})
    fnp = FieldNames.parameters

    match = 0
    for i = 1:length(fnp)
        if fnp[i] == ColumnName
            match += 1
        end
    end
    if match != 1
        return :(error("Malformed SubColumn{$ColumnName,$FieldNames,$FieldTypes,$IndexType}: the column $ColumnName doesn't exist in the table"))
    end

    if !method_exists(getindex,(Vector{FieldTypes},IndexType))
        return :(error("Malformed SubColumn{$ColumnName,$FieldNames,$FieldTypes,$IndexType}: indextype $IndexType can't index a vector"))
    end

    return nothing
end

# Constructors
SubColumn{ColumnName,FieldNames,FieldTypes}(p::TypedTable{FieldNames,FieldTypes},::Type{Val{ColumnName}}) = SubColumn{ColumnName,FieldNames,FieldTypes,Colon}(p,Colon())
SubColumn{ColumnName,FieldNames,FieldTypes,IndexType}(p::TypedTable{FieldNames,FieldTypes},::Type{Val{ColumnName}},idx::IndexType) = SubColumn{ColumnName,FieldNames,FieldTypes,IndexType}(p,idx)
Base.sub{ColumnName,FieldNames,FieldTypes}(tt::TypedTable{FieldNames,FieldTypes},col::Type{Val{ColumnName}}) = SubColumn(p,Val{ColumnName})
Base.sub{ColumnName,FieldNames,FieldTypes,IndexType}(tt::TypedTable{FieldNames,FieldTypes},col::Type{Val{ColumnName}},idx::IndexType) = SubColumn(p,Val{ColumnName},idx)

# Makes a copy
@generated function Base.convert{ColumnName,FieldNames,FieldTypes,IndexType,OutType}(::Type{Vector{OutType}},sc::SubColumn{ColumnName,FieldNames,FieldTypes,IndexType})
    fnp = FieldNames.parameters
    if IndexType == Colon
        l = :(length(sc.parent))
    else
        l = :(length(sc.idx))
    end

    # Could do something to make conversion from nullable arrays possible?

    for j = 1:length(fnp)
        if fnp[j] == ColumnName
            # Should I throw an error or not?
            #if !method_exists(Base.convert, (Type{OutType}, FieldTypes.parameters[j]))
            #    error("Cannot convert column type $(FieldTypes.parameters[j]) to $OutType")
            #end
            return :($(OutType)[sc.parent.data[sc.idx[i]][$j] for i = 1:$l])
        end
    end
end


@generated function Base.getindex{ColumnName,FieldNames,FieldTypes,IndexType}(sc::SubColumn{ColumnName,FieldNames,FieldTypes,IndexType}, i::Int)
    fnp = FieldNames.parameters
    for j = 1:length(fnp)
        if fnp[j] == ColumnName
            return :(sc.parent.data[sc.idx[i]][$j]) # Would be nice to do something like an unsafe_getindex/getfield for the tuple, but doesn't seem to exist?
        end
    end
end

@generated function Base.unsafe_getindex{ColumnName,FieldNames,FieldTypes,IndexType}(sc::SubColumn{ColumnName,FieldNames,FieldTypes,IndexType}, i::Int)
    fnp = FieldNames.parameters
    for j = 1:length(fnp)
        if fnp[j] == ColumnName
            return :(Base.getfield(Base.unsafe_getindex(sc.parent.data,sc.idx[i]),$j))
        end
    end
end

# Should this return a vector or a subarray? I think a vector copy, and use sub for a new view?
@generated function Base.getindex{ColumnName,FieldNames,FieldTypes,IndexType1,IndexType2}(sc::SubColumn{ColumnName,FieldNames,FieldTypes,IndexType1}, i::IndexType2)
    # Should calculate upgraded IndexType (is there a covenient way of doing this??)
    PromotedIndexType = IndexType1
    if IndexType2 <: Vector
        PromotedIndexType = IndexType2
    elseif IndexType2 <: StepRange && IndexType1 <: Union{Colon,UnitRange}
        PromotedIndexType = IndexType2
    elseif IndexType2 <: UnitRange && IndexType1 <: Colon
        PromotedIndexType = IndexType2
    end

    return :(SubColumn{$ColumnName,$FieldNames,$FieldTypes,$PromotedIndexType}(sc.parent,sc.idx[i]))
end

@generated function Base.setindex!{ColumnName,FieldNames,FieldTypes,IndexType,ValType}(sc::SubColumn{ColumnName,FieldNames,FieldTypes,IndexType}, val::ValType, i::Int)
    quote
        if sc.idx[i] < 1 || sc.idx[i] > length(sc.parent.data)
            error("Index out of bounds")
        end
        Base.unsafe_setindex!(sc,val,i)
    end
end

#ptr = Base.unsafe_convert(Ptr{FieldTypes},sc.parent.data) + $s*(sc.idx[i]-1) + $offset
#Base.pointerset(Base.unsafe_convert(Ptr{ValType},ptr), val, 1)


@generated function Base.unsafe_setindex!{ColumnName,FieldNames,FieldTypes,IndexType,ValType}(sc::SubColumn{ColumnName,FieldNames,FieldTypes,IndexType}, val::ValType, i::Int)
    # Here we can grab a pointer to the table, add the index offset, add offset depending on column, and do a pointerset.
    # Rather unsafe, possibly naughty, but it works!
    s = sizeof(FieldTypes)
    local offset
    local valexpr
    local ColumnType
    fnp = FieldNames.parameters
    for i = 1:length(fnp)
        if ColumnName == fnp[i]
            ColumnType = FieldTypes.parameters[i]
            offset = fieldoffsets(FieldTypes)[i]
            if FieldTypes.parameters[i] == ValType
                valexpr = :(val)
            elseif method_exists(Base.convert, (Type{ColumnType}, ValType))
                valexpr = :(Base.convert($(ColumnType),val))
            else
                str = "Trying to set column $ColumnName of type $ColumnType with type $ValType and convert not defined"
                return :(error($str))
            end
            break
        end
    end

    quote
        Expr(:meta,:inline)
        Base.pointerset(Base.unsafe_convert(Ptr{$ColumnType},Base.unsafe_convert(Ptr{$FieldTypes},sc.parent.data) + $s*(sc.idx[i]-1) + $offset), $valexpr, 1)
    end
end

=#
