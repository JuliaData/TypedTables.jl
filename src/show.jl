
#  ┌─┬┐
#  ├─┼┤
#  │ ││
#  └─┴┘

function compactstring(x, l = 16)
    str = "$x"
    if length(str) > l
        if l >= 10
            l1 = div(l,2)
            l2 = l - l1 - 1
            return str[1:l1] * "…" * str[end-l2+1:end]
        else
            return str[1:l] * "…"
        end
    else
        return str
    end
end

#compactstring(x::Integer, l) = "$x"

function compactstring(x::Nullable, l = 16)
    if isnull(x)
        #if l == 1
            return "-"
        #else
        #    return "NA"
        #end
    else
        return compactstring(get(x), l)
    end
end

function compactstring(x::Bool, l = 16)
    if l < 5
        x ? (return "T") : (return "F")
        #x ? (return "✓") : (return "✗")
    else
        return "$x"
    end
end

# TODO think hard about this one. Some data is numerical, while some is a label
# Is there a simple way of the user controlling the difference?
function compactstring(x::Integer,l=8)
    if x < 10_000
        return string(x)
    elseif x < 10_000_000
        tmp = div(x + 500, 1000)
        return "$(tmp) k"
    elseif x < 10_000_000_000
        tmp = div(x + 500_000, 1_000_000)
        return "$(tmp) M"
    elseif x < 10_000_000_000_000
        tmp = div(x + 500_000_000, 1_000_000_000)
        return "$(tmp) B"
    else
        tmp = div(x + 500_000_000_000, 1_000_000_000_000)
        return "$(tmp) T"
    end
end

function compactstring(x::Float64,l=16)
    if isnan(x)
        return "NaN"
    elseif isinf(x)
        if x > 0
            return "Inf"
        else
            return "-Inf"
        end
    elseif x == 0.0e0
        return "0.0000"
    else
        if x < 0
            isneg = true
            x = -x
        else
            isneg = false
        end
        if x <= 1e-3 # If it is too small
            exp = 0
            factor = 1e3
            while true
                exp -= 3
                x *= factor
                if x > 1.0
                    break
                end
            end

            tmp = Int32(round(x*10_000))
            (whole,frac) = divrem(tmp, 10_000)
            frac_str = string(frac)

            if frac < 10
                frac_str = "000" * frac_str
            elseif frac < 100
                frac_str = "00" * frac_str
            elseif frac < 1000
                frac_str = "0" * frac_str
            end

            #return "$(whole).$(frac_str)e$(exp)"
            return "$("-"^isneg)$(whole).$(frac_str) × 10$(superscript(exp))"

        elseif x >= 1e4 # Or if it is too large
            exp = 0
            factor = 1e-3
            while true
                exp += 3
                x *= factor
                if x < 1e3
                    break
                end
            end

            tmp = Int32(round(x*10_000))
            (whole,frac) = divrem(tmp, 10_000)
            frac_str = string(frac)
            if frac < 10
                frac_str = "000" * frac_str
            elseif frac < 100
                frac_str = "00" * frac_str
            elseif frac < 1000
                frac_str = "0" * frac_str
            end

            #return "$(whole).$(frac_str)e$(exp)"
            return "$("-"^isneg)$(whole).$(frac_str) × 10$(superscript(exp))"

        else # Otherwise it is "reasonably" sized
            tmp = Int32(round(x*10_000))
            (whole,frac) = divrem(tmp, 10_000)
            frac_str = string(frac)
            if frac < 10
                frac_str = "000" * frac_str
            elseif frac < 100
                frac_str = "00" * frac_str
            elseif frac < 1000
                frac_str = "0" * frac_str
            end

            return "$("-"^isneg)$(whole).$(frac_str)"
        end
    end
end

