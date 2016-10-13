@pure function samename{C1<:Union{AbstractCell,AbstractColumn}, C2<:Union{AbstractCell,AbstractColumn}}(::Type{C1}, ::Type{C2})
    name(C1) == name(C2)
end

@pure function samenames{T1<:Union{AbstractRow,AbstractTable}, T2<:Union{AbstractRow,AbstractTable}}(::Type{T1}, ::Type{T2})
    names(T1) == names(T2)
end

@pure function similarnames{T1<:Union{AbstractRow,AbstractTable}, T2<:Union{AbstractRow,AbstractTable}}(::Type{T1}, ::Type{T2})
    n1 = names(T1)
    n2 = names(T2)

    if length(n1) != length(n2)
        return false
    end

    N = length(n1)

    for i = 1:N
        isfound = false
        for j = 1:N
            @inbounds if n1[i] == n2[j]
                isfound = true
                break
            end
        end

        if !isfound
            return false
        end
    end

    return true
end


@pure function names_perm{T1<:Union{AbstractRow,AbstractTable}, T2<:Union{AbstractRow,AbstractTable}}(::Type{T1}, ::Type{T2})
    names_perm(names(T1), names(T2))
end

@pure function names_perm{N}(names1::NTuple{N,Symbol}, names2::NTuple{N,Symbol})
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

    return (order...)
end



nameindex(names::Union{AbstractCell,AbstractColumn}, name) = error("Can't search for columns $name")
@pure function nameindex{T<:Union{AbstractTable,AbstractRow}}(::Type{T}, name::Symbol)
    nameindex(names(T), name)
end
@pure function nameindex(ns::Tuple{Vararg{Symbol}}, name::Symbol)
    for i = 1:length(ns)
        if ns[i] == name
            return i
        end
    end
    error("Can't find column with name :$name")
end

@pure function nameindex{T<:Union{AbstractTable,AbstractRow}}(::Type{T}, searchnames::Tuple{Vararg{Symbol}})
    map(n -> nameindex(T, n), searchnames)
end

@pure function nameindex(ns::Tuple{Vararg{Symbol}}, searchnames::Tuple{Vararg{Symbol}})
    map(n -> nameindex(ns, n), searchnames)
end
