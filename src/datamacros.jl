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
            #exprs[i-1] = :( TypedTables.extractfield(TypedTables.index($(esc(table))),Val{$(Expr(:quote,expr))}) = $(esc(table))[Val{$(Expr(:quote,expr))}] )
            exprs[i-1] = :( $(esc(expr)) = $(esc(table))[Val{$(Expr(:quote, expr))}] )
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
                        #exprs[i-1] = :( TypedTables.rename(TypedTables.extractfield(TypedTables.index($(esc(table))),Val{$(Expr(:quote,expr_right))}), Val{$(Expr(:quote,expr_left))}) = $(esc(table))[Val{$(Expr(:quote,expr_right))}] )
                        exprs[i-1] = :($(esc(expr_left)) = $(esc(table))[Val{$(Expr(:quote,expr_right))}])
                    elseif isa(expr_left, Expr) && expr_left.head == :(::)
                        expr_left.args[2] = :($(esc(expr_left.args[2])))
                        #exprs[i-1] = :($(macroexpand(:(TypedTables.@field($expr_left)))) = $(esc(table))[Val{$(Expr(:quote,expr_right))}] )
                        exprs[i-1] = :($(esc(expr_left)) = $(esc(table))[Val{$(Expr(:quote,expr_right))}])
                    else
                        return(:( error("Expected syntax like @select(table, col1, newname = col2, newcol::newtype = col1 -> f(col1))") ))
                    end
                elseif operation == :compute
                    # LHS must be new field
                    if isa(expr_left,Symbol)
                        lhs = esc(expr_left)
                    elseif isa(expr_left, Expr) && expr_left.head == :(::)
                        #expr_left.args[2] = :($(esc(expr_left.args[2])))
                        #lhs = :($(macroexpand(:(TypedTables.@field($expr_left)))))
                        lhs = esc(expr_left)
                    else
                        return(:( error("Expected syntax like @select(table, col1, newname = col2, newcol::newtype = col1 -> f(col1))") ))
                    end
                    #eltype = :( eltype($lhs) )

                    # RHS is (field_names) -> function. First identify the field names
                    fields = Vector{Symbol}()
                    if isa(expr_right.args[1], Symbol)
                        push!(fields, expr_right.args[1])
                    elseif isa(expr_right.args[1], Expr) && expr_right.args[1].head == :tuple
                        for j = 1:length(expr_right.args[1].args)
                            push!(fields, expr_right.args[1].args[j])
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
                    exprs[i-1] = :( $(lhs) = [$(func) for idx = 1:length($(esc(table)))] )
                end
            #elseif expr.head == :(::)
                # Straightforward extraction (by name and type)
                #exprs[i-1] = :($(macroexpand(:(TypedTables.@field($expr)))) = $(esc(table))[Val{$(Expr(:quote,expr.args[1]))}] )
            else
                return(:( error("Expected syntax like @select(table, col1, newname = col2, newcol::newtype = col1 -> f(col1))") ))
            end
        else
            return(:( error("Expected syntax like @select(table, col1, newname = col2, newcol::newtype = col1 -> f(col1))") ))
        end
    end

    return Expr(:macrocall, Symbol("@Table"), exprs...)
end

macro filter(x...)
    if length(x) == 0 # Is this an error or an empty table?
        return :(error("@filter expects a table"))
    elseif length(x) == 1
        return :($(esc(x[1])))
    end
    table = x[1]
    exprs = Vector{Any}(length(x)-1)
    for i = 1:length(x)-1
        expr = x[i+1]
        if !isa(expr,Expr) || !(expr.head == :(->))
            return :( error("Expected syntax like @filter(table, col1 -> col1 == 1, (col1, col2) -> col1 < col2 )"))
        end

        # Make list of symbols and replacements
        fields = Vector{Symbol}()
        if isa(expr.args[1], Symbol)
            push!(fields, expr.args[1])
        elseif isa(expr.args[1], Expr) && expr.args[1].head == :tuple
            for j = 1:length(expr.args[1].args)
                if !isa(expr.args[1].args[j], Symbol)
                    return :( error("Expected syntax like @filter(table, col1 -> col1 == 1, (col1, col2) -> col1 < col2 )"))
                end
                push!(fields, expr.args[1].args[j])
            end
        else
            return :( error("Expected syntax like @filter(table, col1 -> col1 == 1, (col1, col2) -> col1 < col2 )"))
        end

        # Given field names build the replacements
        replacements = [:($(esc(table))[idx, Val{$(Expr(:quote,fields[i]))}]) for i = 1:length(fields)]

        # Now make replacements in the boolean function
        func = expr.args[2]
        replace_symbols!(func, fields, replacements)

        # Now make the expression
        exprs[i] = func
    end
    test_expr = exprs[1]
    for i = 2:length(exprs)
        test_expr = :($test_expr && $(exprs[i]))
    end

    # Now build a few lines of code
    quote
        test = Bool[$test_expr for idx = 1:length($(esc(table)))]
        $(esc(table))[test]
    end
