@recipe function f(tt::Table; indices = [1,2])
    if length(indices) == 2
        x_name, y_name = propertynames(tt)[indices]
        xguide --> string(x_name)
        yguide --> string(y_name)
        return getproperty(tt, x_name), getproperty(tt, y_name)
    elseif length(indices) == 3
        x_name, y_name, z_name = propertynames(tt)[indices]
        xguide --> string(x_name)
        yguide --> string(y_name)
        zguide --> string(z_name)
        return getproperty(tt, x_name), getproperty(tt, y_name), getproperty(tt, z_name)
    else
        throw(ArgumentError("Keyword argument `indices` needs to be an integer array of length 2 or 3."))
    end
end

@recipe function f(tt::Table, column_names)
    if length(column_names) == 2
        x_name, y_name = column_names
        xguide --> string(x_name)
        yguide --> string(y_name)
        return getproperty(tt, x_name), getproperty(tt, y_name)
    elseif length(column_names) == 3
        x_name, y_name, z_name = column_names
        xguide --> string(x_name)
        yguide --> string(y_name)
        zguide --> string(z_name)
        return getproperty(tt, x_name), getproperty(tt, y_name), getproperty(tt, z_name)
    else
        throw(ArgumentError("The second argument `column_names` needs to be of length 2 or 3."))
    end
end