function compactstring(x::Float32,l=16)
    if isnan(x)
        return "NaN"
    elseif isinf(x)
        if x > 0
            return "Inf"
        else
            return "-Inf"
        end
    elseif x == 0.0f0
        return "0.0000"
    else
        if x < 0
            isneg = true
            x = -x
        else
            isneg = false
        end
        if x <= 1f-3 # If it is too small
            exp = 0
            factor = 1f3
            while true
                exp -= 3
                x *= factor
                if x > 1.0
                    break
                end
            end

            tmp = Int32(round(x*10_000))
            (whole,frac) = divrem(tmp, 10_000)
            frac_str = string(frac)

            if frac < 10
                frac_str = "000" * frac_str
            elseif frac < 100
                frac_str = "00" * frac_str
            elseif frac < 1000
                frac_str = "0" * frac_str
            end

            #return "$(whole).$(frac_str)e$(exp)"
            return "$("-"^isneg)$(whole).$(frac_str) × 10$(superscript(exp))"

        elseif x >= 1f4 # Or if it is too large
            exp = 0
            factor = 1f-3
            while true
                exp += 3
                x *= factor
                if x < 1f3
                    break
                end
            end

            tmp = Int32(round(x*10_000))
            (whole,frac) = divrem(tmp, 10_000)
            frac_str = string(frac)
            if frac < 10
                frac_str = "000" * frac_str
            elseif frac < 100
                frac_str = "00" * frac_str
            elseif frac < 1000
                frac_str = "0" * frac_str
            end

            #return "$(whole).$(frac_str)e$(exp)"
            return "$("-"^isneg)$(whole).$(frac_str) × 10$(superscript(exp))"

        else # Otherwise it is "reasonably" sized
            tmp = Int32(round(x*10_000))
            (whole,frac) = divrem(tmp, 10_000)
            frac_str = string(frac)
            if frac < 10
                frac_str = "000" * frac_str
            elseif frac < 100
                frac_str = "00" * frac_str
            elseif frac < 1000
                frac_str = "0" * frac_str
            end

            return "$("-"^isneg)$(whole).$(frac_str)"
        end
    end
end

function superscript(x::Integer)
    normalstring = string(x)
    superscriptstring = string()
    for char in normalstring
        superscriptstring = superscriptstring * string(superscript(char))
    end
    return superscriptstring
end

function superscript(char::Char)
    if char == '-'
        return '⁻'
    elseif char == '+'
        return '⁺'
    elseif char == '0'
        return '⁰'
    elseif char == '1'
        return '¹'
    elseif char == '2'
        return '²'
    elseif char == '3'
        return '³'
    elseif char == '4'
        return '⁴'
    elseif char == '5'
        return '⁵'
    elseif char == '6'
        return '⁶'
    elseif char == '7'
        return '⁷'
    elseif char == '8'
        return '⁸'
    elseif char == '9'
        return '⁹'
    end
end

#=
function compactstring(x::Union{Float64,Float32},l=16)
    local str
    if l <= 5
        str = @sprintf("%0.3g",x)
    elseif l == 6
        str = @sprintf("%0.4g",x)
    elseif l == 7
        str = @sprintf("%0.5g",x)
    elseif l == 8
        str = @sprintf("%0.6g",x)
    elseif l == 9
        str = @sprintf("%0.7g",x)
    elseif l == 10
        str = @sprintf("%0.8g",x)
    elseif l == 1
        str = @sprintf("%0.9g",x)
    elseif l == 12
        str = @sprintf("%0.10g",x)
    elseif l == 13
        str = @sprintf("%0.11g",x)
    elseif l == 14
        str = @sprintf("%0.12g",x)
    elseif l == 15
        str = @sprintf("%0.13g",x)
    elseif l == 16
        str = @sprintf("%0.14g",x)
    else
        str = @sprintf("%0.15g",x)
    end
    if str[end] == ' '
        str = str[1:end-1]
    end
    if search(str,'.') == 0 # No decimal point but its a float...
        if search(str,'e') == 0 && search(str,"Inf") == 0:-1 && search(str,"NaN") == 0:-1 # just in case!
            str = str * "."
        end
    end
    return str
end
=#

function compactstring(x::AbstractString,l=16)
    if length(x) > l-2
        return "\"$(x[1:l-3])…\""
    else
        return "\"$(x)\""
    end
end

align_strings(T,x) = x

function align_strings{T <: Integer, S <: AbstractString}(::Union{Type{T},Type{Nullable{T}}}, x::Vector{S})
    isempty(x) && return x
    ls = map(length,x)
    l = maximum(ls)
    for i = 1:length(x)
        x[i] = (" " ^ (l-ls[i])) * x[i]
    end
end

function align_strings{T <: AbstractFloat, S <: AbstractString}(::Union{Type{T},Type{Nullable{T}}}, x::Vector{S})
    isempty(x) && return x

    decimalpoint = [search(x[i],'.') for i = 1:length(x)]
    #if minimum(decimalpoint) == 0
    #    return x # Missing the decimal point somewhere... give up in confusion
    #end
    m = maximum(decimalpoint)

    for i = 1:length(x)
        x[i] = (" " ^ (m-decimalpoint[i])) * x[i]
    end
