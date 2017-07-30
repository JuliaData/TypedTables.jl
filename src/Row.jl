# ======================================
#    Row of data
# ======================================

"""
A `Row` stores multiple elements of data referenced by their column names.
"""
immutable Row{Names, Types <: Tuple}
    data::Types

    function (::Type{Row{Names, Types}}){Names, Types, T <: Tuple}(data_in::T)
        check_row(Val{Names}, Types)
        new{Names, Types}(convert(Types, data_in))
    end
end

@generated function check_row{Names, Types}(::Type{Val{Names}}, ::Type{Types})
    if !isa(Names, Tuple) || eltype(Names) != Symbol || length(Names) != length(unique(Names))
        str = "Row parameter 1 (Names) is expected to be a tuple of unique symbols, got $Names" # TODO: reinsert colons in symbols?
        return :(error($str))
    end
    if :Row ∈ Names
        return :( error("Field name cannot be :Row") )
    end
    N = length(Names)
    if length(Types.parameters) != N || reduce((a,b) -> a | !isa(b, DataType), false, Types.parameters)
        str = "Row parameter 2 (Types) is expected to be a Tuple{} of $N DataTypes, got $Types"
        return :(error($str))
    end

    return nothing
end

@compat @generated function (::Type{Row{Names}}){Names}(data::Tuple)
    if !isa(Names, Tuple) || eltype(Names) != Symbol || length(Names) != length(unique(Names))
        str = "Row parameter 1 (Names) is expected to be a tuple of unique symbols, got $Names" # TODO: reinsert colons in symbols?
        return :(error($str))
    end

    if length(Names) == length(data.parameters)
        return quote
            $(Expr(:meta,:inline))
            Row{Names, $data}(data)
        end
    else
        return :(error("Can't construct Row with $(length(Names)) columns with input $data"))
    end
end

@compat (::Type{Row{Names,Types_new}}){Names, Types, Types_new}(r::Row{Names,Types}) = convert(Row{Names,Types_new}, r)

@generated function Base.convert{Names, Names_new, Types, Types_new <: Tuple}(::Type{Row{Names_new,Types_new}}, r::Row{Names,Types})
    if !isa(Names_new, Tuple) || eltype(Names_new) != Symbol || length(Names_new) != length(Names) || length(Names_new) != length(unique(Names_new))
        str = "Cannot convert $(length(Names)) columns to new names $(Names_new)."
        return :(error($str))
    end
    if length(Types_new.parameters) != length(Types.parameters)
        str = "Cannot convert $(length(Types.pareters)) columns to $(length(Types_new.parameters)) new types."
        return :(error($str))
    end
    exprs = [:(convert(Types_new.parameters[$j], r.data[$j])) for j = 1:length(Names)]
    return Expr(:call, Row{Names_new,Types_new}, Expr(:tuple, exprs...))
end

rename{Names, NewNames}(row::Row{Names}, ::Type{Val{NewNames}}) = Row{NewNames}(row.data)

columnindex{N}(names::NTuple{N,Symbol}, name) = error("Can't search for columns $name")
function columnindex{N}(names::NTuple{N,Symbol}, name::Symbol)
    for i = 1:length(names)
        if names[i] == name
            return i
        end
    end
    error("Can't find column with name :$name")
end
function columnindex{N, M}(names::NTuple{N,Symbol}, searchnames::NTuple{M,Symbol})
    return ntuple(i->columnindex(names, searchnames[i]), M)
end

@inline Base.names{Names}(::Row{Names}) = Names
@inline Base.names{Names, Types <: Tuple}(::Type{Row{Names,Types}}) = Names
@inline Base.names{Names}(::Type{Row{Names}}) = Names
@inline eltypes{Names, Types <: Tuple}(::Row{Names,Types}) = Types
@inline eltypes{Names, Types <: Tuple}(::Type{Row{Names,Types}}) = Types

@inline nrow(::Row) = 1
@inline ncol{Names}(::Row{Names}) = length(Names)
@inline ncol{Names,Types}(::Type{Row{Names,Types}}) = length(Names)
@inline ncol{Names}(::Type{Row{Names}}) = length(Names)

@generated function rename{Names, OldName, NewName}(row::Row{Names}, ::Type{Val{OldName}}, ::Type{Val{NewName}})
    j = columnindex(Names, OldName)

    NewNames = [Names...]
    NewNames[j] = NewName
    NewNames = (NewNames...)

    return :(Row{$NewNames}(row.data))
end

