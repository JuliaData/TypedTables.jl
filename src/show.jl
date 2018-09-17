function compact_string(x)
    io = IOContext(IOBuffer(), :compact => true)
    print(io, x)
    return String(take!(io.io))
end

function compact_string_row(x::Integer)
    io = IOContext(IOBuffer(), :compact => true)
    print(io, x)
    return String(take!(io.io))
end

function compact_string_row(x::CartesianIndex{N}) where N
    io = IOContext(IOBuffer(), :compact => true)
    for dim in 1:N
        print(io, x.I[dim])
        if dim < N
            print(io, ",")
        end
    end
    return String(take!(io.io))
end


function truncate_string(str, max_width)
    string_width = textwidth(str)
    if string_width <= max_width
        return str
    end

    newstring = ""
    string_width = 0
    for grapheme ∈ graphemes(str)
        grapheme_width = textwidth(grapheme)
        if string_width + grapheme_width >= max_width
            return newstring * "…"
        end
        newstring = newstring * grapheme
        string_width += grapheme_width
    end
    # Shouldn't get here, given that textwidth(s) = reduce(charwidth, 0, s)
end

# Two columns, for Series
function balance_widths(width1::Int, width2::Int, max_width::Int, min_width::Int = 20)
    @assert max_width >= 0
    biggest_width = max(width1, width2)

    while width1 + width2 > max_width
        biggest_width -= 1
        if biggest_width < min_width
            break
        end
        width1 = min(biggest_width, width1)
        width2 = min(biggest_width, width2)
    end

    return (width1, width2)
end

# Multiple columns, for Table
function balance_widths!(widths::Vector{Int}, ncols::Int, max_width::Int, buffer::Int = 2, min_width::Int = 20)
    @assert max_width >= 0
    biggest_width = maximum(widths)

    # First pass: shorten all the column widths
    while sum(widths) + buffer*length(widths) > max_width
        biggest_width -= 1
        if biggest_width < min_width
            break
        end
        for i = 1:length(widths)
            @inbounds widths[i] = min(biggest_width, widths[i])
        end
    end

    # Second pass: truncate columns, if necessary
    if sum(widths) + buffer*length(widths) > max_width
        total_width = 0
        for i = 1:length(widths)
            width = widths[i] + buffer
            if i == length(widths)
                ncols_shown = i-1
            else
                if total_width + width + buffer + 1 > max_width # we anticipate at least a "⋯" column to follow this one
                    ncols_shown = i-1
                    break
                end
            end
            total_width += width
        end
    else
        ncols_shown = length(widths)
    end

    return ncols_shown
end

function showtable(io::IO, @nospecialize t)
    row_inds = keys(t)
    col_inds = columnnames(t)
    nrows = length(row_inds)::Int
    nrowstring = join(map(string, size(t)), "×")
    ncols = length(col_inds)::Int
    display_width = displaysize(io)[2]
    max_cols = display_width ÷ 3 # assuming one-width columns with two spaces in-between

    typename = typeof(t).name.name
    print(io, "$typename with $ncols column$(ncols == 1 ? "" : "s") and $nrowstring row$(nrows == 1 ? "" : "s")")

    max_show_rows = displaysize(io)[1] - 7

    ncols_shown = min(ncols+1, max_cols)::Int # First "column" shown is the indices

    strings = Vector{Vector{String}}(undef, ncols_shown)
    for i ∈ 1:ncols_shown
        for j ∈ 1:(min(max_show_rows, nrows) + 1)
            if j == 1
                if i == 1
                    strings[i] = [""]
                else
                    strings[i] = [compact_string(col_inds[i-1])]
                end
            else
                if i == 1
                    push!(strings[i], compact_string_row(row_inds[j-1]))
                else
                    push!(strings[i], compact_string(t[row_inds[j-1]][col_inds[i-1]]))
                end
            end
        end
    end

    max_column_widths = [max(1, maximum(textwidth, str_vec)) for str_vec ∈ strings]

    if sum(max_column_widths) + 2*length(max_column_widths) > display_width
        # Shorten each column and reduce the number of columns shown
        # If they all still don't fit, the final shown column will be filled with "⋯"

        ncols_shown = balance_widths!(max_column_widths, ncols, display_width)
        strings = strings[1:ncols_shown]
        max_column_widths = max_column_widths[1:ncols_shown]
        for i = 1:length(strings)
            map!(str -> truncate_string(str, max_column_widths[i]), strings[i], strings[i])
        end
    end

    if ncols_shown < ncols+1
        push!(strings, fill("⋯", length(strings[1])))
        push!(max_column_widths, 1)
    end

    if nrows > max_show_rows
        for i ∈ 1:length(strings)
            if i == length(strings) && strings[i][1] == "⋯"
                push!(strings[i], (" " ^ div(max_column_widths[i]-1, 2)) *  "⋱")
            else
                push!(strings[i], (" " ^ div(max_column_widths[i]-1, 2)) *  "⋮")
            end
        end
    end

    # Now produce output

    # Header: " --  Column1  Column2"
    print(io, ":\n ")
    n_spaces = max_column_widths[1] + 3
    print(io, " " ^ n_spaces)
    for i ∈ 2:length(strings)
        @inbounds col_str = strings[i][1]
        print(io, col_str)
        if i != length(strings)
            n_spaces = max_column_widths[i] - textwidth(col_str) + 2
            print(io, " " ^ n_spaces)
        end
    end

    # Seperator: " ┌────────"
    print(io, "\n ")
    print(io, " " ^ max_column_widths[1])
    print(io, " ┌─")
    print(io, "─" ^ (sum(max_column_widths) - max_column_widths[1] + 2*(length(max_column_widths) - 2)))

    # Body " rowind │ val1  val2"
    for j = 2:length(strings[1])
        print(io, "\n ")
        @inbounds row_str = strings[1][j]
        print(io, row_str)
        n_spaces = max_column_widths[1] - textwidth(row_str)
        if n_spaces > 0
            print(io, " " ^ n_spaces)
        end
        print(io, " │ ")

        for i = 2:length(strings)
            @inbounds val_str = strings[i][j]
            print(io, val_str)

            if i != length(strings)
                n_spaces = max_column_widths[i] - textwidth(val_str) + 2
                print(io, " " ^ n_spaces)
            end
        end
    end
end