end

macro filter!(x...)
    if length(x) == 0 # Is this an error or an empty table?
        return :(error("@filter expects a table"))
    elseif length(x) == 1
        return :($(esc(x[1])))
    end
    table = x[1]
    exprs = Vector{Any}(length(x)-1)
    for i = 1:length(x)-1
        expr = x[i+1]
        if !isa(expr,Expr) || !(expr.head == :(->))
            return :( error("Expected syntax like @filter(table, col1 -> col1 == 1, (col1, col2) -> col1 < col2 )"))
        end

        # Make list of symbols and replacements
        fields = Vector{Symbol}()
        if isa(expr.args[1], Symbol)
            push!(fields, expr.args[1])
        elseif isa(expr.args[1], Expr) && expr.args[1].head == :tuple
            for j = 1:length(expr.args[1].args)
                if !isa(expr.args[1].args[j], Symbol)
                    return :( error("Expected syntax like @filter(table, col1 -> col1 == 1, (col1, col2) -> col1 < col2 )"))
                end
                push!(fields, expr.args[1].args[j])
            end
        else
            return :( error("Expected syntax like @filter(table, col1 -> col1 == 1, (col1, col2) -> col1 < col2 )"))
        end

        # Given field names build the replacements
        replacements = [:($(esc(table))[idx, Val{$(Expr(:quote,fields[i]))}]) for i = 1:length(fields)]

        # Now make replacements in the boolean function
        func = expr.args[2]
        replace_symbols!(func, fields, replacements)

        # Now make the expression
        exprs[i] = func
    end
    test_expr = exprs[1]
    for i = 2:length(exprs)
        test_expr = :($test_expr && $(exprs[i]))
    end

    # Now build a few lines of code
    # TODO can switch this to an anonymous function using filter!() for 0.5
    # TODO in general we should also consider a lazy view like filter()
    quote
        test_not = Bool[!$test_expr for idx = 1:length($(esc(table)))]
        deleteat!($(esc(table)), (:)[test_not])
    end
end

macro filter_mask(x...)
    if length(x) == 0 # Is this an error or an empty table?
        return :(error("@filter expects a table"))
    elseif length(x) == 1
        return :($(esc(x[1])))
    end
    table = x[1]
    exprs = Vector{Any}(length(x)-1)
    for i = 1:length(x)-1
        expr = x[i+1]
        if !isa(expr,Expr) || !(expr.head == :(->))
            return :( error("Expected syntax like @filter(table, col1 -> col1 == 1, (col1, col2) -> col1 < col2 )"))
        end

        # Make list of symbols and replacements
        fields = Vector{Symbol}()
        if isa(expr.args[1], Symbol)
            push!(fields, expr.args[1])
        elseif isa(expr.args[1], Expr) && expr.args[1].head == :tuple
            for j = 1:length(expr.args[1].args)
                if !isa(expr.args[1].args[j], Symbol)
                    return :( error("Expected syntax like @filter(table, col1 -> col1 == 1, (col1, col2) -> col1 < col2 )"))
                end
                push!(fields, expr.args[1].args[j])
            end
        else
            return :( error("Expected syntax like @filter(table, col1 -> col1 == 1, (col1, col2) -> col1 < col2 )"))
        end

        # Given field names build the replacements
        replacements = [:($(esc(table))[idx, Val{$(Expr(:quote,fields[i]))}]) for i = 1:length(fields)]

        # Now make replacements in the boolean function
        func = expr.args[2]
        replace_symbols!(func, fields, replacements)

        # Now make the expression
        exprs[i] = func
    end
    test_expr = exprs[1]
    for i = 2:length(exprs)
        test_expr = :($test_expr && $(exprs[i]))
    end

    # Now build a few lines of code
    quote # TODO can switch this to an anonymous function for 0.5
        Bool[$test_expr for idx = 1:length($(esc(table)))]
    end
end

function replace_symbols!(a::Expr, symbols::Vector{Symbol}, exprs::Vector)
    for i = 1:length(a.args)
		if isa(a.args[i], Expr) && a.args[i].head != :line && a.args[i].head != :.
		    replace_symbols!(a.args[i], symbols, exprs)
        elseif isa(a.args[i], Symbol)
            notfound = true
            for j = 1:length(symbols)
                if a.args[i] == symbols[j]
                    a.args[i] = exprs[j]
                    notfound = false
                    break
                end
            end
            # If it's not our symbol then it belongs to the caller's scope
            if notfound
                a.args[i] = :($(esc(a.args[i])))
            end
        elseif isa(a.args[i], Expr) && a.args[i].head == :.
            a.args[i] = :($(esc(a.args[i])))
        end
    end
end