end

_displaysize(io) = haskey(io, :displaysize) ? io[:displaysize] : _displaysize(io.io)

function printtable(io::IO, header_str::Vector{String}, data_str::Vector{Vector{String}}, row_header_str::String = "", row_str::Vector{String} = (length(data_str) > 0 ? ["" for _ = 1:length(data_str[1])] : Vector{String}());
                    dotsbreak::Int = -1, # Insert some dots after this row (set to 0 for at top)
                    max_width::Int = 255,
                    tl::String = "┌─",
                    t::String = "─", # length 1
                    tr::String = "─┐",
                    tsep::String = "─┬─",
                    hl::String = "├─",
                    h::String = "─", # length 1
                    hsep::String = "─┼─",
                    hr::String = "─┤",
                    l::String = "│ ",
                    sep::String = " │ ",
                    r::String = " │",
                    bl::String = "└─",
                    b::String = "─", # length 1
                    br::String = "─┘",
                    bsep::String = "─┴─",
                    pad::String = " ", # length 1
                    vdots::String = "⋮",# length 1
                    hdots::String = "…") # length 1)

    ncols = length(data_str)
    nrows = length(data_str) > 0 ? length(data_str[1]) : 0
    header_str_bak = copy(header_str)

    row_width = max(length(row_header_str), maximum(isempty(row_str) ? 0 : map(length, row_str)))
    widths = [max(length(header_str[i]), maximum(isempty(data_str[i]) ? 0 : map(length, data_str[i]))) for i = 1:ncols]

    n_skipped_cols = 0
    too_wide = row_width + sum(widths) + 2 + 3*length(widths) > max_width
    was_too_wide = too_wide
    while too_wide
        if length(widths) == 1
            break # Show at least one column of data, even if it is ugly
        end
        n_skipped_cols += 1
        pop!(widths)
        pop!(header_str)
        pop!(data_str)
        too_wide = row_width + sum(widths) + 6 + 3*length(widths) > max_width
        ncols = ncols - 1
    end
    if was_too_wide
        push!(widths, 1)
        push!(header_str,hdots)
        push!(data_str,fill(hdots, length(data_str[1])))
        ncols = ncols + 1
    end

    # Top line
    print(io,pad^(row_width+1))
    for c = 1:ncols
        if c == 1
            print(io,tl)
        else
            print(io,tsep)
        end
        print(io, t ^ widths[c])
        if c == ncols
            println(io,tr)
        end
    end

    # Field names
    print(io,row_header_str * (pad ^ (row_width - length(row_header_str) + 1)))
    for c = 1:ncols
        if c == 1
            print(io,l)
        else
            print(io,sep)
        end
        print(io, header_str[c])
        if length(header_str[c]) < widths[c]
            print(io, pad ^ (widths[c] - length(header_str[c])))
        end
        if c == ncols
            println(io,r)
        end
    end

    # Header seperator
    print(io,pad^(row_width+1))
    for c = 1:ncols
        if c == 1
            print(io,hl)
        else
            print(io,hsep)
        end
        print(io, h ^ widths[c])
        if c == ncols
            println(io,hr)
        end
    end

    # Special case for vdots at start of table (e.g. might be great for displaying the tail of a table)
    if dotsbreak == 0
        print(io,pad^(row_width+1))
        for c = 1:ncols
            if c == 1
                print(io,l)
            else
                print(io,sep)
            end
            print(io, pad ^ div(widths[c]-1,2))
            print(io, vdots)
            print(io, pad ^ (widths[c]-1-div(widths[c]-1,2)))
            if c == ncols
                println(io,r)
            end
        end
    end

    # Data
    for i = 1:nrows
        print(io, pad ^ (row_width - length(row_str[i])) * row_str[i] * pad)
        for c = 1:ncols
            if c == 1
                print(io,l)
            else
                print(io,sep)
            end
            print(io, data_str[c][i])
            if length(data_str[c][i]) < widths[c]
                print(io, pad ^ (widths[c] - length(data_str[c][i])))
            end
            if c == ncols
                println(io,r)
            end
        end

        if i == dotsbreak
            print(io,pad^(row_width+1))
            for c = 1:ncols
                if c == 1
                    print(io,l)
                else
                    print(io,sep)
                end
                print(io, pad ^ div(widths[c]-1,2))
                print(io, vdots)
                print(io, pad ^ (widths[c]-1-div(widths[c]-1,2)))
                if c == ncols
                    println(io,r)
                end
            end
        end
    end

    # Bottom line
    print(io,pad^(row_width+1))
    for c = 1:ncols
        if c == 1
            print(io,bl)
        else
            print(io,bsep)
        end
        print(io, b ^ widths[c])
        if c == ncols
            print(io,br)
        end
    end
    if n_skipped_cols > 0
        print(io, "\n" * pad^(row_width) * "+ $n_skipped_cols unshown columns: ")
        for i = length(header_str_bak)+1-n_skipped_cols:length(header_str_bak)
            print(io,"$(header_str_bak[i])")
            if i < length(header_str_bak)
                print(io, ", ")
            end
        end
    end
