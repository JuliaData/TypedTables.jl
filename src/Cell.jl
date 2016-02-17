# ==========================================
#    Cell - a single piece of table data
# ==========================================

"""
A Cell is a single piece of data annotated by a Field name
"""
immutable Cell{F, CellType}
    data::CellType
    function Cell(x::CellType)
        check_Cell(F,CellType)
        new(x)
    end
end
@generated Cell{F<:Field,CellType}(::F,x::CellType) = :(Cell{$(F()),$CellType}(x))
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

@generated function check_Cell{F,CellType}(::F,::Type{CellType})
    if !isa(F(),Field)
        return :(error("Field $F should be an instance of field"))
    elseif CellType != eltype(F())
        return :(error("CellType $CellType does not match fieldtype $F"))
    else
        return nothing
    end
end

Base.show{F,CellType}(io::IO,x::Cell{F,CellType}) = print(io,"$(name(F)):$(x.data)")

@inline name{F,CellType}(::Cell{F,CellType}) = name(F)
@inline name{F,CellType}(::Type{Cell{F,CellType}}) = name(F)
@inline Base.eltype{F,CellType}(::Cell{F,CellType}) = CellType
@inline Base.eltype{F,CellType}(::Type{Cell{F,CellType}}) = CellType
@inline field{F,CellType}(::Cell{F,CellType}) = F
@inline field{F,CellType}(::Type{Cell{F,CellType}}) = F

@inline rename{F1,F2,CellType}(x::Cell{F1,CellType},::F2) = rename(x,F1,F2())
@generated function rename{F1,F1_type,F2,CellType}(x::Cell{F1,CellType},::F1_type,::F2)
    if F1_type() == F1
        return :(Cell{$(F2()),CellType}(x.data))
    else
        str = "Cannot rename: can't find field $F1"
        return :(error($str))
    end
end

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
    return :($field($value))
end
