
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
    ls = map(length,x)
    l = maximum(ls)
    for i = 1:length(x)
        x[i] = (" " ^ (l-ls[i])) * x[i]
    end
end

function align_strings{T <: AbstractFloat, S <: AbstractString}(::Union{Type{T},Type{Nullable{T}}}, x::Vector{S})
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

function Base.show{Index,ElTypes,StorageTypes}(io::IO,table::Table{Index,ElTypes,StorageTypes})
    if ncol(table) == 0
        print(io,"Empty Table")
        return
    end

    s = Base.tty_size() # [height, width] in characters TODO fix for Julia 0.5
    maxl = max(5,div(s[1],5)) # Maximum number of lines to show (head, then tail)

    # Lengths of left, right and seperators should be consistent...
    tl = "┌─"
    t = "─" # length 1
    tr = "─┐"
    tsep = "─┬─"
    hl = "├─"
    h = "─" # length 1
    hsep = "─┼─"
    hr = "─┤"
    l = "│ "
    sep = " │ "
    r = " │"
    bl = "└─"
    b = "─" # length 1
    br = "─┘"
    bsep = "─┴─"
    pad = " " # length 1
    vdots = "⋮"# length 1
    hdots = "…" # length 1

    # First we format all of our output and determine its size

    # Rows (on side)
    row_header_str = string(name(DefaultKey))
    row_width = length(row_header_str)
    row_str = Vector{UTF8String}()

    # header....
    ncols = ncol(table)
    col_names = names(table)
    header_str = [UTF8String(string(col_names[i])) for i = 1:ncols]
    widths = [length(header_str[i]) for i = 1:ncols]

    width_suggestions = fill(20,ncols) # Default to reasonably big. except for some types
    for c = 1:ncols
        if eltype(table.data[c]) <: Union{Bool,Nullable{Bool},Float64,Float32} && widths[c] < width_suggestions[c]
            width_suggestions[c] = widths[c]
        end
    end

    # data...
    data_str = [Vector{UTF8String}() for i = 1:ncols]
    n_skipped_cols = 0
    if length(table) > 0
        if length(table) > 2*maxl
            for i = 1:maxl
                push!(row_str,string(i))
                for c = 1:ncols
                    tmp = compactstring(table.data[c][i],width_suggestions[c])
                    push!(data_str[c],tmp)
                end
            end

            for i = endof(table)-maxl+1:endof(table)
                push!(row_str,string(i))
                for c = 1:ncols
                    tmp = compactstring(table.data[c][i],width_suggestions[c])
                    push!(data_str[c],tmp)
                end
            end
        else
            for i = 1:length(table)
                push!(row_str,string(i))
                for c = 1:ncols
                    tmp = compactstring(table.data[c][i],width_suggestions[c])
                    push!(data_str[c],tmp)
                end
            end
        end
        row_width = max(row_width,maximum(map(length,row_str)))

        # Next we fix up some of the strings
        for c = 1:ncols
            align_strings(eltype(table.data[c]), data_str[c])
            widths[c] = max(length(header_str[c]),maximum(map(length,data_str[c])))
        end

        # Now we see if it is too wide...
        max_width = s[2]
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

    end

    # Now we show the table using computed widths for decorations

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

    # Data
    if length(table) > 2*maxl
        for i = 1:maxl
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
        end

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

        for i = maxl+1:2*maxl
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
        end
    else
        for i = 1:length(table)
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
        for i = length(Index)+1-n_skipped_cols:length(Index)
            print(io,"$(Index[i])")
            if i < length(Index)
                print(io, ", ")
            end
        end
    end
end

function Base.showall{Index,ElTypes,StorageTypes}(io::IO,table::Table{Index,ElTypes,StorageTypes})
    if ncol(table) == 0
        print(io,"Empty Table")
        return
    end

    s = Base.tty_size() # [height, width] in characters TODO fix for Julia 0.5
    maxl = max(5,div(s[1],5)) # Maximum number of lines to show (head, then tail)

    # Lengths of left, right and seperators should be consistent...
    tl = "┌─"
    t = "─" # length 1
    tr = "─┐"
    tsep = "─┬─"
    hl = "├─"
    h = "─" # length 1
    hsep = "─┼─"
    hr = "─┤"
    l = "│ "
    sep = " │ "
    r = " │"
    bl = "└─"
    b = "─" # length 1
    br = "─┘"
    bsep = "─┴─"
    pad = " " # length 1
    vdots = "⋮"# length 1
    hdots = "…" # length 1

    # First we format all of our output and determine its size

    # Rows (on side)
    row_header_str = string(name(DefaultKey))
    row_width = length(row_header_str)
    row_str = Vector{UTF8String}()

    # header....
    ncols = ncol(table)
    col_names = names(table)
    header_str = [UTF8String(string(col_names[i])) for i = 1:ncols]
    widths = [length(header_str[i]) for i = 1:ncols]

    width_suggestions = fill(32,ncols)
    for c = 1:ncols
        if eltype(table.data[c]) <: Union{Bool,Nullable{Bool},Float64,Float32} && widths[c] < width_suggestions[c]
            width_suggestions[c] = widths[c]
        end
    end

    # data...
    data_str = [Vector{UTF8String}() for i = 1:ncols]
    for i = 1:length(table)
        push!(row_str,string(i))
        for c = 1:ncols
            tmp = compactstring(table.data[c][i],width_suggestions[c])
            push!(data_str[c],tmp)
        end
    end
    row_width = max(row_width,maximum(map(length,row_str)))

    # Next we fix up some of the strings
    for c = 1:ncols
        align_strings(eltype(table.data[c]), data_str[c])
        widths[c] = max(length(header_str[c]),maximum(map(length,data_str[c])))
    end

    # Now we show the table using computed widths for decorations

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

    # Data
    for i = 1:length(table)
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
end

#=
function Base.showall{Index,ElTypes,StorageTypes}(io::IO,table::Table{Index,ElTypes,StorageTypes})
    summary(io,table)
    for i = 1:length(table)
        if i == endof(table)
            print(io,i," ",table[i])
        else
            println(io,i," ",table[i])
        end
    end
end
=#
