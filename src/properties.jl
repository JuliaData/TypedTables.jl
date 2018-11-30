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
propertytype(x) = identity # the input is always a `NamedTuple`, and so this is the default propertytype

struct Compute{names, F} <: Function
    f::F
end

(::Type{Compute{names}})(f) where {names} = Compute{names, typeof(f)}(f)

@generated function (c::Compute{names})(x) where {names}
    exprs = [:(getproperty(x, $(QuoteNode(n)))) for n in names]
    return Expr(:call, :(c.f), exprs...)
end

const UNARY_OPERATORS = [:!, :-]
const BINARY_OPERATORS = [:+, :-, :*, :/, :\, ://, :÷, :×, :∈, :∉, :⊂, :⊆, :⊃, :⊇, :⊄, :⊈, :⊅, :⊉, :(==), :(===), :<, :<=, :>, :>=, :!=, :!==, :\, :≠, :≡, :≢, :≯ ,:≱, :≮, :≰]

"""
    @Compute(...)

The `@Compute` macro returns a function which performs a calculation on the properties of an
object, such as a `NamedTuple`.

The input expression is standard Julia code, with `\$` prepended to property names. For
example. if you want to refer to a property named `a` then use `\$a` in the expression.

# Example

```julia
julia> nt = (a = 1, b = 2.0, c = false)
(a = 1, b = 2.0, c = false)

julia> @Compute(\$a + \$b)(nt)
3.0
```
"""
macro Compute(expr)
    # We traverse the expression tree and locate the $ nodes, which we note the name of and
    # replace with getproperty calls
    names = Symbol[]

    # First we check if we can simplify the expression to make it more introsepctable
    if expr isa Expr
        # Simple column extraction
        if expr.head == :$ && length(expr.args) == 1 && expr.args[1] isa Symbol
            return :($(GetProperty{expr.args[1]}()))
        end

        if expr.head == :call && countdollars(expr.args[1]) == 0
            # Single argument function
            if length(expr.args) == 2 && expr.args[2] isa Expr && expr.args[2].head == :$ && length(expr.args[2].args) == 1 && expr.args[2].args[1] isa Symbol
                f = expr.args[1]
                name = expr.args[2].args[1]
                return :(Compute{($(QuoteNode(name)),)}($f))
            end

            # Two argument functions
            if length(expr.args) == 3
                # Binary function
                if expr.args[2] isa Expr && expr.args[2].head == :$ && length(expr.args[2].args) == 1 && expr.args[2].args[1] isa Symbol && expr.args[3] isa Expr && expr.args[3].head == :$ && length(expr.args[3].args) == 1 && expr.args[3].args[1] isa Symbol
                    f = expr.args[1]
                    name1 = expr.args[2].args[1]
                    name2 = expr.args[3].args[1]
                    return :(Compute{($(QuoteNode(name1)),$(QuoteNode(name2)))}($f))
                end                

                # Fix1
                if countdollars(expr.args[2]) == 0 && expr.args[3] isa Expr && expr.args[3].head == :$ && length(expr.args[3].args) == 1 && expr.args[3].args[1] isa Symbol
                    f = expr.args[1]
                    x = expr.args[2]
                    name = expr.args[3].args[1]
                    return :(Compute{($(QuoteNode(name)),)}(Base.Fix1($f, $x)))
                end

                # Fix2
                if expr.args[2] isa Expr && expr.args[2].head == :$ && length(expr.args[2].args) == 1 && expr.args[2].args[1] isa Symbol && countdollars(expr.args[3]) == 0
                    f = expr.args[1]
                    name = expr.args[2].args[1]
                    x = expr.args[3]
                    return :(Compute{($(QuoteNode(name)),)}(Base.Fix2($f, $x)))
                end
            end
        end

        # Unary operator
        if expr.head ∈ UNARY_OPERATORS && length(expr.args) == 1 && expr.args[1].head == :$ && length(expr.args[1].args) == 1 && expr.args[1].args[1] isa Symbol
            f = expr.head
            name = expr.args[1].args[1]
            return :(Compute{($(QuoteNode(name)),)}($f))
        end

        # Binary operator
        if expr.head ∈ BINARY_OPERATORS && length(expr.args) == 2
            # Binary function
            if expr.args[1].head == :$ && length(expr.args[1].args) == 1 && expr.args[1].args[1] isa Symbol && expr.args[2].head == :$ && length(expr.args[2].args) == 1 && expr.args[2].args[1] isa Symbol
                f = expr.head
                name1 = expr.args[1].args[1]
                name2 = expr.args[2].args[1]
                return :(Compute{($(QuoteNode(name1)),$(QuoteNode(name2)))}($f))
            end

            # Fix1
            if countdollars(expr.args[1]) == 0 && expr.args[2].head == :$ && length(expr.args[2].args) == 1 && expr.args[2].args[1] isa Symbol
                f = expr.head
                x = expr.args[1]
                name = expr.args[2].args[1]
                return :(Compute{($(QuoteNode(name)),)}(Base.Fix1($f, $x)))
            end

            # Fix2
            if expr.args[1].head == :$ && length(expr.args[1].args) == 1 && expr.args[1].args[1] isa Symbol && countdollars(expr.args[2]) == 0
                f = expr.head
                name = expr.args[1].args[1]
                x = expr.args[2]
                return :(Compute{($(QuoteNode(name)),)}(Base.Fix2($f, $x)))
            end
        end        
    end

    # In the general case, we make a new closure
    compute_expr!(names, expr)
    return :(Compute{$(tuple(names...))}((x...) -> $expr))
end

countdollars(expr) = countdollars(expr, 0)
countdollars(expr, n::Int) = n
function countdollars(expr::Expr, n::Int)
    if expr.head == :$
        @assert length(expr.args) == 1 && expr.args[1] isa Symbol
        n += 1
    else
        n += sum(map(countdollars, expr.args))
    end
    return n
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
    @Select(...)

The `@Select` macro returns a function which performs an arbitrary transformation of the
properties of an object, such as a `NamedTuple`.

The input expression is a comma-seperated list of `lhs = rhs` pairs. The `lhs` is the name
of the new property to calculate. The `rhs is  standard Julia code, with `\$` prepended to
input property names. For example. if you want to rename an input property `a` to be called
`b`, use `@Select(b = \$a)`.

As a special case, if a property is to be simply replicated the `= rhs` part can be dropped,
for example `@Select(a)` is synomous with `@Select(a = \$a)`.

# Example

```julia
julia> nt = (a = 1, b = 2.0, c = false)
(a = 1, b = 2.0, c = false)

julia> @Select(a, sum_a_b = \$a + \$b)(nt)
(a = 1, sum_a_b = 3.0)
```
"""
macro Select(exprs...)
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
