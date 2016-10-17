# ======================================
#    Row of data
# ======================================

"""
A `Row` stores multiple elements of data referenced by their column names.
"""
immutable Row{Names, Types <: Tuple} <: AbstractRow
    data::Types

    function Row{T <: Tuple}(data_in::T)
        check_row(Val{Names}, Types)
        new(convert(Types, data_in))
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

@generated function (::Type{Row{Names}}){Names}(data::Tuple)
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


@pure Base.names{Names, Types <: Tuple}(::Type{Row{Names,Types}}) = Names
@pure Base.names{Names}(::Type{Row{Names}}) = Names

@inline Base.get(r::Row) = r.data

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
