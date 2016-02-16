module Tables

export Field, DefaultKey, FieldIndex, Row, Table, DenseTable, KeyTable, DenseKeyTable

export rename, getname, getnames, gettype, gettypes, field, index, key, keyname, ncol, nrow

# TODO DataFrames.jl uses names and eltypes (could also use name/eltype? eltype should be safe for a single column or variable)
# TODO "cell" is the common term for the intersection of a row and column, not Datum (which is currently unused, see next)
# TODO should we have Column as a generalization of Datum/Cell? Indexing by number of a Table/Row would give a Column/Datum (a bit confusing for table... maybe like table[:,1] vs table[1,:])
# TODO fix TableKey so it always references the length of the current table, not its parent
# TODO macro for constructing tables, etc
# TODO implement copy() and possibly subtable (with no ability to push! or change rows, though can setindex!)
# TODO join for row, join for table, somehow make sense of the key mess
# TODO sub for generating a sub-table (i.e. simply a table with different StorageTypes)
# TODO other DataFrames things like unique!
# TODO finish DenseTable
# TODO implement KeyTable ?
# TODO implement DenseKeyTable ?
# TODO other types of computed joins, map, do, etc

# ======================================
#    Fields
# ======================================
abstract AbstractField

"The default key is a special field referring to the intrinsic row-number of a (keyless) table"
immutable DefaultKey <: AbstractField
end
Base.show(io::IO,::DefaultKey) = print(io,"Default:$Int")
@inline gettype(::Type{DefaultKey}) = Int
@inline gettype(::DefaultKey) = Int
@inline getname(::Type{DefaultKey}) = :Default
@inline getname(::DefaultKey) = :Default


"""
A Field{Name,T}() is a singleton defining a name (as a symbol) and a data type.
"""
immutable Field{Name,T} <: AbstractField
    function Field()
        check_field(Val{Name},T)
        new{Name,T}()
    end
end

@generated function check_field{Name,T}(::Type{Val{Name}},::Type{T})
    if Name == :Default
        return :(error("Field name 'Default' is reserved"))
    else
        return nothing
    end
end
check_field(Name,T) = error("Field name $Name must be a Symbol and type $T must be a DataType")

"Extract the type parameter of a Field"
@inline gettype{Name,T}(::Type{Field{Name,T}}) = T
@inline gettype{Name,T}(::Field{Name,T}) = T
"Extract the name parameter of a Field"
@inline getname{Name,T}(::Type{Field{Name,T}}) = Name
@inline getname{Name,T}(::Field{Name,T}) = Name
@inline Base.length{Name,T}(::Field{Name,T}) = 1 # seems to be defined for scalars in Julia

Base.show{Name,T}(io::IO,::Field{Name,T}) = print(io,"$Name:$T")

# ==========================================
#    Datum - a single piece of table data
# ==========================================

"""
A Datum is a single piece of data annotated by a Field name
"""
immutable Datum{F, DatumType}
    data::DatumType
    function Datum(x::DatumType)
        check_datum(F,DatumType)
        new(x)
    end
end
@generated Datum{F<:Field,DatumType}(::F,x::DatumType) = :(Datum{$(F()),$DatumType}(x))
@generated Base.call{Name,T}(::Field{Name,T},x::T) = :(Datum{$(Field{Name,T}()),$T}(x))

# TODO All of these converts give wierd dispatch warnings (possibly a Julia bug? Clashes with similar things from Nullable and Ref)
#Base.convert{F,T1,T2}(::Type{Ref{T1}},x::Datum{F,T2}) = convert(Ref{T1},x.data)
#Base.convert{F,T1,T2}(::Type{Nullable{T1}},x::Datum{F,T2}) = convert(Nullable{T1},x.data)
#Base.convert{F,T1,T2}(t1::Type{T1},x::Datum{F,T2}) = convert(T1,x.data)

#Base.convert{Name,T}(::Type{Ref{T}},x::Datum{F,T}) = Ref{T}(x.data)
#@generated Base.convert{F,T<:DataType}(::Type{T},x::Datum{F,T}) = :(x.data)
#@generated Base.convert{F,T}(::Type{Ref{T}},x::Datum{F,T}) = :(x.data)

@generated function Base.convert{F1,F2,T1,T2}(::Type{Datum{F2,T2}},x::Datum{F1,T1})
    if getname(F1) != getname(F2)
        return :(error("Names do not match"))
    else
        return :(Datum{F2,T2}(convert(T2,x.data)))
    end
