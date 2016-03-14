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
@generated Table{Index<:FieldIndex}(::Index,check_sizes::Union{Type{Val{true}},Type{Val{false}}} = Val{true}) = :(Table{$(Index()),$(eltypes(Index)),$(makestoragetypes(eltypes(Index)))}($(instantiate_tuple(makestoragetypes(eltypes(Index)))),check_sizes) )
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

function compactstring(x, l = 10)
    str = "$x"
    if length(str) > l
        if l >= 10
            l1 = div(l,2)
            l2 = l - l1 - 1
            return str[1:l1] * "…" * str[end-l2+1]
        else
            return str[1:l]
        end
    else
        return str
    end
end

function compactstring(x::Nullable, l = 10)
    if isnull(x)
        if l == 1
            return "-"
        elseif l < 4
            return "NA"
        else
            return "NULL"
        end
    else
        return compactstring(get(x), l)
    end
end

function compactstring(x::Bool, l = 10)
    if l < 5
        x ? (return "T") : (return "F")
        #x ? (return "✓") : (return "✗")
    else
        return "$x"
    end
end

function compactstring(x::Union{Float64,Float32},l)
    local str
    if l <= 5
        str = @sprintf("%0.3g",x)
    elseif l == 6
        str = @sprintf("%0.4g",x)
    elseif l == 7
        str = @sprintf("%0.5g",x)
    elseif l == 8
        str = @sprintf("%0.6g",x)
    elseif l == 9
        str = @sprintf("%0.7g",x)
    else
        str = @sprintf("%0.8g",x)
    end
    if str[end] == ' '
        str = str[1:end-1]
    end
    if search(str,'.') == 0 # No decimal point but its a float...
        if search(str,'e') == 0 # just in case!
            str = str * ".0"
        end
    end
    return str
end

function compactstring(x::AbstractString,l)
    if length(x) > l-2
        return "\"$(x[1:l-3])…\""
    else
        return "\"$(x)\""
    end
end



#function showalligned{T <: Integer}(io::IO, str::AbstractString, type::Type{T}, width, pad::AbstractString = " ")
#    print(io, pad ^ (width - length(str)))
#    print(io, str)
#end


_displaysize(io) = haskey(io, :displaysize) ? io[:displaysize] : _displaysize(io.io)

function Base.show{Index,ElTypes,StorageTypes}(io::IO,table::Table{Index,ElTypes,StorageTypes})
    s = Base.tty_size() # [height, width] in characters TODO fix for Julia 0.5
    maxl = max(5,div(s[1],5)) # Maximum number of lines to show (head, then tail)

    # Lengths of left, right and seperators should be consistent...
    tl = "┌─"
    t = "─" # length 1
    tr = "─┐"
    tsep = "─┬─"
    hl = "├─"
    h = "─" # length 1
    hsep = "─┼─"
    hr = "─┤"
    l = "│ "
    sep = " │ "
    r = " │"
    bl = "└─"
    b = "─" # length 1
    br = "─┘"
    bsep = "─┴─"
    pad = " " # length 1
    vdots = "⋮"# length 1
    hdots = "…" # length 1

    # First we format all of our output and determine its size

    # header....
    ncols = ncol(table)
    col_names = names(table)
    header_str = [UTF8String(string(col_names[i])) for i = 1:ncols]
    widths = [length(header_str[i]) for i = 1:ncols]

    width_suggestions = fill(10,ncols)
    for c = 1:ncols
        if eltype(table.data[c]) <: Union{Bool,Nullable{Bool},Float64,Float32} && widths[c] < width_suggestions[c]
            width_suggestions[c] = widths[c]
        end
    end

    # data...
    data_str = [Vector{UTF8String}() for i = 1:ncols]
    if length(table) > 2*maxl
        for i = 1:maxl
            for c = 1:ncols
                tmp = compactstring(table.data[c][i],width_suggestions[c])
                push!(data_str[c],tmp)
                if widths[c] < length(tmp)
                    widths[c] = length(tmp)
                end
            end
        end
        for c = 1:ncol(table)
            push!(data_str[c],"⋮")
        end
        for i = endof(table)-maxl:endof(table)
            for c = 1:ncols
                tmp = compactstring(table.data[c][i],width_suggestions[c])
                push!(data_str[c],tmp)
                if widths[c] < length(tmp)
                    widths[c] = length(tmp)
                end
            end
        end
    else
        for i = 1:length(table)
            for c = 1:ncols
                tmp = compactstring(table.data[c][i],width_suggestions[c])
                push!(data_str[c],tmp)
                if widths[c] < length(tmp)
                    widths[c] = length(tmp)
                end
            end
        end
    end

    # Now we show the table using computed widths for decorations

    # Top line
    for c = 1:ncols
        if c == 1
            print(io,tl)
        else
            print(io,tsep)
        end
        print(io, t ^ widths[c])
        if c == ncols
            println(io,tr)
        end
    end

    # Field names
    for c = 1:ncols
        if c == 1
            print(io,l)
        else
            print(io,sep)
        end
        print(io, header_str[c])
        if length(header_str[c]) < widths[c]
            print(io, pad ^ (widths[c] - length(header_str[c])))
        end
        if c == ncols
            println(io,r)
        end
    end

    # Header seperator
    for c = 1:ncols
        if c == 1
            print(io,hl)
        else
            print(io,hsep)
        end
        print(io, h ^ widths[c])
        if c == ncols
            println(io,hr)
        end
    end

    # Data
    if length(table) > 2*maxl
        for i = 1:maxl
            for c = 1:ncols
                if c == 1
                    print(io,l)
                else
                    print(io,sep)
                end
                print(io, data_str[c][i])
                if length(data_str[c][i]) < widths[c]
                    print(io, pad ^ (widths[c] - length(data_str[c][i])))
                end
                if c == ncols
                    println(io,r)
                end
            end
        end

        for c = 1:ncols
            if c == 1
                print(io,l)
            else
                print(io,sep)
            end
            print(io, vdots)
            print(io, pad ^ (widths[c]-1))
            if c == ncols
                println(io,r)
            end
        end

        for i = endof(table)-maxl:endof(table)
            for c = 1:ncols
                if c == 1
                    print(io,l)
                else
                    print(io,sep)
                end
                print(io, data_str[c][i])
                if length(data_str[c][i]) < widths[c]
                    print(io, pad ^ (widths[c] - length(data_str[c][i])))
                end
                if c == ncols
                    println(io,r)
                end
            end
        end
    else
        for i = 1:length(table)
            for c = 1:ncols
                if c == 1
                    print(io,l)
                else
                    print(io,sep)
                end
                print(io, data_str[c][i])
                if length(data_str[c][i]) < widths[c]
                    print(io, pad ^ (widths[c] - length(data_str[c][i])))
                end
                if c == ncols
                    println(io,r)
                end
            end
        end
    end

    # Bottom line
    for c = 1:ncols
        if c == 1
            print(io,bl)
        else
            print(io,bsep)
        end
        print(io, b ^ widths[c])
        if c == ncols
            println(io,br)
        end
    end

    #=
    summary(io,table)

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
    end =#
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
Base.getindex{Index,ElTypes,StorageTypes,F<:Field}(table::Table{Index,ElTypes,StorageTypes},idx::Int,::F) = table.data[Index[F()]][idx]
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
Base.getindex{Index,ElTypes,StorageTypes,F<:Field}(table::Table{Index,ElTypes,StorageTypes},idx,::F) = table.data[Index[F()]][idx]
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



