# ==========================================
#    Cell - a single piece of table data
# ==========================================

"""
A Cell is a single piece of data annotated by a Field name
"""
immutable Cell{F, ElType}
    data::ElType
    function Cell(x::ElType)
        check_Cell(F,ElType)
        new(x)
    end
end
@generated Cell{F<:Field,ElType}(::F,x::ElType) = :(Cell{$(F()),$ElType}(x))
@generated Base.call{Name,T}(::Field{Name,T},x::T) = :(Cell{$(Field{Name,T}()),$T}(x))

# TODO All of these converts give wierd dispatch warnings (possibly a Julia bug? Clashes with similar things from Nullable and Ref)
#Base.convert{F,T1,T2}(::Type{Ref{T1}},x::Cell{F,T2}) = convert(Ref{T1},x.data)
#Base.convert{F,T1,T2}(::Type{Nullable{T1}},x::Cell{F,T2}) = convert(Nullable{T1},x.data)
#Base.convert{F,T1,T2}(t1::Type{T1},x::Cell{F,T2}) = convert(T1,x.data)

#Base.convert{Name,T}(::Type{Ref{T}},x::Cell{F,T}) = Ref{T}(x.data)
#@generated Base.convert{F,T<:DataType}(::Type{T},x::Cell{F,T}) = :(x.data)
#@generated Base.convert{F,T}(::Type{Ref{T}},x::Cell{F,T}) = :(x.data)

@generated function Base.convert{F1,F2,T1,T2}(::Type{Cell{F2,T2}},x::Cell{F1,T1})
    if name(F1) != name(F2)
        return :(error("Names do not match"))
    else
        return :(Cell{F2,T2}(convert(T2,x.data)))
    end
end

@generated function check_Cell{F,ElType}(::F,::Type{ElType})
    if !isa(F(),Field)
        return :(error("Field $F should be an instance of field"))
    elseif ElType != eltype(F())
        return :(error("ElType $ElType does not match fieldtype $F"))
    else
        return nothing
    end
end

Base.show{F,ElType}(io::IO,x::Cell{F,ElType}) = print(io,"$(name(F)):$(x.data)")

@inline name{F,ElType}(::Cell{F,ElType}) = name(F)
@inline name{F,ElType}(::Type{Cell{F,ElType}}) = name(F)
@inline Base.eltype{F,ElType}(::Cell{F,ElType}) = ElType
@inline Base.eltype{F,ElType}(::Type{Cell{F,ElType}}) = ElType
@inline field{F,ElType}(::Cell{F,ElType}) = F
@inline field{F,ElType}(::Type{Cell{F,ElType}}) = F

@inline rename{F1,F2,ElType}(x::Cell{F1,ElType},::F2) = rename(x,F1,F2())
@generated function rename{F1,F1_type,F2,ElType}(x::Cell{F1,ElType},::F1_type,::F2)
    if F1_type() == F1
        return :(Cell{$(F2()),ElType}(x.data))
    else
        str = "Cannot rename: can't find field $F1"
        return :(error($str))
    end
end

Base.copy{F,ElType}(cell::Cell{F,ElType}) = Cell{F,ElType}(copy(cell.data))
Base.deepcopy{F,ElType}(cell::Cell{F,ElType}) = Cell{F,ElType}(deepcopy(cell.data))

# Currently @column and @cell do the same thing, by calling field
macro cell(expr)
    if expr.head != :(=) && expr.head != :(kw) # strange Julia bug, see issue 7669
        error("A Expecting expression like @cell(name::Type = value) or @cell(field = value)")
    end
    local field
    if isa(expr.args[1],Symbol)
        field = expr.args[1]
    elseif isa(expr.args[1],Expr)
        if expr.args[1].head != :(::) || length(expr.args[1].args) != 2
            error("B Expecting expression like @cell(name::Type = value) or @cell(field = value)")
        end
        field = :(Tables.Field{$(Expr(:quote,expr.args[1].args[1])),$(expr.args[1].args[2])}())
    else
        error("C Expecting expression like @cell(name::Type = value) or @cell(field = value)")
    end
    value = expr.args[2]
    return :(Tables.Cell($field,$value))
end