end

@generated function check_datum{F,DatumType}(::F,::Type{DatumType})
    if !isa(F(),Field)
        return :(error("Field $F should be an instance of field"))
    elseif DatumType != gettype(F())
        return :(error("DatumType $DatumType does not match fieldtype $F"))
    else
        return nothing
    end
end

Base.show{F,DatumType}(io::IO,x::Datum{F,DatumType}) = print(io,"$(getname(F)):$(x.data)")

@inline getname{F,DatumType}(::Datum{F,DatumType}) = getname(F)
@inline gettype{F,DatumType}(::Datum{F,DatumType}) = DatumType
@inline field{F,DatumType}(::Datum{F,DatumType}) = F

@inline rename{F1,F2,DatumType}(x::Datum{F1,DatumType},::F2) = rename(x,F1,F2())
@generated function rename{F1,F1_type,F2,DatumType}(x::Datum{F1,DatumType},::F1_type,::F2)
    if F1_type() == F1
        return :(Datum{$(F2()),DatumType}(x.data))
    else
        str = "Cannot rename: can't find field $F1"
        return :(error($str))
    end
end


# ======================================
#    Field indexes
# ======================================

"""
FieldIndex define collections of Field objects, and behave similarly to tuples.
"""
immutable FieldIndex{Fields}
    function FieldIndex()
        check_fieldindex(Fields)
        new{Fields}()
    end
end



@generated FieldIndex{F<:AbstractField}(field::F) = :(FieldIndex{($(F()),)}())
function FieldIndex(fields::AbstractField...)
    error("Use a tuple of Field instances to instantiate FieldIndex")
end
@generated function FieldIndex{Fields<:Tuple}(::Fields)
    local c
    try
        c = instantiate_tuple(Fields)
    catch
        return :(error("Expecting a well-formed tuple of Fields, but got a $Fields"))
    end
    return :(FieldIndex{$c}())
end

# Checks & utilities
@generated function check_fieldindex{Fields}(fields::Fields)
    if Fields <: Tuple
        for i = 1:length(Fields.parameters)
            if !(Fields.parameters[i] <: AbstractField)
                return :(error("FieldIndex was expecting a Field tuple, but received $fields"))
            end
        end

        if isunique(ntuple(i->getname(Fields.parameters[i]),length(Fields.parameters)))
            return nothing
        else
            return :(error("Fields $fields must have unique names"))
        end
    else
        return :(error("FieldIndex was expecting a Field tuple, but received $fields"))
    end
end

@inline instantiate_tuple{T <: Tuple}(::Type{T}) = ntuple(i->T.parameters[i](),length(T.parameters))
@inline isunique{T<:Tuple}(t::T) = length(t) == length(unique(t))

# Length, sizes, offsets, etc
@generated ncol{Fields}(::FieldIndex{Fields}) = :($(length(Fields)))
@generated Base.length{Fields}(::FieldIndex{Fields}) = :($(length(Fields)))

"Extract the type parameters of a FieldIndex as a Tuple{...}"
@inline gettypes{Fields}(::Type{FieldIndex{Fields}}) = gettypes(FieldIndex{Fields}())
@generated function gettypes{Fields}(::FieldIndex{Fields})
    types = ntuple(i->gettype(Fields[i]),length(Fields))
    # Insert hack here... previous hack seems to crash julia (*) so reverting to strings
    #    * mental note: never overwrite a type paramemter list with a new svec...
    # TODO convert this to an expression...
    str = "Tuple{"
    for i = 1:length(types)
        str *= "$(types[i])"
        if i < length(types) || i == 1
            str *= ","
        end
    end
    str *= "}"

    quote
      $(Expr(:meta,:inline))
      $(parse(str))
    end
end

"Extract the name parameters of a FieldIndex as a tuple of symbols (...)"
@inline getnames{Fields}(::Type{FieldIndex{Fields}}) = getnames(FieldIndex{Fields}())
@generated function getnames{Fields}(::FieldIndex{Fields}) # The output is not strongly typed...
    names = ntuple(i->getname(Fields[i]),length(Fields))
    return quote
        $(Expr(:meta, :inline))
        return $names
    end
end

