
#"""
#Return a vector of vectors indicating the indices of identical values in a
#`Column` or identical rows of a `Table` using a sorting algorithm (accepting
#keyword arguments of Julia's `sort` interface).
#"""
"""
Return a vector of vectors indicating the indices of identical values in a
`Column` or identical rows of a `Table` using a hashing algorithm.
"""
function groupinds(C::Union{AbstractColumn,AbstractTable}; kwargs...) # See also https://github.com/JuliaLang/julia/pull/15503/, https://github.com/AndyGreenwell/GroupSlices.jl
    out = Dict{eltype(C),Vector{Int}}()
    i = 1
    for i = 1:length(C)
        if !in(get(C)[i], keys(out))
            out[get(C)[i]] = [i]
        else
            push!(out[get(C)[i]],i)
        end
    end
    collect(values(out))
end

"""
Return the indices of the first unique elements in a `Column` or a `Table`.
"""
function uniqueind(x::AbstractColumn)
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

function uniqueind(x::AbstractTable)
    out = Vector{Int}()
    seen = Set{eltype(x)}()
    i = 1
    for y in x
        if !in(get(y), seen)
            push!(seen, get(y))
            push!(out, i)
        end
        i += 1
    end
    out
end

function Base.unique(x::Union{AbstractColumn,AbstractTable})
    x[uniqueind(x)]
end

"""
Mutating form of `unique`.
"""
function unique!(x::AbstractColumn)
    idx = uniqueind(x)
    get(x)[1:length(idx)] == get(x)[idx]
    resize!(get(x), length(idx))
end

function unique!(x::AbstractTable)
    idx = uniqueind(x)
    for i = 1:ncol(x)
        get(x)[i][1:length(idx)] == get(x)[i][idx]
        resize!(get(x)[i], length(idx))
    end
end

Base.union(cell::AbstractCell) = column_type(typeof(cell))(union(get(cell)))
Base.union(col::AbstractColumn) = unique(col)
Base.union(col1::Union{AbstractCell,AbstractColumn}, col2::Union{AbstractCell,AbstractColumn}) =
    column_type(typeof(col1))(union(get(col1), get(col2)))
@inline Base.union(col1::Union{AbstractCell,AbstractColumn}, col2::Union{AbstractCell,AbstractColumn}, cols::Union{AbstractCell,AbstractColumn}...) =
    union(union(col1, col2), cols...)

Base.intersect(col1::Union{AbstractCell,AbstractColumn}, col2::Union{AbstractCell,AbstractColumn}) =
    column_type(typeof(col1))(intersect(get(col1), get(col2)))

Base.setdiff(col1::Union{AbstractCell,AbstractColumn}, col2::Union{AbstractCell,AbstractColumn}) =
    column_type(typeof(col1))(setdiff(get(col1), get(col2)))

Base.union(row::AbstractRow) = vcat(row)
Base.union(table::AbstractTable) = unique(table)
function Base.union(table1::Union{AbstractRow,AbstractTable}, table2::Union{AbstractRow,AbstractTable})
    seen = Set{eltypes(typeof(table1))}()
    idx1 = Vector{Int}()
    for i = 1:length(table1)
        if !in(get(table1[i]), seen)
            push!(seen, get(table1[i]))
            push!(idx1, i)
        end
    end
    idx2 = Vector{Int}()
    for i = 1:length(table2)
        if !in(get(table2[i]), seen)
            push!(seen, get(table2[i]))
            push!(idx2, i)
        end
    end

    vcat(table1[idx1], table2[idx2])
end
@inline function Base.union(table1::Union{AbstractRow,AbstractTable}, table2::Union{AbstractRow,AbstractTable}, tables::Union{AbstractRow,AbstractTable}...)
    union(union(table1, table2), tables...) # TODO a bit inefficient to build the hash multiple times...
end

function Base.union!(table1::AbstractTable, table2::Union{AbstractRow,AbstractTable})
    seen = Set{eltypes(typeof(table1))}()
    repeats = Vector{Int}()
    for i = 1:length(table1)
        if !in(get(table1[i]), seen)
            push!(seen, get(table1[i]))
        else
            push!(repeats, i)
        end
    end
    deleteat!(table1, repeats)
    for i = 1:length(table2)
        if !in(get(table2[i]), seen)
            push!(seen, get(table2[i]))
            push!(table1, table2[i])
        end
    end
end
@inline function Base.union!(table1::AbstractTable, table2::Union{AbstractRow,AbstractTable}, tables::Union{AbstractRow,AbstractTable}...)
    union!(union!(table1, table2), tables...) # TODO a bit inefficient to build the hash multiple times...
end

function Base.intersect(table1::Union{AbstractRow,AbstractTable}, table2::Union{AbstractRow,AbstractTable})
    seen1 = Set{eltypes(typeof(table1))}()
    for i = 1:length(table1)
        if !in(get(table1[i]), seen1)
            push!(seen1, get(table1[i]))
        end
    end
    seen2 = Set{eltypes(typeof(table2))}()
    idx2 = Vector{Int}()
    for i = 1:length(table2)
        if in(get(table2[i]), seen1)
            if !in(get(table2[i]), seen2)
                push!(seen2, get(table2[i]))
                push!(idx2, i)
            end
        end
    end

    table2[idx2] # This is a strange return if table2 <: AbstractRow
end

function Base.setdiff(table1::Union{AbstractRow,AbstractTable}, table2::Union{AbstractRow,AbstractTable})
    idx1 = Dict{eltypes(typeof(table1)),Int}()
    for i = 1:length(table1)
        if !in(get(table1[i]), keys(idx1))
            idx1[get(table1[i])] = i
        end
    end
    for i = 1:length(table2)
        if in(get(table2[i]), keys(idx1))
            delete!(idx1,get(table2[i]))
        end
    end

    table1[collect(values(idx1))]
end