@generated function Base.getindex{Names, GetName}(row::Row{Names}, ::Type{Val{GetName}})
    if isa(GetName, Symbol)
        j = columnindex(Names, GetName)

        return quote
            $(Expr(:meta, :inline))
            row.data[$j]
        end
    elseif isa(GetName, Tuple)
        inds = columnindex(Names, GetName)
        exprs = [:(row.data[$(inds[j])]) for j = 1:length(inds)]
        expr = Expr(:call, Row{GetName}, Expr(:tuple, exprs...))

        return quote
            $(Expr(:meta, :inline))
            $expr
        end
    else
        str = "Can't get column(s) named $Name"
        return :(error($str))
    end
end


@inline Base.length(::Row) = 1
@inline Base.endof(::Row) = 1

Base.start(r::Row) = false
Base.next(r::Row, state) = (r, true)
Base.done(r::Row, state) = state

Base.getindex(r::Row) = r
Base.getindex(r::Row, i::Integer) = i == 1 ? r : error("Cannot index Row at $i")
Base.getindex(r::Row, ::Colon) = r

function permutator{N}(names1::NTuple{N,Symbol}, names2::NTuple{N,Symbol})
    order = zeros(Int, N)
    for i = 1:N
        isfound = false
        for j = 1:N
            if names1[i] == names2[j]
                isfound = true
                order[j] = i
                break
            end
        end

        if !isfound
            str = "New column names $names2 do not match existing names $names1"
            return :(error($str))
        end
    end

    return order
end

# reordering
@generated function permutecols{Names1,Names2,Types}(r::Row{Names1,Types}, ::Type{Val{Names2}})
    if Names1 == Names2
        return :(r)
    else
        if !(isa(Names2, Tuple)) || eltype(Names2) != Symbol || length(Names2) != length(Names1) || length(Names2) != length(unique(Names2))
            str = "New column names $Names2 do not match existing names $Names1"
            return :(error($str))
        end

        order = permutator(Names1, Names2)

        exprs = [:(r.data[$(order[j])]) for j = 1:length(Names1)]
        return Expr(:call, Row{Names2}, Expr(:tuple, exprs...))
    end
end

@compat Base.:(==){Names, Types1, Types2}(row1::Row{Names, Types1}, row2::Row{Names, Types2}) = (row1.data == row2.data)
@compat @generated function Base.:(==){Names1, Types1, Names2, Types2}(row1::Row{Names1,Types1}, row2::Row{Names2,Types2})
    # This definition has to be below permutator. See #20326
    try
        order = permutator(Names1, Names2)
        expr = :( row1.data[$(order[1])] == row2.data[1] )
        for j = 2:length(Names1)
            expr = Expr(:call, :(&), expr, :( row1.data[$(order[j])] == row2.data[$j] ))
        end
        return expr
    catch
        return false
    end
end

# Horizontally concatenate cells and rows into rows
@generated Base.hcat{Name}(c::Cell{Name}) = :( Row{$((Name,))}((c.data,)) )
Base.hcat(r::Row) = r

@generated function Base.hcat(r1::Union{Cell,Row}, r2::Union{Cell,Row})
    names1 = (r1 <: Cell ? (name(r1),) : names(r1))
    names2 = (r2 <: Cell ? (name(r2),) : names(r2))

    if length(intersect(names1, names2)) != 0
        str = "Column names are not distinct. Got $names1 and $names2"
        return :(error($str))
    end

    newnames = (names1..., names2...)
    exprs = vcat([:(r1.data[$j]) for j = 1:length(names1)], [:(r2.data[$j]) for j = 1:length(names2)])

    return Expr(:call, Row{newnames}, Expr(:tuple, exprs...))
end

Base.hcat(r1::Union{Cell,Row}, r2::Union{Cell,Row}, rs::Union{Cell,Row}...) = hcat(hcat(r1, r2), rs...)

# copy
@generated function Base.copy{Names}(r::Row{Names})
    exprs = [:(copy(r.data[$j])) for j = 1:length(Names)]
    return Expr(:call, Row{Names}, Expr(:tuple, exprs...))
end

