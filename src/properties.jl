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

struct Compute{names, F} <: Function
    f::F
end

(::Type{Compute{names}})(f) where {names} = Compute{names, typeof(f)}(f)

@generated function (c::Compute{names})(x) where {names}
    exprs = [:(getproperty(x, $(QuoteNode(n)))) for n in names]
    return Expr(:call, :(c.f), exprs...)
end

"""
    @compute(...)

The `@compute` macro returns a function which performs a calculation on the properties of an
object, such as a `NamedTuple`.

The input expression is standard Julia code, with `\$` prepended to property names. For
example. if you want to refer to a property named `a` then use `\$a` in the expression.

# Example

```julia
julia> nt = (a = 1, b = 2.0, c = false)
(a = 1, b = 2.0, c = false)

julia> @compute(\$a + \$b)(nt)
3.0
```
"""
macro compute(expr)
    # We traverse the expression tree and locate the $ nodes, which we note the name of and
    # replace with getproperty calls
    names = Symbol[]

    if expr isa Expr && expr.head == :$ && length(expr.args) == 1 && expr.args[1] isa Symbol
        return :($(GetProperty{expr.args[1]}()))
    end

    compute_expr!(names, expr)
    return :(Compute{$(tuple(names...))}((x...) -> $expr))
end

function compute_expr!(names::Vector{Symbol}, expr::Expr)
    if expr.head == :$
        @assert length(expr.args) == 1
        n = expr.args[1]::Symbol

        i = 0
        for j = 1:length(names)
            if names[j] == n
                i = j
                break
            end
        end
        if i == 0
            push!(names, n)
            i = length(names)
        end

        expr.head = :ref
        expr.args = [:x, i]
    else
        compute_expr!(names, expr.head)
        foreach(ex -> compute_expr!(names, ex), expr.args)
    end

    return nothing
end

compute_expr!(names::Vector{Symbol}, expr::Any) = nothing

struct Select{names, Fs <: Tuple} <: Function
    fs::Fs
end

(::Type{Select{names}})(fs::Tuple) where {names} = Select{names, typeof(fs)}(fs)

@generated function (s::Select{names})(x) where {names}
    exprs = [:($(names[i]) = (s.fs[$i])(x)) for i in 1:length(names)]
    return Expr(:call, Expr(:call, :propertytype, :x), Expr(:tuple, exprs...))
end

"""
    @select(...)

The `@select` macro returns a function which performs an arbitrary transformation of the
properties of an object, such as a `NamedTuple`.

The input expression is a comma-seperated list of `lhs = rhs` pairs. The `lhs` is the name
of the new property to calculate. The `rhs is  standard Julia code, with `\$` prepended to
input property names. For example. if you want to rename an input property `a` to be called
`b`, use `@select(b = \$a)`.

As a special case, if a property is to be simply replicated the `= rhs` part can be dropped,
for example `@select(a)` is synomous with `@select(a = \$a)`.

# Example

```julia
julia> nt = (a = 1, b = 2.0, c = false)
(a = 1, b = 2.0, c = false)

julia> @select(a, sum_a_b = \$a + \$b)(nt)
(a = 1, sum_a_b = 3.0)
```
"""
macro select(exprs...)
    # For each express we extract the output property name and the associated `Compute`.
    names = Symbol[]
    fs = Expr[]

    if exprs isa Tuple{Vararg{Symbol}}
        return :($(GetProperties{exprs}()))
    end

    for expr in exprs
        if expr isa Symbol
            push!(names, expr)
            push!(fs, :(GetProperty{$(QuoteNode(expr))}()))
        elseif expr isa Expr && expr.head == :(=)
            @assert length(expr.args) == 2
            push!(names, expr.args[1])
            internal_names = Symbol[]
            compute_expr!(internal_names, expr.args[2])
            push!(fs, :(Compute{$(tuple(internal_names...))}((x...) -> $(expr.args[2]))))
        else
            error("Bad input to @select")
        end
    end

    @assert length(unique(names)) == length(names)

    return :(Select{$(tuple(names...))}(tuple($(fs...))))
end