# Concatenate rows and tables into tables
Base.vcat{Index,ElTypes}(row::Row{Index,ElTypes}) = Table(row)
Base.vcat{Index,ElTypes,StorageTypes}(table::Table{Index,ElTypes,StorageTypes}) = table

@generated Base.vcat{Index,ElTypes}(row1::Row{Index,ElTypes},row2::Row{Index,ElTypes}) = :( Table{Index,ElTypes,$(makestoragetypes(ElTypes))}(ntuple(i->vcat(row1.data[i],row2.data[i]),$(length(Index)))) )
Base.vcat{Index,ElTypes,StorageTypes}(row1::Row{Index,ElTypes},table2::Table{Index,ElTypes,StorageTypes}) = Table{Index,ElTypes,StorageTypes}(ntuple(i->vcat(row1.data[i],table2.data[i]),length(Index)))
Base.vcat{Index,ElTypes,StorageTypes}(table1::Table{Index,ElTypes,StorageTypes},row2::Row{Index,ElTypes}) = Table{Index,ElTypes,StorageTypes}(ntuple(i->vcat(table1.data[i],row2.data[i]),length(Index)))
Base.vcat{Index,ElTypes,StorageTypes}(table1::Table{Index,ElTypes,StorageTypes},table2::Table{Index,ElTypes,StorageTypes}) = Table{Index,ElTypes,StorageTypes}(ntuple(i->vcat(table1.data[i],table2.data[i]),length(Index)))

Base.vcat{Index,ElTypes}(row1::Row{Index,ElTypes},row2::Row{Index,ElTypes},rows::Row{Index,ElTypes}...) = vcat(vcat(row1,row2),rows...)
Base.vcat{Index,ElTypes,StorageTypes}(c1::Union{Row{Index,ElTypes},Table{Index,ElTypes,StorageTypes}},c2::Union{Row{Index,ElTypes},Table{Index,ElTypes,StorageTypes}},cs::Union{Row{Index,ElTypes},Table{Index,ElTypes,StorageTypes}}...) = vcat(vcat(c1,c2),cs...)

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
Base.endof{Index,ElTypes,StorageTypes}(k::TableKey{Index,ElTypes,StorageTypes}) = endof(k.parent.x)
Base.eltype(k::TableKey) = Int
Base.eltype{Index,ElTypes,StorageTypes}(k::Type{TableKey{Index,ElTypes,StorageTypes}}) = Int
Base.first{Index,ElTypes,StorageTypes}(::TableKey{Index,ElTypes,StorageTypes},i::Int) = 1
Base.next{Index,ElTypes,StorageTypes}(::TableKey{Index,ElTypes,StorageTypes},i::Int) = (i, i+1)
Base.done{Index,ElTypes,StorageTypes}(k::TableKey{Index,ElTypes,StorageTypes},i::Int) = (i-1) == length(k.parent.x)
Base.show(io::IO,k::TableKey) = show(io::IO,1:length(k.parent.x))
Base.copy(k::TableKey) = 1:length(k)