@generated function rename{Fields,F_old<:Field,F_new<:Field}(::FieldIndex{Fields},::F_old,::F_new)
    if F_old() ∉ Fields
        str = "Cannot rename: can't find field $(F1()) in $Fields"
        return :(error($str))
    end

    if gettype(F_new()) != gettype(F_old())
        str = "Cannot rename: type of new field $(F_new()) does not match old field $(F_old())"
        return :(error($str))
    end

    new_fields = ntuple(i -> Fields[i] == F_old() ? F_new() : Fields[i], length(Fields))
    return :($(FieldIndex{new_fields}()))
end

@generated rename{Fields,Fields_new}(::FieldIndex{Fields},::FieldIndex{Fields_new}) = :(rename($(FieldIndex{Fields}()), $(FieldIndex{Fields}()), $(FieldIndex{Fields_new}()))) # A bit silly... could just replace old with new, but at least it passes through the checks
@generated function rename{Fields,Fields_old,Fields_new}(::FieldIndex{Fields},::FieldIndex{Fields_old},::FieldIndex{Fields_new})
    if !(Fields_old ⊆ Fields)
        str = "Cannot rename: can't find fields $(Fields_old) in $Fields"
        return :(error($str))
    end

    if length(Fields_old) != length(Fields_new)
        str = "Cannot rename: different number of old fields $(Fields_old) to new fields $(Fields_new)"
        return :(error($str))
    end

    for i = 1:length(Fields_old)
        if gettype(Fields_new[i]) != gettype(Fields_old[i])
            str = "Cannot rename: type of new field $(Fields_new[i]) does not match old field $(Fields_old[i])"
            return :(error($str))
        end
    end

    f = i -> Fields[i] ∈ Fields_old ? Fields_new[FieldIndex(Fields_old)[Fields[i]]] : Fields[i]
    new_fields = ntuple(f, length(Fields))

    return :($(FieldIndex{new_fields}()))
end


# TODO: Here we could define sizeof, fieldoffsets, etc for use in Row
# Actually, is this a good idea?? Might confuse Julia if we overload these, but we get them for free in Row or from gettypes(::FieldIndex)

# Iterators (TODO not fast... should they even be implemented? They could be made type-safe but still wouldn't work for for loops (maybe some kind of for macro or generated function?) Possibly still useful for code generators
@generated Base.start{Fields}(::FieldIndex{Fields}) = :(Val{1})
@generated Base.next{Fields,I}(::FieldIndex{Fields},::Type{Val{I}}) = :(($(Fields[I]),Val{$(I+1)}))
@generated Base.done{Fields,I}(::FieldIndex{Fields},::Type{Val{I}}) = :($(I-1 == length(Fields)))

# Getting indices (immutable, so no setindex)
@inline Base.getindex{Fields}(::FieldIndex{Fields},i) = Fields[i]
@inline Base.getindex{Fields}(::FieldIndex{Fields},::Colon) = Fields

@generated function Base.getindex{F<:Field,Fields}(::FieldIndex{Fields},::F)
    j = 0
    for i = 1:length(Fields)
        if F() == Fields[i]
            j = i
        end
    end
    if j == 0
        str = "Field $(F()) is not in $Fields"
        return :(error($str))
    else
        return quote
            $(Expr(:meta,:inline))
            return $j
        end
    end
end

@generated function Base.getindex{Fields,Fields2}(a::FieldIndex{Fields},b::FieldIndex{Fields2})
    local x
    try
        x = ntuple(i->FieldIndex{Fields}()[FieldIndex{Fields2}()[i]], length(Fields2))
    catch
        str = "Error indexing $Fields2 in columns $Fields"
        return :(error($str))
    end
    return quote
        $(Expr(:meta,:inline))
        return $x
    end
end

Base.show{Fields}(io::IO,::FieldIndex{Fields}) = show(io,Fields)

# unions, intersections, differences, etc.
@generated Base.union{F <: AbstractField}(::F) = :(FieldIndex{($(F()),)}())
@inline Base.union{Fields}(::FieldIndex{Fields}) = FieldIndex{Fields}()
@inline Base.union{F1 <: Union{AbstractField,FieldIndex}, F2 <: Union{AbstractField,FieldIndex}}(f1::F1,f2::F2,fields...) = union(union(c1,c2),fields...) # TODO check of this results in no-ops? Otherwise will need a (disgusting)_chain of generated functions...

@generated function Base.union{F1 <: AbstractField, F2 <: AbstractField}(::F1,::F2)
    fields_out = (unique((F1(),F2()))...)
    :($(Expr(:meta,:inline)); FieldIndex($(fields_out)))
