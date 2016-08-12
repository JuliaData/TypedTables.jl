# ==========================================
#    Cell - a single piece of table data
# ==========================================

"""
A `Cell` is a single piece of data annotated by a column name
"""
immutable Cell{Name, ElType}
    data::ElType
    function Cell{T}(x::T)
        check_Cell(Val{Name},ElType)
        new(convert(ElType,x))
    end
end
@compat @inline (::Type{Cell{Name}}){Name, ElType}(x::ElType) = Cell{Name,ElType}(x)

Base.convert{Name, T1, T2}(::Type{Cell{Name, T2}}, x::Cell{Name,T1}) = Cell{Name,T2}(x.data)

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

@compat Base.:(==){Name}(cell1::Cell{Name}, cell2::Cell{Name}) = (cell1.data == cell2.data)

@inline rename{Name1, Name2, ElType}(x::Cell{Name1, ElType}, ::Type{Val{Name2}}) = Cell{Name2, ElType}(x.data)

@inline name{Name,ElType}(::Cell{Name,ElType}) = Name
@inline name{Name}(::Type{Cell{Name}}) = Name
@inline name{Name,ElType}(::Type{Cell{Name,ElType}}) = Name
@inline Base.eltype{Name,ElType}(::Cell{Name,ElType}) = ElType
@inline Base.eltype{Name,ElType}(::Type{Cell{Name,ElType}}) = ElType
@inline Base.length{Name,ElType}(::Cell{Name,ElType}) = 1
@inline Base.length{Name,ElType}(::Type{Cell{Name,ElType}}) = 1

@inline nrow(::Cell) = 1
@inline ncol(::Cell) = 1
@inline ncol{C <: Cell}(::Type{C}) = 1

Base.getindex{Name}(c::Cell{Name}, ::Type{Val{Name}}) = c.data
Base.getindex{Name1, Name2}(c::Cell{Name1}, ::Type{Val{Name2}}) = error("Tried to index cell of field name :$Name1 with field name :$Name2")

Base.start(c::Cell) = false # Similar iterators as Julia scalars
Base.next(c::Cell, i::Bool) = (c.data, true)
Base.done(c::Cell, i::Bool) = i
Base.endof(c::Cell) = 1

Base.getindex(c::Cell) = c.data
Base.getindex(c::Cell, i::Integer) = ((i == 1) ? c.data : throw(BoundsError())) # This matches the behaviour of other scalars in Julia
Base.getindex(c::Cell, ::Colon) = c


Base.copy{F,ElType}(cell::Cell{F,ElType}) = Cell{F,ElType}(copy(cell.data))

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
