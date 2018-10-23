# Data representation

*TypedTables* leaves the user fully in charge of how they represent and store their data. The only requirements are that each column is an `AbstractArray`, all the columns have matching sizes, and that each column name is distinct.

This section contains some basic advice on how to choose what arrays to use to represent your data, depending on your needs.

## Element types and `missing` data

Each column is an `AbstractArray{T}`, where `T` is the `eltype` (element type) of the array.

Element types can be *concrete* or *abstract*. Concrete types are fully-determined types, such as `Int`, `Float64`, or `String` and are the fastest option because the precise layout of the bytes in memory is known by the compiler in advance, and optimized machine code can be produced. However, when you construct an array with a given concrete elememt types, only elements of that type can be stored in the array. (Note that when writing to arrays, Julia will use `convert` by default to attempt to convert data to the correct element type, for example converting an integer into a floating-point number).

Abstract element types like `Any`, `Number` and `AbstractString` are much more flexible - many more types of data can be written into the same array. However, Julia's compiler knows very little about these types in advance (like what the memory layout of the data is, or what function methods they support), so the compiled code must deal with these uncertainties *dynamically*, with a certain run-time overhead. This is a trade-off - using abstract types may allow the programmer to worry less about the details, at the cost of execution speed.

Julia also provides a middle-ground, through the `Union{A, B}` type. This type represents data which is *either* of type `A` or of type `B`. If types `A` and `B` are both concrete, Julia performs optimizations by knowing more about memory layout and method dispatch, compared to abstract types like `Any`. To achieve this, a memory layout is used where a Boolean value indicates whether the actual value is an `A` or a `B`, and the remaining bytes contain the actual data.

One very convenient use case for this is to handle missing data. Julia 1.0 contains a (zero-byte) type called `Missing` with an instance called `missing` (and all instances of zero-byte types are equivalent, by definition). Many functions are defined for missing, such as `1 + missing = missing` and so-on, so the "missingness" of the data propagates correctly through even extremely complex calculations.

The type `Union{T, Missing}` is the officially recommended way to represent data which may be of type `T` or otherwise `Missing`. For example, a column which contains *optional* `Float64` values may be best represent with element type `Union{Float64, Missing}`. In practice, the amount of memory needed to store an element is `sizeof(T) + 1` bytes - for example, `Union{Float64, Missing}` requires 9 bytes-per-element rather than 8 bytes-per-element for a plain `Float64`. The compiler will produce quite efficient code to handle the `missing` data elements, and dispatch the data which is present to fully-optimzed methods, as usual.

## Array types

As mentioned, each column is an `AbstractArray`, but there are many different *concrete* implementations of the `AbstractArray` interface. The `AbstractArray` interface can be implemented by any type that has a `size` and supports random access via `getindex` - the syntax `array[index]` - and thus is extremely flexible, yet powerful.

`Array` is the prototypical `AbstractArray`, which provides random access to a flat array of memory. It is the type created by array-literal syntax, such as `[1, 2, 3]`. You can create an array of a given element type by prepending the type - for example, `Float64[1, 2, 3]` is equivalent to `[1.0, 2.0, 3.0]`. You can create an empty vector of a given type `T` with `T[]` or the explicit constructor `Vector{T}()`. If you want to be able to add missing values later, you may want to create an empty array with `Union{Float64, Missing}[]` or `Vector{Union{Float64, Missing}}()`.

`Array`s are sufficient for playing with a relatively small amount of data at the REPL. However, *TypedTables* will let you use any of a wide variety of array types, depending on your needs. A few examples include:

 * Typical `Array`-based columns represent continugous chunks of memory, and can be [memory-mapped](https://docs.julialang.org/en/v1/stdlib/Mmap/index.html) from disk for a simple way of doing out-of-core analytics.

 * Acceleration indices can be attached to columns using the [AcceleratedArrays](https://github.com/andyferris/AcceleratedArrays.jl) package, speeding up searches and joins.

 * Some data can be stored in compressed form using [sparse arrays](https://docs.julialang.org/en/v1/stdlib/SparseArrays/index.html), [categorical arrays](http://juliadata.github.io/CategoricalArrays.jl/latest/using.html), and so-on.

 * Columns could be stored and processed on a GPU with [GPU-backed array](https://github.com/JuliaGPU/GPUArrays.jl) using [CUDA](https://github.com/JuliaGPU/CuArrays.jl), [OpenCL](https://github.com/JuliaGPU/CLArrays.jl), [ArrayFire](https://github.com/JuliaComputing/ArrayFire.jl), etc.

 * Columns might be distributed and processed in parallel over multiple machines with [DistributedArrays](https://github.com/JuliaParallel/DistributedArrays.jl) or between multiple processes with [`SharedArrays`](https://docs.julialang.org/en/v1/stdlib/SharedArrays/index.html).

 * In extreme cases, tables with a small, fixed number of rows might be most efficient represented with a [statically sized array](https://github.com/JuliaArrays/StaticArrays.jl).

In each case, the user will be able to use much the same interface (and code) to perform their transformations. In the background, Julia's compiler will create specialized, performant machine code, for whichever backing array you choose. You may be able to scale your calculations from rapid experimentation to large-scale production via a few simple changes to your array types.