end

function make_strings(data; maxl::Int = 5, width_suggestion::Int = 20)
    data_str = Vector{String}()
    nrows = length(data)

    if nrows > 2*maxl
        for i = 1:maxl
            push!(data_str, compactstring(data[i],width_suggestion))
        end
        for i = (nrows-maxl+1):nrows
            push!(data_str, compactstring(data[i],width_suggestion))
        end
    else
        for i = 1:nrows
            push!(data_str, compactstring(data[i],width_suggestion))
        end
    end

    align_strings(eltype(data), data_str)

    return data_str
end


function Base.show(io::IO, table::AbstractTable)
    if ncol(table) == 0
        print(io,"Empty ", typeof(table).name.name)
        return
    else
        ncols = ncol(table)
        nrows = length(table)

        println(io, "$nrows-row × $ncols-column ", typeof(table).name.name, ":")
    end

    s = displaysize(io) # [height, width] in characters
    maxl = max(5,div(s[1],5)) # Maximum number of lines to show (head, then tail)

    # First we format all of our output and determine its size
    # Rows (on side)
    row_header_str = String("Row")
    if nrows > 2*maxl
        row_str = String[string(i) for i = vcat(1:maxl, nrows-maxl+1:nrows)]
        dotsbreak = maxl
    else
        row_str = String[string(i) for i = 1:nrows]
        dotsbreak = -1
    end

    # header....
    col_names = names(table)
    header_str = [String(string(col_names[i])) for i = 1:ncols]

    data_str = [Vector{String}() for i = 1:ncols]
    for c = 1:ncols
        width_suggestion = 20
        if eltype(table.data[c]) <: Union{Bool,Nullable{Bool},Float64,Float32} && length(header_str[c]) < width_suggestion
            width_suggestion = length(header_str[c])
        end

        data_str[c] = make_strings(table.data[c]; maxl = maxl, width_suggestion=width_suggestion)
    end

    # Now we show the table using computed widths for decorations
    printtable(io, header_str, data_str, row_header_str, row_str; max_width = s[2],
                                                                  dotsbreak = dotsbreak,
                                                                  tl = "╔═",
                                                                  t = "═",
                                                                  tr = "═╗",
                                                                  tsep = "═╤═",
                                                                  l = "║ ",
                                                                  r = " ║",
                                                                  hl = "╟─",
                                                                  hr = "─╢",
                                                                  bl = "╚═",
                                                                  b = "═",
                                                                  br = "═╝",
                                                                  bsep = "═╧═")
end


function Base.showall(io::IO,table::AbstractTable)
    if ncol(table) == 0
        print(io,"Empty ", typeof(table).name.name)
        return
    else
        ncols = ncol(table)
        nrows = length(table)

        println(io, "$nrows-row × $ncols-column ", typeof(table).name.name, ":")
    end

    s = displaysize(io) # [height, width] in characters
    maxl = max(5,div(s[1],5)) # Maximum number of lines to show (head, then tail)

    # First we format all of our output and determine its size
    # Rows (on side)
    row_header_str = String("Row")
    row_str = String[string(i) for i = 1:nrows]

    # header....
    col_names = names(table)
    header_str = [String(string(col_names[i])) for i = 1:ncols]

    data_str = [Vector{String}() for i = 1:ncols]
    for c = 1:ncols
        width_suggestion = 20
        if eltype(table.data[c]) <: Union{Bool,Nullable{Bool},Float64,Float32} && length(header_str[c]) < width_suggestion
            width_suggestion = length(header_str[c])
        end

        data_str[c] = make_strings(table.data[c]; maxl = nrows, width_suggestion=width_suggestion)
    end

    # Now we show the table using computed widths for decorations
    printtable(io, header_str, data_str, row_header_str, row_str; max_width = s[2],
                                                                  tl = "╔═",
                                                                  t = "═",
                                                                  tr = "═╗",
                                                                  tsep = "═╤═",
                                                                  l = "║ ",
                                                                  r = " ║",
                                                                  hl = "╟─",
                                                                  hr = "─╢",
                                                                  bl = "╚═",
                                                                  b = "═",
                                                                  br = "═╝",
                                                                  bsep = "═╧═")