end

@generated function Base.union{F1 <: AbstractField,Fields2}(::F1,::FieldIndex{Fields2})
    fields_out = (unique((F1(),Fields2...))...)
    :($(Expr(:meta,:inline)); FieldIndex($(fields_out)))
end

@generated function Base.union{Fields1,F2 <: AbstractField}(::FieldIndex{Fields1},::F2)
    fields_out = (unique((Fields1...,F2()))...)
    :($(Expr(:meta,:inline)); FieldIndex($(fields_out)))
end

@generated function Base.union{Fields1, Fields2}(::FieldIndex{Fields1},::FieldIndex{Fields2})
    fields_out = (unique((Fields1...,Fields2...))...)
    :($(Expr(:meta,:inline)); FieldIndex($(fields_out)))
end

# intersect
@generated function Base.intersect{F1 <: AbstractField, F2 <: AbstractField}(::F1,::F2)
    fields_out = (intersect((F1(),),(F2(),))...)
    :(Expr(:meta,:inline); FieldIndex($(fields_out)))
end
@generated function Base.intersect{F1 <: AbstractField,Fields2}(::F1,::FieldIndex{Fields2})
    fields_out = (intersect((F1(),),Fields2)...)
    :(Expr(:meta,:inline); FieldIndex($(fields_out)))
end
@generated function Base.intersect{Fields1,F2 <: AbstractField}(::FieldIndex{Fields1},::F2)
    fields_out = (intersect(Fields1,(F2(),))...)
    :(Expr(:meta,:inline); FieldIndex($(fields_out)))
end
@generated function Base.intersect{Fields1, Fields2}(::FieldIndex{Fields1},::FieldIndex{Fields2})
    fields_out = (intersect(Fields1,Fields2)...)
    :(Expr(:meta,:inline); FieldIndex($(fields_out)))
end

# setdiff
@generated function Base.setdiff{F1 <: AbstractField, F2 <: AbstractField}(::F1,::F2)
    fields_out = (setdiff((F1(),),(F2(),))...)
    :(Expr(:meta,:inline); FieldIndex($(fields_out)))
end
@generated function Base.setdiff{F1 <: AbstractField,Fields2}(::F1,::FieldIndex{Fields2})
    fields_out = (setdiff((F1(),),Fields2)...)
    :(Expr(:meta,:inline); FieldIndex($(fields_out)))
end
@generated function Base.setdiff{Fields1,F2 <: AbstractField}(::FieldIndex{Fields1},::F2)
    fields_out = (setdiff(Fields1,(F2(),))...)
    :(Expr(:meta,:inline); FieldIndex($(fields_out)))
end
@generated function Base.setdiff{Fields1, Fields2}(::FieldIndex{Fields1},::FieldIndex{Fields2})
    fields_out = (setdiff(Fields1,Fields2)...)
    :(Expr(:meta,:inline); FieldIndex($(fields_out)))
end

# Now we can add or remove columns. Just use + and -
# TODO Think about what symbols are best for this that also works for tables (this covers both outer joins and simple appending of columns)
import Base.+
@generated function +{F1 <: Union{AbstractField,FieldIndex}, F2 <: Union{AbstractField,FieldIndex}}(::F1,::F2)
    if length(intersect(F1(),F2())) == 0
        return :(Expr(:meta,:inline); union($(F1()),$(F2())))
    else
        str = "FieldIndex's must be disjoint: tried to combine $(F1()) with $(F2())"
        return :(error($str))
    end
end

import Base.-
@generated function -{F1 <: Union{AbstractField,FieldIndex}, F2 <: Union{AbstractField,FieldIndex}}(::F1,::F2)
    if length(intersect(F1(),F2())) == length(F2())
        return :(Expr(:meta,:inline); setdiff($(F1()),$(F2())))
    else
        str = "Cannot remove requested fields: tried to remove $(F2()) from $(F1())"
        return :(error($str))
    end
end


# ======================================
#    Row of data
# ======================================

"""
A Row includes data stored according to its FieldIndex description
"""
immutable Row{Index,DataTypes}
    data::DataTypes

    function Row(data_in)
        check_row(Index,DataTypes)
        new(data_in)
    end
end

