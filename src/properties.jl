# GetProperty
struct GetProperty{name} <: Function
end
@inline GetProperty(name::Symbol) = GetProperty{name}()

"""
    getproperty(name::Symbol)

Return a curried function equivalent to `x -> getproperty(x, name)`.

Internally, `name` is stored as a type parameter of a `GetProperty` object for the purpose
of constant propagation. See also `getproperties`.

# Example

Extract property `b` from a `NamedTuple`.

```julia
julia> nt = (a = 1, b = 2.0, c = false)
(a = 1, b = 2.0, c = false)

julia> getproperty(:b)(nt)
2.0
```
"""
@inline function Base.getproperty(name::Symbol)
    return GetProperty(name)
end

@inline (::GetProperty{name})(x) where {name} = getproperty(x, name)

# GetProperties
struct GetProperties{names} <: Function
end

@inline GetProperties(names::Tuple{Vararg{Symbol}}) = GetProperties{names}()

"""
    getproperties(names::Symbol...)

Return a function that extracts a set of properties with the given `names` from an object,
returning a new object with just those properties.

Internally, the `names` are stored as a type parameter of a `GetProperties` object for the
purpose of constant propagation. You may overload the `propertytype` function to control
the type of the object that is returned, which by default will be a `NamedTuple`. See also
`getproperty`.

# Example

Extract properties `a` and `c` from a `NamedTuple`.

```julia
julia> nt = (a = 1, b = 2.0, c = false)
(a = 1, b = 2.0, c = false)

julia> getproperties(:a, :c)(nt)
(a = 1, c = false)
```
"""
@inline function getproperties(names::Symbol...)
    return GetProperties(names)
end

@generated function (::GetProperties{names})(x) where {names}
    exprs = [:($n = getproperty(x, $(QuoteNode(n)))) for n in names]
    return Expr(:call, Expr(:call, :propertytype, :x), Expr(:tuple, exprs...))
end

"""
    propertytype(x)

Return a constructor for an object similar to `x` that can accept a `NamedTuple` with
arbitrary properties and support `getproperty`. Used for determining the return type of a
`getproperties` function. The defaults return type is `NamedTuple`.
"""
propertytype(x) = identity # the input is always a `NamedTuple`