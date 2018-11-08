# Data representation

*TypedTables* leaves the user fully in charge of how they represent and store their data. The only requirements are that each column is an `AbstractArray`, all the columns have matching sizes, and that each column name is distinct.

This section contains some basic advice on how to choose what arrays to use to represent your data, depending on your needs.

## Element types and `missing` data

Each column is an `AbstractArray{T}`, where `T` is the `eltype` (element type) of the array. Most frequently, this will be a `Vector{T}`, where `Vector` is a one-dimensional `Array`, unless you have special requirements.

In general, you should try to chose `T` to be a *concrete* type, such as `Int`, `Float64`, or `String`. Julia's compiler will know in advance how a concrete type is laid out in memory, and what function methods to dispatch to, allowing it to produce highly optimized machine code similar to hand-written C code.

Sometimes you may want to have more than one type of data in a column. One very convenient use case for this is to handle missing data. Julia 1.0 contains a value called `missing` of a type called `Missing` . Many functions are defined for missing, such as `1 + missing = missing` and so-on, so the "missingness" of the data propagates correctly through even extremely complex calculations. The *union* type `Union{T, Missing}` is the officially recommended way to represent data which may be of type `T` or otherwise `Missing`. For example, a column which contains *optional* `Float64` values may be best represent by a `Vector{Union{Float64, Missing}}`. Union types are treated specially be the compiler, where it takes advantage of the fact that the value can only be of one of a small number of known types.

If your column may contain any of a variety of Julia types, it may be suitable to use *abstract* types like `Any`. You will be able to insert any element into a `Vector{Any}`, but Julia will have to dynamically deal with the type of each element, slowing down run-time performance. This is a trade-off - using abstract types may allow the programmer to worry less about the details, at the cost of execution speed.

## Array types

As mentioned, each column is an `AbstractArray`, but there are many different *concrete* implementations of the `AbstractArray` interface. The `AbstractArray` interface can be implemented by any type that has a `size` and supports random access via `getindex` - the syntax `array[index]` - and thus is extremely flexible, yet powerful.

`Array` (and `Vector`) is the prototypical `AbstractArray`, which provides random access to a flat array of memory. It is the type created by array-literal syntax, such as `[1, 2, 3]`. You can create an array of a given element type by prepending the type - for example, `Float64[1, 2, 3]` is equivalent to `[1.0, 2.0, 3.0]`. You can create an empty vector of a given type `T` with `T[]` or the explicit constructor `Vector{T}()`. If you want to be able to add missing values later, you may want to create an empty array with `Union{Float64, Missing}[]` or `Vector{Union{Float64, Missing}}()`.

`Array`s are sufficient for playing with a relatively small amount of data at the REPL. However, *TypedTables* will let you use any of a wide variety of array types, depending on your needs. A few examples include:

 * Typical `Array`-based columns represent continugous chunks of memory, and can be [memory-mapped](https://docs.julialang.org/en/v1/stdlib/Mmap/index.html) from files on disk for a simple way of doing out-of-core analytics.

 * Acceleration indices can be attached to columns using the [AcceleratedArrays](https://github.com/andyferris/AcceleratedArrays.jl) package, speeding up searches and joins.

 * Some data can be stored in compressed form using [sparse arrays](https://docs.julialang.org/en/v1/stdlib/SparseArrays/index.html), [categorical arrays](http://juliadata.github.io/CategoricalArrays.jl/latest/using.html), and so-on. Ranges such as `1:length(table)` are a compact way of including things like the table's primary key/indices as an explicit column.

 * Columns could be stored and processed on a GPU with [GPU-backed array](https://github.com/JuliaGPU/GPUArrays.jl) using [CUDA](https://github.com/JuliaGPU/CuArrays.jl), [OpenCL](https://github.com/JuliaGPU/CLArrays.jl), [ArrayFire](https://github.com/JuliaComputing/ArrayFire.jl), etc.

 * Columns might be distributed and processed in parallel over multiple machines with [DistributedArrays](https://github.com/JuliaParallel/DistributedArrays.jl) or between multiple processes with [`SharedArrays`](https://docs.julialang.org/en/v1/stdlib/SharedArrays/index.html).

 * In extreme cases, tables with a small, fixed number of rows might be most efficient represented with a [statically sized array](https://github.com/JuliaArrays/StaticArrays.jl).

In each case, the user will be able to use much the same interface (and code) to perform their transformations. In the background, Julia's compiler will create specialized, performant machine code, for whichever backing array you choose. You may be able to scale your calculations from rapid experimentation to large-scale production via a few simple changes to your array types.