end

function Base.show(io::IO, col::AbstractColumn)
    s = displaysize(io) # [height, width] in characters
    maxl = max(5,div(s[1],5)) # Maximum number of lines to show (head, then tail)
    nrows = length(col)

    println(io, "$nrows-row ", typeof(col).name.name, ":")

    # First we format all of our output and determine its size
    # Rows (on side)
    row_header_str = String("Row")
    if nrows > 2*maxl
        row_str = String[string(i) for i = vcat(1:maxl, nrows-maxl+1:nrows)]
        dotsbreak = maxl
    else
        row_str = String[string(i) for i = 1:nrows]
        dotsbreak = -1
    end

    # header....
    header_str = [String(string(name(col)))]

    data_str = Vector{String}[make_strings(col.data; maxl = maxl, width_suggestion=60),]

    # Now we show the table using computed widths for decorations
    printtable(io, header_str, data_str, row_header_str, row_str; max_width = s[2],
                                                                  dotsbreak = dotsbreak,
                                                                  tl = "╒═",
                                                                  t = "═",
                                                                  tr = "═╕",
                                                                  tsep = "═╤═",
                                                                  bl = "╘═",
                                                                  b = "═",
                                                                  br = "═╛",
                                                                  bsep = "═╧═")
end

function Base.showall(io::IO, col::AbstractColumn)
    s = displaysize(io) # [height, width] in characters
    nrows = length(col)

    println(io, "$nrows-row ", typeof(col).name.name, ":")

    # First we format all of our output and determine its size
    # Rows (on side)
    row_header_str = String("Row")
    row_str = String[string(i) for i = 1:nrows]

    # header....
    header_str = [String(string(name(col)))]

    data_str = Vector{String}[make_strings(col.data; maxl = nrows, width_suggestion=60),]


    # Now we show the table using computed widths for decorations
    printtable(io, header_str, data_str, row_header_str, row_str; max_width = s[2],
                                                                  tl = "╒═",
                                                                  t = "═",
                                                                  tr = "═╕",
                                                                  tsep = "═╤═",
                                                                  bl = "╘═",
                                                                  b = "═",
                                                                  br = "═╛",
                                                                  bsep = "═╧═")
end

function Base.show(io::IO,row::AbstractRow)
    if ncol(row) == 0
        print(io,"Empty ", typeof(row).name.name)
        return
    end

    s = displaysize(io) # [height, width] in characters
    ncols = ncol(row)

    println(io, "$ncols-column ", typeof(row).name.name, ":")

    # First we format all of our output and determine its size

    # header....
    col_names = names(row)
    header_str = [String(string(col_names[i])) for i = 1:ncols]

    data_str = [Vector{String}() for i = 1:ncols]
    for c = 1:ncols
        width_suggestion = 20
        if eltype(row.data[c]) <: Union{Bool,Nullable{Bool},Float64,Float32} && length(header_str[c]) < width_suggestion
            width_suggestion = length(header_str[c])
        end

        data_str[c] = make_strings([row.data[c]]; width_suggestion=width_suggestion)
    end

    # Now we show the table using computed widths for decorations
    printtable(io, header_str, data_str; max_width = s[2],
                                         tl = "╓─",
                                         tr = "─╖",
                                         l = "║ ",
                                         r = " ║",
                                         hl = "╟─",
                                         hr = "─╢",
                                         bl = "╙─",
                                         br = "─╜")
end

showall(io::IO, row::AbstractRow) = show(io, row) # TODO fix this (row can be too wide)

function Base.show(io::IO, cell::AbstractCell)
    println(io, typeof(cell).name.name, ":")

    s = displaysize(io) # [height, width] in characters

    # First we format all of our output and determine its size

    # header....
    header_str = [String(string(name(cell)))]

    data_str = Vector{String}[make_strings([cell.data]; width_suggestion=60),]

    # Now we show the table using computed widths for decorations
    printtable(io, header_str, data_str; max_width = s[2])
end

showall(io::IO, cell::AbstractCell) = show(io, cell)
