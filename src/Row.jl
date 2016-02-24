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
    if eltypes(Index()) != DataTypes
        return :(error("Data types $DataTypes do not match field index $(eltypes(Index()))"))
    else
        return nothing
    end
end

function check_row(i,d)
    error("Malformed Row type parameters $(typeof(i)), $d")
end

# Some interrogation
@inline Base.names{Index,DataTypes}(row::Row{Index,DataTypes}) = names(Index)
@inline eltypes{Index,DataTypes}(row::Row{Index,DataTypes}) = DataTypes
@inline index{Index,DataTypes}(row::Row{Index,DataTypes}) = Index
@generated Base.length{Index,DataTypes}(row::Row{Index,DataTypes}) = :($(length(Index)))
@generated ncol{Index,DataTypes}(row::Row{Index,DataTypes}) = :($(length(Index)))
nrow{Index,DataTypes}(row::Row{Index,DataTypes}) = 1

rename{Index,DataTypes}(row::Row{Index,DataTypes}, new_names::FieldIndex) = Row(rename(Index,new_names),row.data)
rename{Index,DataTypes}(row::Row{Index,DataTypes}, old_names::Union{FieldIndex,Field}, new_names::Union{FieldIndex,Field}) = Row(rename(Index,old_names,new_names),row.data)

function Base.show{Index,DataTypes}(io::IO,row::Row{Index,DataTypes})
    print(io,"(")
    for i = 1:length(Index)
        print(io,"$(name(Index[i])):$(row.data[i])")
        if i < length(Index)
            print(io,", ")
        end
    end
    print(io,")")
end

# Can index with integers or rows
@inline Base.getindex{Index,DataTypes}(row::Row{Index,DataTypes},i) = row.data[i] #::DataTypes.parameters[i] # Is this considered "type safe"??
@inline Base.getindex{Index,DataTypes,F<:Union{Field,FieldIndex}}(row::Row{Index,DataTypes},::F) = row.data[Index[F()]] #::DataTypes.parameters[i] # Is this considered "type safe"??

# copies
Base.copy{Index,DataTypes}(row::Row{Index,DataTypes}) = Row{Index,DataTypes}(copy(row.data))
Base.deepcopy{Index,DataTypes}(row::Row{Index,DataTypes}) = Row{Index,DataTypes}(deepcopy(row.data))

# For rows we can make it type-safe
#@inline Base.getindex{Col<:Union{Column,Columns},Cols,DataTypes}(row::Row{Cols,DataTypes},col::Col) = row[Cols[col]]
#@generated function Base.getindex{Col <: Column,Cols,DataTypes}(row::Row{Cols,DataTypes},col::Col)
#    idx = Cols[Col()]
#    return :(Expr(:meta,:inline), row.data[$idx]) # Under investigation, I'm not certain inline is a great idea...
#end




macro row(exprs...)
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
            field[i] = :(Tables.Field{$(Expr(:quote,expr.args[1].args[1])),$(esc(expr.args[1].args[2]))}())
        else
            error("C Expecting expression like @cell(name::Type = value) or @cell(field = value)")
        end
        value[i] = expr.args[2]
    end

    fields = Expr(:tuple,field...)
    values = Expr(:tuple,value...)

    return :(Tables.Row(Tables.FieldIndex{$(esc(fields))}(),$(esc(values))))
end