macro Row(exprs...)
    N = length(exprs)
    names = Vector{Any}(N)
    values = Vector{Any}(N)
    for i = 1:N
        expr = exprs[i]
        if expr.head != :(=) && expr.head != :(kw) # strange Julia bug, see issue 7669
            error("A Expecting expression like @Row(name1::Type1 = value1, name2::Type2 = value2) or @Row(name1 = value1, name2 = value2)")
        end
        if isa(expr.args[1],Symbol)
            names[i] = (expr.args[1])
            values[i] = esc(expr.args[2])
        elseif isa(expr.args[1],Expr)
            if expr.args[1].head != :(::) || length(expr.args[1].args) != 2
                error("A Expecting expression like @Row(name1::Type1 = value1, name2::Type2 = value2) or @Row(name1 = value1, name2 = value2)")
            end
            names[i] = (expr.args[1].args[1])
            values[i] = esc(Expr(:call, :convert, expr.args[1].args[2], expr.args[2]))
        else
            error("A Expecting expression like @Row(name1::Type1 = value1, name2::Type2 = value2) or @Row(name1 = value1, name2 = value2)")
        end
    end

    rowtype = TypedTables.Row{(names...)}
    return Expr(:call, rowtype, Expr(:tuple, values...))
end


#=
# Some interrogation
@inline Base.names{Index,DataTypes}(row::Union{Row{Index,DataTypes},Type{Row{Index,DataTypes}}}) = names(Index)
@inline eltypes{Index,DataTypes}(row::Union{Row{Index,DataTypes},Type{Row{Index,DataTypes}}}) = DataTypes
@inline index{Index,DataTypes}(row::Union{Row{Index,DataTypes},Type{Row{Index,DataTypes}}}) = Index
@generated Base.length{Index,DataTypes}(row::Union{Row{Index,DataTypes},Type{Row{Index,DataTypes}}}) = :($(length(Index)))
Base.endof(row::Row) = length(row)
@generated ncol{Index,DataTypes}(row::Union{Row{Index,DataTypes},Type{Row{Index,DataTypes}}}) = :($(length(Index)))
nrow{Index,DataTypes}(row::Union{Row{Index,DataTypes},Type{Row{Index,DataTypes}}}) = 1

samefields{Index1,Index2}(::Row{Index1},::Row{Index2}) = samefields(Index1,Index2)
samefields{Index1<:FieldIndex,Index2}(::Index1,::Row{Index2}) = samefields(Index1(),Index2)
samefields{Index1,Index2<:FieldIndex}(::Row{Index1},::Index2) = samefields(Index1,Index2())

=={Index,ElTypes}(row1::Row{Index,ElTypes},row2::Row{Index,ElTypes}) = (row1.data == row2.data)
function =={Index1,ElTypes1,Index2,ElTypes2}(row1::Row{Index1,ElTypes1},row2::Row{Index2,ElTypes2})
    if samefields(Index1,Index2)
        idx = Index2[Index1]
        for i = 1:length(Index1)
            if row1.data[i] != row2.data[idx[i]]
                return false
            end
        end
        return true
    else
        return false
    end
end

rename{Index,DataTypes}(row::Row{Index,DataTypes}, new_names::FieldIndex) = Row(rename(Index,new_names),row.data)
rename{Index,DataTypes}(row::Row{Index,DataTypes}, old_names::Union{FieldIndex,Field}, new_names::Union{FieldIndex,Field}) = Row(rename(Index,old_names,new_names),row.data)

#function Base.show{Index,DataTypes}(io::IO,row::Row{Index,DataTypes})
#    print(io,"Row(")
#    for i = 1:length(Index)
#        print(io,"$(name(Index[i]))=$(compactstring(row.data[i]))")
#        if i < length(Index)
#            print(io,", ")
#        end
#    end
#    print(io,")")
#end

# Can index with integers or fields
# A single field returns a scalar value, an integer a cell, a FieldIndex or other collection returns a smaller Row.
@inline Base.getindex{Index,DataTypes}(row::Row{Index,DataTypes},i::Field) = row.data[Index[i]] #::DataTypes.parameters[i] # Is this considered "type safe"??
@generated function Base.getindex{R<:Row,I<:FieldIndex}(row::R,idx::I)
    tmp = ntuple(i->:(row.data[$(index(R)[I()[i]])]), length(I))
    tmp2 = Expr(:tuple,tmp...)
    return :(idx($tmp2))
end

