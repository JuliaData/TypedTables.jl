"""
Read a table from another data structure that supports indexing columns by
symbols, such as a DataFrame. Requires a well-specified `FieldIndex`.

The reverse transformation (to DataFrames) can be acheived by:
   DataFrames(collect(table.data), collect(names(table)))
"""
@generated function readtable(index::FieldIndex, x)
    exprs = ntuple(i->:(x[$(index[i])]), length(index))
    expr = Expr(:tuple, exprs...)
    return :( Table(index, $expr) )
end

"""
Read a table from a file in DLM (delimited) or CSV (comma-sereperated values,
default) text-based formats, using Julia's inbuilt readdlm.
"""
function readtable(index::FieldIndex, file::IOStream; delim::Char = ',', eol::Char = '\n', header::Bool = false, kwargs...)
    # Read data from file...
    local headerdata, data
    if header
        (data, headerdata) = readdlm(file, delim, Any, eol; header = header, kwargs...)
    else
        data = readdlm(file, delim, Any, eol; header = header, kwargs...)
    end

    # Read the header, verify columns and get corresponding indices
    local indices
    if header == true
        # Reoreded or extra indices are possible
        colnames = map(string,names(index))

        indices = Vector{Int}(length(index))
        for i = 1:length(colnames)
            found = 0
            for k = 1:length(headerdata)
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
    out = Table(index)
    for i = 1:size(data,1)
        push!(out, (data[i,indices]...))
    end

    return out
end
