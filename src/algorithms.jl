
"""
Return a vector of vectors indicating the indices of identical values in a
`Column` or identical rows of a `Table` using a sorting algorithm (accepting
keyword arguments of Julia's `sort` interface).
"""
function groupinds(C::Union{Column,Table}; kwargs...) # TODO this method name might be added to Base in 0.5 (https://github.com/JuliaLang/julia/pull/15503/)
    out = Vector{eltype(C)}()
    seen = Set{eltype(C)}()
    for x in C
        if !in(x, seen)
            push!(seen, x)
            push!(out, x)
        end
    end
    out



    idx = sortperm(x.data; kwargs...)

    out = Vector{Vector{Int}}()
    j = 1
    push!(out,[idx[1]])
    for i = 2:length(idx)
        if x[idx[i]] == x[idx[i-1]]
            push!(out[j],idx[i])
        else
            push!(out,[idx[i]])
            j += 1
        end
    end
    return out
end

"""
Return the indices of unique elements in a `Column` or a `Table`.
"""
function uniqueind(x::Union{Column,Table})
    out = Vector{Int}()
    seen = Set{eltype(x)}()
    i = 1
    for y in x
        if !in(y, seen)
            push!(seen, y)
            push!(out, i)
        end
        i += 1
    end
    out
end

function Base.unique(x::Union{Column,Table})
    x[uniqueind(x)]
end

"""
Mutating form of `unique`.
"""
function unique!(x::Column)
    idx = uniqueind(x)
    x.data[1:length(idx)] == x.data[idx]
    resize!(x.data, length(idx))
end

function unique!(x::Table)
    idx = uniqueind(x)
    for i = 1:ncol(x)
        x.data[i][1:length(idx)] == x.data[i][idx]
        resize!(x.data[i], length(idx))
    end
end