# Getting indices (immutable, so no setindex)
@generated function Base.getindex{Index,DataTypes,I}(row::Row{Index,DataTypes},::Type{Val{I}})
    if isa(I, Int)
        return :( $(Cell{Index[I],DataTypes.parameters[I]})(row.data[$I]) )
    elseif isa(I, Symbol)
        return :( row.data[$(Index[Val{I}])] )
    elseif isa(I, Tuple)
        l_I = length(I)
        if isa(I, NTuple{l_I, Int})
            expr = Expr(:tuple, ntuple(i-> :(row.data[$(I[i])]), l_I)...)
            return :( Row($(Index[Val{I}]), $expr) )
        elseif isa(I, NTuple{l_I, Symbol})
            expr = Expr(:tuple, ntuple(i -> :(row.data[$(Index[Val{I[i]}])]), l_I)...)
            return :( Row($(Index[Val{Index[Val{I}]}]), $expr) )
        else
            str = "Can't index Row with fields $Fields with a Val{$I}"
            return :(error($str))
        end
    else # e.g. UnitRange{Int} and other methods of indexing a Tuple
        str = "Can't index Row with fields $Fields with a Val{$I}"
        return :(error($str))
    end
end


#@inline Base.getindex{Index,DataTypes}(row::Row{Index,DataTypes},i) = Index[i](row.data[i])
@inline Base.getindex{Index,DataTypes}(row::Row{Index,DataTypes},::Colon) = row

# TODO setindex broadcasts to `[] =` (assume its like a zero-dimensional sub-array) or use SubRow class

# copies
Base.copy{Index,DataTypes}(row::Row{Index,DataTypes}) = Row{Index,DataTypes}(copy(row.data))
Base.deepcopy{Index,DataTypes}(row::Row{Index,DataTypes}) = Row{Index,DataTypes}(deepcopy(row.data))

# Concatenate cells and rows into rows
# Generated functions appear to be needed for speed...
Base.hcat{F,ElType}(cell::Cell{F,ElType}) = Row(F,cell.data)
Base.hcat{Index,ElTypes}(row::Row{Index,ElTypes}) = Row{Index,ElTypes}(row.data)

@generated Base.hcat{F1,ElType1,F2,ElType2}(cell1::Cell{F1,ElType1},cell2::Cell{F2,ElType2}) = :( Row{$(FieldIndex{(F1,F2)}()),$(Tuple{ElType1,ElType2})}((cell1.data,cell2.data)) )
@generated function Base.hcat{F1,ElType1,Index2,ElTypes2}(cell1::Cell{F1,ElType1},row2::Row{Index2,ElTypes2})
    Index = F1 + Index2
    ElTypes = eltypes(Index)
    :(Row{$Index,$ElTypes}((cell1.data, row2.data...)) )
end
@generated function Base.hcat{Index1,ElTypes1,F2,ElType2}(row1::Row{Index1,ElTypes1},cell2::Cell{F2,ElType2})
    Index = Index1 + F2
    ElTypes = eltypes(Index)
    :(Row{$Index,$ElTypes}((row1.data..., cell2.data)) )
end
@generated function Base.hcat{Index1,ElTypes1,Index2,ElTypes2}(row1::Row{Index1,ElTypes1},row2::Row{Index2,ElTypes2})
    Index = Index1 + Index2
    ElTypes = eltypes(Index)
    :(Row{$Index,$ElTypes}((row1.data..., row2.data...)) )
end

@inline Base.hcat(c1::Union{Cell,Row},c2::Union{Cell,Row},cs::Union{Cell,Row}...) = hcat(hcat(c1,c2),cs...) # Splatting is expensive but it works.


macro row(exprs...)
    N = length(exprs)
    field = Vector{Any}(N)
    value = Vector{Any}(N)
    for i = 1:N
        expr = exprs[i]
        if expr.head != :(=) && expr.head != :(kw) # strange Julia bug, see issue 7669
            error("A Expecting expression like @row(name1::Type1 = value1, name2::Type2 = value2) or @row(field1 = value1, field2 = value2)")
        end
        if isa(expr.args[1],Symbol)
            field[i] = expr.args[1]
        elseif isa(expr.args[1],Expr)
            if expr.args[1].head != :(::) || length(expr.args[1].args) != 2
                error("A Expecting expression like @row(name1::Type1 = value1, name2::Type2 = value2) or @row(field1 = value1, field2 = value2)")
            end
            field[i] = :(TypedTables.Field{$(Expr(:quote,expr.args[1].args[1])),$(expr.args[1].args[2])}())
        else
            error("A Expecting expression like @row(name1::Type1 = value1, name2::Type2 = value2) or @row(field1 = value1, field2 = value2)")
        end
        value[i] = expr.args[2]
    end

    fields = Expr(:tuple,field...)
    values = Expr(:tuple,value...)

    return :(TypedTables.Row(TypedTables.FieldIndex{$(esc(fields))}(),$(esc(values))))
end
=#
