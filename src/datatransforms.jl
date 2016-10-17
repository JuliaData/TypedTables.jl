using CoordinateTransformations

abstract DataTransformation <: Transformation



# Filter
immutable Filter{Names, Func} <: DataTransformation
    f::Func
end

@pure names{Names, Func}(::Type{Filter{Names}}) = Names
@pure names{Names, Func}(::Type{Filter{Names, Func}}) = Names

Filter(f) = Filter{()}(f) # ?
@pure Filter(n::Tuple{Vararg{Symbol}}, f) = Filter{n}(f)

@generated function (filter::Filter)(t::Union{AbstractTable,AbstractColumn})
    if t <: AbstractTable
        new_type = table_type(t)
    else
        new_type = column_type(t)
    end


    return quote
        out = new_type(eltypes(t))
        for i in 1:nrow(t)
            @inbounds row = t[i]
            subrow = getindex(row, Vals)
            if filter.f(get(subrow)) # Fix get for column
                push!(out, row)
            end
        end
        return out
    end
end


# Join columns
immutable Join{Names} <: DataTransformation
end

function Join(n::Symbol...)
    @_pure_meta
    @_inline_meta
    Join(n)
end

@pure Join(n::Tuple{Vararg{Symbol}}) = Join{n}()
