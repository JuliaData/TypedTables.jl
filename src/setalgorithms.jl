
"""
Return a vector of vectors indicating the indices of identical values in a
`Column` or identical rows of a `Table` using a sorting algorithm (accepting
keyword arguments of Julia's `sort` interface).
"""
function groupinds(C::Union{Column,Table}; kwargs...) # TODO this method name might be added to Base in 0.5 (https://github.com/JuliaLang/julia/pull/15503/)
    out = Dict{eltype(C),Vector{Int}}()
    i = 1
    for i = 1:length(C)
        if !in(C.data[i], keys(out))
            out[C.data[i]] = [i]
        else
            push!(out[C.data[i]],i)
        end
    end
    collect(values(out))
end

"""
Return the indices of the first unique elements in a `Column` or a `Table`.
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

Base.union(cell::Cell) = Column(cell)
Base.union(col::Column) = unique(col)
Base.union{F, T}(col1::Union{Cell{F,T},Column{F,T}}, col2::Union{Cell{F,T},Column{F,T}}) =
    Column(F, union(col1.data, col2.data))
Base.union{F, T}(col1::Union{Cell{F,T},Column{F,T}}, col2::Union{Cell{F,T},Column{F,T}}, cols::Union{Cell,Column}...) =
    union(union(col1, col2), cols...)

Base.intersect{F, T}(col1::Union{Cell{F,T},Column{F,T}}, col2::Union{Cell{F,T},Column{F,T}}) =
    Column(F, intersect(col1.data, col2.data))

Base.setdiff{F, T}(col1::Union{Cell{F,T},Column{F,T}}, col2::Union{Cell{F,T},Column{F,T}}) =
    Column(F, setdiff(col1.data, col2.data))

Base.union(row::Row) = Table(row)
Base.union(table::Table) = unique(table)
function Base.union{Index}(table1::Union{Row{Index},Table{Index}}, table2::Union{Row{Index},Table{Index}})
    seen = Set{eltypes(Index)}()
    idx1 = Vector{Int}()
    for i = 1:length(table1)
        if !in(table1[i].data, seen)
            push!(seen, table1[i].data)
            push!(idx1, i)
        end
    end
    idx2 = Vector{Int}()
    for i = 1:length(table2)
        if !in(table2[i].data, seen)
            push!(seen, table2[i].data)
            push!(idx2, i)
        end
    end

    vcat(table1[idx1], table2[idx2])
end
function Base.union{Index}(table1::Union{Row{Index},Table{Index}}, table2::Union{Row{Index},Table{Index}}, tables::Union{Row,Table}...)
    union(union(table1, table2), tables...)
end

function Base.intersect{Index}(table1::Union{Row{Index},Table{Index}}, table2::Union{Row{Index},Table{Index}})
    seen1 = Set{eltypes(Index)}()
    for i = 1:length(table1)
        if !in(table1[i].data, seen1)
            push!(seen1, table1[i].data)
        end
    end
    seen2 = Set{eltypes(Index)}()
    idx2 = Vector{Int}()
    for i = 1:length(table2)
        if in(table2[i].data, seen1)
            if !in(table2[i].data, seen2)
                push!(seen2, table2[i].data)
                push!(idx2, i)
            end
        end
    end

    table2[idx2]
end

function Base.setdiff{Index}(table1::Union{Row{Index},Table{Index}}, table2::Union{Row{Index},Table{Index}})
    idx1 = Dict{eltypes(Index),Int}()
    for i = 1:length(table1)
        if !in(table1[i].data, keys(idx1))
            idx1[table1[i].data] = i
        end
    end
    for i = 1:length(table2)
        if in(table2[i].data, keys(idx1))
            delete!(idx1,table2[i].data)
        end
    end

    table1[collect(values(idx1))]
end
