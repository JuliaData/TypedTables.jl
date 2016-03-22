macro select(x...)
    if length(x) == 0 # Is this an error or an empty table?
        return :(error("@select expects a table"))
    end

    table = x[1]
    exprs = Vector{Any}(length(x)-1)
    for i = 2:length(x)
        expr = x[i]
        if isa(expr, Symbol)
            # Straightforward extraction (by name)
            exprs[i-1] = :( TypedTables.extractfield(TypedTables.index($(esc(table))),Val{$(Expr(:quote,expr))}) = $(esc(table))[Val{$(Expr(:quote,expr))}] )
        elseif isa(expr, Expr)
            if expr.head == :(=) || expr.head == :(kw)
                expr_left = expr.args[1]
                expr_right = expr.args[2]

                # Determine operation from RHS
                operation = :unknown
                if isa(expr_right, Symbol)
                    operation = :rename
                elseif isa(expr_right, Expr)
                    if expr_right.head == :(::)
                        return(:( error("Expected syntax like @select(table, col1, newname = col2, newcol::newtype = col1 -> f(col1))") ))
                    elseif expr_right.head == :(->)
                        operation = :compute
                    end
                end

                if operation == :unknown
                    return(:( error("Expected syntax like @select(table, col1, newname = col2, newcol::newtype = col1 -> f(col1))") ))
                elseif operation == :rename
                    if isa(expr_left,Symbol)
                        exprs[i-1] = :( TypedTables.rename(TypedTables.extractfield(TypedTables.index($(esc(table))),Val{$(Expr(:quote,expr_right))}), Val{$(Expr(:quote,expr_left))}) = $(esc(table))[Val{$(Expr(:quote,expr_right))}] )
                    elseif isa(expr_left, Expr) && expr_left.head == :(::)
                        exprs[i-1] = :($(macroexpand(:(TypedTables.@field($expr_left)))) = $(esc(table))[Val{$(Expr(:quote,expr_right))}] )
                    else
                        return(:( error("Expected syntax like @select(table, col1, newname = col2, newcol::newtype = col1 -> f(col1))") ))
                    end
                elseif operation == :compute

                    # LHS must be new field
                    if isa(expr_left,Symbol)
                        lhs = :( $(esc(expr_left)) )
                    elseif isa(expr_left, Expr) && expr_left.head == :(::)
                        lhs = :($(macroexpand(:(TypedTables.@field($expr_left)))))
                    else
                        return(:( error("Expected syntax like @select(table, col1, newname = col2, newcol::newtype = col1 -> f(col1))") ))
                    end
                    eltype = :( eltype($lhs) )

                    # RHS is (field_names) -> function. First identify the field names
                    fields = Vector{Symbol}()
                    if isa(expr_right.args[1], Symbol)
                        push!(fields, expr_right.args[1])
                    elseif isa(expr_right.args[1], Expr) && expr_right.args[1].head == :tuple
                        for i = 1:length(expr_right.args[1].args)
                            isa(expr_right.args[1].args[i], Symbol) || return(:( error("Expected syntax like @select(table, col1, newname = col2, newcol::newtype = col1 -> f(col1))") ))
                            push!(fields, expr_right.args[1].args[i])
                        end
                    else
                        return(:( error("Expected syntax like @select(table, col1, newname = col2, newcol::newtype = col1 -> f(col1))") ))
                    end

                    # Given field names build the replacements
                    replacements = [:($(esc(table))[idx, Val{$(Expr(:quote,fields[i]))}]) for i = 1:length(fields)]

                    # Now replace the symbols in the function as necessary.
                    func = expr_right.args[2]
                    replace_symbols!(func, fields, replacements)

                    # Now make the expression
                    exprs[i-1] = :( $(lhs) = $eltype[$(func) for idx = 1:length($(esc(table)))] )
                end
            elseif expr.head == :(::)
                # Straightforward extraction (by name and type)
                exprs[i-1] = :($(macroexpand(:(TypedTables.@field($expr)))) = $(esc(table))[Val{$(Expr(:quote,expr.args[1]))}] )
            else
                return(:( error("Expected syntax like @select(table, col1, newname = col2, newcol::newtype = col1 -> f(col1))") ))
            end
        else
            return(:( error("Expected syntax like @select(table, col1, newname = col2, newcol::newtype = col1 -> f(col1))") ))
        end
    end
    return Expr(:macrocall, Symbol("@table"), exprs...)
end


function replace_symbols!(a::Expr, symbols::Vector{Symbol}, exprs::Vector)
    for i = 1:length(a.args)
		if isa(a.args[i], Expr)
		    replace_symbols!(a.args[i], symbols, exprs)
        elseif isa(a.args[i], Symbol)
            for j = 1:length(symbols)
                if a.args[i] == symbols[j]
                    a.args[i] = exprs[j]
                    break
                end
            end
        end
    end
end
