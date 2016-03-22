"""
Read a table from another data structure that supports indexing columns by
symbols, such as a DataFrame. Requires a well-specified `FieldIndex`.

The reverse transformation (to DataFrames) can be acheived by:
   DataFrames(collect(table.data), collect(names(table)))
"""
@generated function readtable{Fields}(index::FieldIndex{Fields}, x)
    exprs = ntuple(i->:(x[$(Expr(:quote,name(Fields[i])))]), length(Fields))
    expr = Expr(:tuple, exprs...)
    return :( Table(index, $expr) )
end

"""
Read a table from a file in DLM (delimited) or CSV (comma-sereperated values,
default) text-based formats, using Julia's inbuilt readdlm.
"""
function readtable(index::FieldIndex, file::Union{AbstractString,IOStream}; kwargs...)
    table = Table(index)
    readtable!(table, file; kwargs...)
    return table
end

function readtable!{index}(table::Table{index}, filename::AbstractString; kwargs...)
    open(filename) do fio
        readtable!(table, fio; kwargs...)
    end
end

"""
Append data to a table from a file in DLM (delimited) or CSV (comma-sereperated
values, default) text-based formats, using Julia's inbuilt readdlm.
"""
function readtable!{index}(table::Table{index}, file::IOStream; delim::Char = ',', eol::Char = '\n', header::Bool = false, kwargs...)
    # Read data from file...
    local headerdata, data
    if header == true
        (data, headerdata) = readdlm(file, delim, Any, eol; header = true, kwargs...)
    else
        data = readdlm(file, delim, Any, eol; header = false, kwargs...)
    end

    # Read the header, verify columns and get corresponding indices
    local indices
    if header == true
        # Reoreded or extra indices are possible
        colnames = map(string,names(index))

        indices = Vector{Int}(length(index))
        for i = 1:length(colnames)
            found = 0
            for j = 1:length(headerdata)
                if colnames[i] == headerdata[j]
                    indices[i] = j
                    found += 1
                end
            end
            if found == 0
                error("Didn't find header string $(colnames[i])")
            elseif found > 1
                error("Found $found duplicates of header string $(colnames[i])")
            end
        end
    else
        indices = collect(1:length(index))
    end

    # Convert to a table
    for i = 1:size(data,1)
        push!(table, ntuple(j->convert(eltype(index[indices[j]]), data[i,indices[j]]), length(index)))
    end
end

function writetable{index}(filename::AbstractString, table::Table{index}; kwargs...)
    fio = open(filename, false, true, true, true, false)
    writetable(fio, table; kwargs...)
    close(fio)
end

"""
Write a table to disk using delimeted text format. Optional arguments include:

  header = false
  delim = ','
  eol = '\n'
  null = "NA"
  string_delim = '\"'
  string_delim_right = string_delim (for guillements, chevrons, Gänsefüßchen...)
  char_delim = '\''
  char_delim_right = char_delim
"""
function writetable{index}(fileio::IOStream, table::Table{index}; header::Bool = false, delim = ',', eol = '\n', string_delim = '\"', string_delim_right = string_delim, char_delim = '\'', char_delim_right = char_delim, null = "NA")
    if header == true
        n = names(index)
        for j = 1:ncol(table)
            write(fileio, n[j])
            if j == ncol(table)
                write(fileio, eol)
            else
                write(fileio, delim)
            end
        end
    end

    isnullable = fill(false, ncol(table))
    isstring = fill(false, ncol(table))
    ischar = fill(false, ncol(table))
    for i = 1:length(index)
        typ = eltype(index[i])
        if typ <: Nullable
            isnullable[i] = true
            typ = eltype(typ)
        end
        isstring[i] = typ <: AbstractString
        ischar[i] = typ <: Char
    end


    for i = 1:nrow(table)
        for j = 1:ncol(table)
            if isnullable[j]
                if isnull(table.data[j][i])
                    write(fileio, null)

                    if j == ncol(table)
                        write(fileio, eol)
                    else
                        write(fileio, delim)
                    end
                else
                    if isstring[j]
                        write(fileio, string_delim)
                    elseif ischar[j]
                        write(fileio, char_delim)
                    end
                    write(fileio, string(get(table.data[j][i])))
                    if isstring[j]
                        write(fileio, string_delim_right)
                    elseif ischar[j]
                        write(fileio, char_delim_right)
                    end

                    if j == ncol(table)
                        write(fileio, eol)
                    else
                        write(fileio, delim)
                    end
                end
            else
                if isstring[j]
                    write(fileio, string_delim)
                elseif ischar[j]
                    write(fileio, char_delim)
                end
                write(fileio, string(table.data[j][i]))
                if isstring[j]
                    write(fileio, string_delim_right)
                elseif ischar[j]
                    write(fileio, char_delim_right)
                end

                if j == ncol(table)
                    write(fileio, eol)
                else
                    write(fileio, delim)
                end
            end
        end
    end
end
