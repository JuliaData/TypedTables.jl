# ==========================================
#    Cell - a single piece of table data
# ==========================================

"""
A `Cell` is a single piece of data annotated by a column name
"""
immutable Cell{Name, ElType} <: AbstractCell
    data::ElType
    function Cell{T}(x::T)
        check_Cell(Val{Name},ElType)
        new(convert(ElType,x))
    end
end
@inline (::Type{Cell{Name}}){Name, ElType}(x::ElType) = Cell{Name,ElType}(x)

@generated function check_Cell{Name, ElType}(::Type{Val{Name}}, ::Type{ElType})
    if !isa(Name, Symbol)
        return :(error("Field name $F should be a symbol"))
    elseif Name == :Row
        return :( error("Field name cannot be :Row") )
    elseif !isa(ElType, DataType)
        return :(error("ElType $ElType should be a data type"))
    else
        return nothing
    end
end

@inline Base.get(c::Cell) = c.data
@inline name{Name}(::Type{Cell{Name}}) = Name
@inline name{Name,ElType}(::Type{Cell{Name,ElType}}) = Name

# @Column and @Cell are very similar
macro Cell(expr)
    if expr.head != :(=) && expr.head != :(kw) # strange Julia bug, see issue 7669
        error("A Expecting expression like @Cell(name::Type = value) or @Cell(name = value)")
    end
    local field
    value = expr.args[2]
    if isa(expr.args[1], Symbol)
        name = expr.args[1]
        return :( TypedTables.Cell{$(QuoteNode(name))}($(esc(value))) )
    elseif isa(expr.args[1],Expr)
        if expr.args[1].head != :(::) || length(expr.args[1].args) != 2 || !isa(expr.args[1].args[1], Symbol)
            error("B Expecting expression like @Cell(name::Type = value) or @Cell(name = value)")
        end
        name = expr.args[1].args[1]
        eltype = expr.args[1].args[2]
        field = :( TypedTables.Cell{$(QuoteNode(name)), $(esc(eltype))}($(esc(value))) )
    else
        error("C Expecting expression like @Cell(name::Type = value) or @Cell(name = value)")
    end
end