# Convenient methods of instantiation
@generated Row{Index<:FieldIndex,DataTypes<:Tuple}(::Index,data_in::DataTypes) = :(Row{$(Index()),$DataTypes}(data_in))
Row{Index<:FieldIndex}(::Index, data_in...) = error("Must instantiate Row with a tuple")
@generated Base.call{Index<:FieldIndex,DataTypes<:Tuple}(::Index,x::DataTypes) = :(Row{$(Index()),$DataTypes}(x))
Base.call{Index<:FieldIndex}(::Index,x...) = error("Must instantiate Row with a tuple")

@generated function check_row{Index<:FieldIndex,DataTypes<:Tuple}(::Index,::Type{DataTypes})
    if gettypes(Index()) != DataTypes
        return :(error("Data types $DataTypes do not match field index $(gettypes(Index()))"))
    else
        return nothing
    end
end

function check_row(i,d)
    error("Malformed Row type parameters $(typeof(i)), $d")
end

# Some interrogation
@inline getnames{Index,DataTypes}(row::Row{Index,DataTypes}) = getnames(Index)
@inline gettypes{Index,DataTypes}(row::Row{Index,DataTypes}) = DataTypes
@inline index{Index,DataTypes}(row::Row{Index,DataTypes}) = Index
@generated Base.length{Index,DataTypes}(row::Row{Index,DataTypes}) = :($(length(Index)))
@generated ncol{Index,DataTypes}(row::Row{Index,DataTypes}) = :($(length(Index)))
nrow{Index,DataTypes}(row::Row{Index,DataTypes}) = 1

rename{Index,DataTypes}(row::Row{Index,DataTypes}, new_names::FieldIndex) = Row(rename(Index,new_names),row.data)
rename{Index,DataTypes}(row::Row{Index,DataTypes}, old_names::Union{FieldIndex,Field}, new_names::Union{FieldIndex,Field}) = Row(rename(Index,old_names,new_names),row.data)

function Base.show{Index,DataTypes}(io::IO,row::Row{Index,DataTypes})
    print(io,"(")
    for i = 1:length(Index)
        print(io,"$(getname(Index[i])):$(row.data[i])")
        if i < length(Index)
            print(io,", ")
        end
    end
    print(io,")")
end

# Can index with integers or rows
@inline Base.getindex{Index,DataTypes}(row::Row{Index,DataTypes},i) = row.data[i] #::DataTypes.parameters[i] # Is this considered "type safe"??
@inline Base.getindex{Index,DataTypes,F<:Field}(row::Row{Index,DataTypes},::F) = row.data[Index[F()]] #::DataTypes.parameters[i] # Is this considered "type safe"??

# For rows we can make it type-safe
#@inline Base.getindex{Col<:Union{Column,Columns},Cols,DataTypes}(row::Row{Cols,DataTypes},col::Col) = row[Cols[col]]
#@generated function Base.getindex{Col <: Column,Cols,DataTypes}(row::Row{Cols,DataTypes},col::Col)
#    idx = Cols[Col()]
#    return :(Expr(:meta,:inline), row.data[$idx]) # Under investigation, I'm not certain inline is a great idea...
#end

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
@inline gettypes{Index,Key}(::AbstractTable{Index,Key}) = gettypes(Index)
@inline getnames{Index,Key}(::AbstractTable{Index,Key}) = getnames(Index)
@inline key{Index,Key}(::AbstractTable{Index,Key}) = Key
@inline Base.keytype{Index,Key}(::AbstractTable{Index,Key}) = gettype(Key)
@inline keyname{Index,Key}(::AbstractTable{Index,Key}) = getname(Key)

"""
A table stores the data as a vector of row-tuples.
"""
immutable Table{Index, StorageTypes <: Tuple} <: AbstractTable{Index,DefaultKey()}
    data::StorageTypes

    function Table(data_in, check_sizes::Type{Val{true}} = Val{true})
        check_table(Index,StorageTypes)
        ls = map(length,data_in)
        for i in 2:length(data_in)
            if ls[i] != ls[1]
                error("Column inputs must be same length.")
            end
        end
        new(data_in)
    end

    function Table(data_in, check_sizes::Type{Val{false}})
        check_table(Index,StorageTypes)
        new(data_in)
    end
end

@generated function check_table{Index <: FieldIndex,StorageTypes <: Tuple}(::Index,::Type{StorageTypes})
    try
        types = (gettypes(Index).parameters...)
        storage_eltypes = ntuple(i->eltype(StorageTypes.parameters[i]), length(StorageTypes.parameters))
        if types == storage_eltypes
            return nothing
        else
            str = "Storage types $StorageTypes do not match Index $Index"
            return :(error($str))
        end
    catch
        return :(error("Error with table parameters"))
    end
