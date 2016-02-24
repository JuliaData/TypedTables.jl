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

        if isunique(ntuple(i->name(Fields.parameters[i]),length(Fields.parameters)))
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
@generated Base.endof{Fields}(::FieldIndex{Fields}) = :($(length(Fields)))


"Extract the type parameters of a FieldIndex as a Tuple{...}"
@inline eltypes{Fields}(::Type{FieldIndex{Fields}}) = eltypes(FieldIndex{Fields}())
@generated function eltypes{Fields}(::FieldIndex{Fields})
    types = ntuple(i->eltype(Fields[i]),length(Fields))
    quote
      $(Expr(:meta,:inline))
      Tuple{$(types...)}
    end
end

"Extract the name parameters of a FieldIndex as a tuple of symbols (...)"
@inline Base.names{Fields}(::Type{FieldIndex{Fields}}) = names(FieldIndex{Fields}())
@generated function Base.names{Fields}(::FieldIndex{Fields}) # The output is not strongly typed...
    names = ntuple(i->name(Fields[i]),length(Fields))
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

    if eltype(F_new()) != eltype(F_old())
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
        if eltype(Fields_new[i]) != eltype(Fields_old[i])
            str = "Cannot rename: type of new field $(Fields_new[i]) does not match old field $(Fields_old[i])"
            return :(error($str))
        end
    end

    f = i -> Fields[i] ∈ Fields_old ? Fields_new[FieldIndex(Fields_old)[Fields[i]]] : Fields[i]
    new_fields = ntuple(f, length(Fields))

    return :($(FieldIndex{new_fields}()))
end


# TODO: Here we could define sizeof, fieldoffsets, etc for use in Row
# Actually, is this a good idea?? Might confuse Julia if we overload these, but we get them for free in Row or from eltypes(::FieldIndex)

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

macro index(exprs...)
    N = length(exprs)
    field = Vector{Any}(N)
    for i = 1:N
        x = exprs[i]
        if x.head != :(::) || length(x.args) != 2
            error("Expecting expression of form @field(:name :: Type)")
        end
        field[i] = :(Tables.Field{$(Expr(:quote,x.args[1])),$(esc(x.args[2]))}())
    end

    fields = Expr(:tuple,field...)

    return :(Tables.FieldIndex{$fields}())
end