end

function check_table(a,b)
    error("Error with table parameters")
end

@generated Table{Index<:FieldIndex,StorageTypes<:Tuple}(::Index,data_in::StorageTypes,check_sizes::Union{Type{Val{true}},Type{Val{false}}} = Val{true}) = :(Table{$(Index()),$StorageTypes}(data_in,check_sizes))
# Conversion between Dense and normal Tables??
# Some more convient versions. (a) One that takes pairs of fields and storage.
#                              (b) A macro @table(x=[1,2,3],y=["a","b","c"]) -> Table(Field{:x,eltype([1,2,3)}()=>[1,2,3], Field{:y,eltype{["a","b","c"]}()=>["a","b","c"])


# Data from the index
getnames{Index,DataTypes}(table::Table{Index,DataTypes}) = getnames(Index)
gettypes{Index,DataTypes}(table::Table{Index,DataTypes}) = gettypes(Index)
@generated rename{Index,DataTypes}(table::Table{Index,DataTypes}, new_names::FieldIndex) = :(Table($(rename(Index,new_names())),table.data, Val{false}))
@generated rename{Index,DataTypes,OldFields,NewFields}(table::Table{Index,DataTypes}, old_names::OldFields, ::NewFields) = :(Table($(rename(Index,OldFields(),NewFields())),table.data, Val{false}))

# Vector-like introspection
Base.length{Index,StorageTypes}(table::Table{Index,StorageTypes}) = length(table.data[1])
@generated ncol{Index,StorageTypes}(table::Table{Index,StorageTypes}) = :($(length(Index)))
nrow{Index,StorageTypes}(table::Table{Index,StorageTypes}) = length(table.data[1])
Base.size{Index,StorageTypes}(table::Table{Index,StorageTypes}) = (length(Index),length(table.data[1]))
Base.size{Index,StorageTypes}(table::Table{Index,StorageTypes},i::Int) = i == 1 ? length(Index) : (i == 2 ? length(table.data[1]) : error("Tables are two-dimensional"))
@generated Base.eltype{Index,StorageTypes}(table::Table{Index,StorageTypes}) = :($(gettypes(Index)))
Base.isempty{Index,StorageTypes}(table::Table{Index,StorageTypes}) = isempty(table.data[1])
Base.endof{Index,StorageTypes}(table::Table{Index,StorageTypes}) = endof(table.data[1])

# Iterators
Base.start{Index,StorageTypes}(table::Table{Index,StorageTypes}) = 1
Base.next{Index,StorageTypes}(table::Table{Index,StorageTypes},i) = (table[i],i+1)
Base.done{Index,StorageTypes}(table::Table{Index,StorageTypes},i) = (i-1 == length(table))

# get/set index
Base.getindex{Index,StorageTypes}(table::Table{Index,StorageTypes},idx::Int) = Row(Index,ntuple(i->getindex(table.data[i],idx),length(Index)))
Base.getindex{Index,StorageTypes}(table::Table{Index,StorageTypes},idx) = Table(Index,ntuple(i->getindex(table.data[i],idx),length(Index)))

Base.setindex!{Index,StorageTypes}(table::Table{Index,StorageTypes},val::Row{Index},idx::Int) = (for i = 1:length(Index); setindex!(table.data[i],val.data[i],idx); end; val)
Base.setindex!{Index,StorageTypes}(table::Table{Index,StorageTypes},val::Table{Index,StorageTypes},idx) = (for i = 1:length(Index); setindex!(table.data[i],val.data[i],idx); end; val)

Base.unsafe_getindex{Index,StorageTypes}(table::Table{Index,StorageTypes},idx::Int) = Row(Index,ntuple(i->unsafe_getindex(table.data[i],idx),length(Index)))
Base.unsafe_getindex{Index,StorageTypes}(table::Table{Index,StorageTypes},idx) = Table(Index,ntuple(i->Base.unsafe_getindex(table.data[i],idx),length(Index)))
Base.unsafe_setindex!{Index,StorageTypes}(table::Table{Index,StorageTypes},val::Row{Index},idx::Int) = for i = 1:length(Index); Base.unsafe_setindex!(table.data[i],val.data[i],idx); end
Base.unsafe_setindex!{Index,StorageTypes}(table::Table{Index,StorageTypes},val::Table{Index,StorageTypes},idx) = for i = 1:length(Index); Base.unsafe_setindex!(table.data[i],val.data[i],idx); end


# Push, append, pop
function Base.push!{Index}(table::Table{Index},row::Row{Index})
    for i = 1:length(Index)
        push!(table.data[i],row[i])
    end
    table
end
@inline Base.push!{Index,StorageTypes,DataTypes<:Tuple}(table::Table{Index,StorageTypes},data_in::DataTypes) = push!(table, Row{Index,DataTypes}(data_in))
@inline Base.push!{Index,StorageTypes}(table::Table{Index,StorageTypes},data_in...) = push!(table,((data_in...))) # TODO check if slow?
function Base.append!{Index,StorageTypes}(table::Table{Index,StorageTypes},table_in::Table{Index,StorageTypes})
    for i in 1:length(Index)
        append!(table.data[i],table_in.data[i])
    end
end
function Base.append!{Index,StorageTypes}(table::Table{Index,StorageTypes},data_in::StorageTypes)
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
function Base.pop!{Index,StorageTypes}(table::Table{Index,StorageTypes})
    return Row{Index,gettypes(Index)}(ntuple(i->pop!(table.data[i]),length(Index)))
end
function Base.shift!{Index,StorageTypes}(table::Table{Index,StorageTypes})
    return Row{Index,gettypes(Index)}(ntuple(i->shift!(table.data[i]),length(Index)))
end
function Base.empty!{Index,StorageTypes}(table::Table{Index,StorageTypes})
    for i = 1:length(Index)
        empty!(table.data[i])
    end
end

# Some output
function Base.summary{Index,StorageTypes}(io::IO,table::Table{Index,StorageTypes})
    println(io,"$(ncol(table))-column, $(nrow(table))-row Table{$Index,$StorageTypes}")
end

function Base.show{Index,StorageTypes}(io::IO,table::Table{Index,StorageTypes})
    summary(io,table)
    if length(table) > 10
        for i = 1:5
            println(io,i," ",table[i])
        end
        for i = 0:ncol(table)
            print("⋮  ")
        end
        println()
        for i = endof(table)-4:endof(table)
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

function Base.showall{Index,StorageTypes}(io::IO,table::Table{Index,StorageTypes})
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
Base.getindex{Index,StorageTypes,F<:Field}(table::Table{Index,StorageTypes},::F) = table.data[Index[F()]]
Base.getindex{Index,StorageTypes,F<:DefaultKey}(table::Table{Index,StorageTypes},::F) = 1:length(table.data[1])
Base.getindex{Index,StorageTypes,NewIndex<:FieldIndex}(table::Table{Index,StorageTypes},::NewIndex) = table.data[Index[NewIndex]] # Probably

@generated function Base.getindex{Index,StorageTypes,NewIndex<:FieldIndex}(table::Table{Index,StorageTypes},::NewIndex) # Need special possibility for DefaultKey, which may or many not exist in array
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

"This is a fake 'storage container' for the field DefaultKey() in a Table"
immutable TableKey{Index,StorageTypes}
    parent::Ref{Table{Index,StorageTypes}}
end
Base.getindex{Index,StorageTypes,T}(k::TableKey{Index,StorageTypes},i::T) = getindex(1:length(k.parent.x),i)
Base.length{Index,StorageTypes}(k::TableKey{Index,StorageTypes}) = length(k.parent.x)
Base.eltype(k::TableKey) = Int
Base.eltype{Index,StorageTypes}(k::Type{TableKey{Index,StorageTypes}}) = Int
Base.first{Index,StorageTypes}(::TableKey{Index,StorageTypes},i::Int) = 1
Base.next{Index,StorageTypes}(::TableKey{Index,StorageTypes},i::Int) = (i, i+1)
Base.done{Index,StorageTypes}(k::TableKey{Index,StorageTypes},i::Int) = (i-1) == length(k.parent.x)
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

DenseTable{Index}(::Index) = DenseTable{Index,gettypes(Index)}(Vector{Row{Index,gettypes(Index)}}())
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

@generated check_key{Key,KeyType}(::Key,::Type{KeyType}) = (gettype(Key()) == KeyType) ? (return nothing) : (str = "KeyType $KeyType doesn't match Key $Key"; return :(error(str)))

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

end # module
