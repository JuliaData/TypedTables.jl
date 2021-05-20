@testset "Table" begin

    @testset "Selecting and dropping" begin
        table = Table(a = [1,2,3], b = ["1","2","3"], c = [1.0, 2.0, 3.0])
        @test table isa Table
        @test select(table, :b) == Table(b = table.b)
        @test select(table, :c, :b, :a) == Table(c = table.c, b = table.b, a = table.a)

        @test dropcolumns(table, :b) == Table(a = table.a, c = table.c)
        @test dropcolumns(table) == table

        @test_throws Exception select(table)
        @test_throws Exception select(table, :not_there)
        @test_throws Exception select(table, :a, :a)    
    end

    t = @inferred(Table(a = [1, 2, 3], b = [2.0, 4.0, 6.0]))::Table

    @test Table(t) == t
    @test Table(t; c = [true,false,true]) == Table(a = [1,2,3], b = [2.0,4.0,6.0], c = [true,false,true])
    @test Table(t, Table(c = [true,false,true])) == Table(a = [1,2,3], b = [2.0,4.0,6.0], c = [true,false,true])
    @test Table(t; b = nothing) == Table(a = [1,2,3])

    @test columnnames(t) == (:a, :b)
    @test propertynames(t) == (:a, :b)
    @test columns(t) == (a = [1,2,3], b = [2.0, 4.0, 6.0])
    @test rows(t) === t
    @test Tables.istable(t) === true
    @test Tables.rowaccess(t) === true
    @test Tables.columnaccess(t) === true
    @test Tables.schema(t) == Tables.Schema(NamedTuple{(:a,:b),Tuple{Int,Float64}})
    @test @inferred(Tables.materializer(t)(map(x -> 2*x, Tables.columns(t)))) isa Table
    @test Tables.materializer(t)(map(x -> 2*x, Tables.columns(t))) == Table(a = [2,4,6], b = [4.0,8.0,12.0])

    @test t.a == [1,2,3]
    @test axes(t) === (Base.OneTo(3),)
    @test size(t) === (3,)
    @test length(t) === 3
    @test @inferred(t[2]) === (a = 2, b = 4.0)
    @test @inferred(t[1:2])::Table == Table(a = [1,2], b = [2.0,4.0])
    @test @inferred(t[:])::Table == t
    @test @inferred(view(t, 1:2))::Table == Table(a = [1,2], b = [2.0,4.0])
    @test @inferred(view(t, :))::Table == t
    @test_throws BoundsError t[4]

    @test similar(t) isa typeof(t)
    @test axes(similar(t)) === axes(t)

    @test @inferred(vcat(t))::Table == t
    @test @inferred(vcat(t, t))::Table == Table(a = [1,2,3,1,2,3], b = [2.0, 4.0, 6.0, 2.0, 4.0, 6.0])
    @test @inferred(vcat(t, t, t))::Table == Table(a = [1,2,3,1,2,3,1,2,3], b = [2.0, 4.0, 6.0, 2.0, 4.0, 6.0, 2.0, 4.0, 6.0])

    @test @inferred(hcat(t))::Table == Table(a = hcat([1; 2; 3]), b = hcat([2.0; 4.0; 6.0]))
    @test @inferred(hcat(t, t))::Table == Table(a = [1 1;2 2;3 3], b = [2.0 2.0; 4.0 4.0; 6.0 6.0])
    @test @inferred(hcat(t, t, t))::Table == Table(a = [1 1 1;2 2 2;3 3 3], b = [2.0 2.0 2.0; 4.0 4.0 4.0; 6.0 6.0 6.0])

    @test [t t; t t]::Table == Table(a = [1 1;2 2;3 3;1 1;2 2;3 3], b = [2.0 2.0; 4.0 4.0; 6.0 6.0; 2.0 2.0; 4.0 4.0; 6.0 6.0])
    @test @inferred(vec(t))::Table == t

    io = IOBuffer()
    show(io, t)
    str = String(take!(io))
    @test str == """
        Table with 2 columns and 3 rows:
             a  b
           ┌───────
         1 │ 1  2.0
         2 │ 2  4.0
         3 │ 3  6.0"""

    @test @inferred(TypedTables.getproperties(:b, :a)(t))::Table == Table(b = [2.0, 4.0, 6.0], a = [1, 2, 3])

    @test t == t
    @test isequal(t, t)
    @test !isless(t, t)

    t2 = empty(t)
    @test t2 isa typeof(t)
    @test isempty(t2)

    t3 = copy(t)
    @test t3 isa typeof(t)
    @test t3 == t
    @test @inferred(t3[1:2])::Table == Table(a = [1,2], b = [2.0,4.0])
    t3[3] = (a = 4, b = 8.0)
    @test t3 == Table(a = [1,2,4], b = [2.0, 4.0, 8.0])
    t3[1:2] .= Ref((a = 0, b = 0.0))
    @test t3 == Table(a = [0,0,4], b = [0.0, 0.0, 8.0])
    t3[1:2] = Table(a = [2,3], b = [4.0, 6.0])
    @test t3 == Table(a = [2,3,4], b = [4.0, 6.0, 8.0])
    v3 = view(t3, :)
    v3[3] = (a = 5, b = 10.0)
    @test t3 == Table(a = [2,3,5], b = [4.0, 6.0, 10.0])
    
    empty!(t3)
    @test isempty(t3)

    push!(t3, (a=10, b=0.0))
    @test t3 == Table(a = [10], b = [0.0])

    pushfirst!(t3, (a=-10, b=-10.0))
    @test t3 == Table(a = [-10, 10], b = [-10.0, 0.0])

    insert!(t3, 2, (a=5,b=5.0))
    @test t3 == Table(a = [-10, 5, 10], b = [-10.0, 5.0, 0.0])

    @test splice!(t3, 2:1) == empty(t)
    @test t3 == Table(a = [-10, 5, 10], b = [-10.0, 5.0, 0.0])
    @test splice!(t3, 2:1, (a=1, b=1.0)) == empty(t)
    @test t3 == Table(a = [-10, 1, 5, 10], b = [-10.0, 1.0, 5.0, 0.0])
    @test splice!(t3, 3:2, Table(a=[2], b=[2.0])) == empty(t)
    @test t3 == Table(a = [-10, 1, 2, 5, 10], b = [-10.0, 1.0, 2.0, 5.0, 0.0])
    @test splice!(t3, 2) === (a = 1, b = 1.0)
    @test t3 == Table(a = [-10, 2, 5, 10], b = [-10.0, 2.0, 5.0, 0.0])
    @test splice!(t3, 2, (a = 3, b = 3.0)) === (a = 2, b = 2.0)
    @test t3 == Table(a = [-10, 3, 5, 10], b = [-10.0, 3.0, 5.0, 0.0])
    @test splice!(t3, 2, Table(a = [4], b = [4.0])) === (a = 3, b = 3.0)
    @test t3 == Table(a = [-10, 4, 5, 10], b = [-10.0, 4.0, 5.0, 0.0])

    @test pop!(t3) === (a = 10, b = 0.0)
    @test t3 == Table(a = [-10, 4, 5], b = [-10.0, 4.0, 5.0])

    @test popfirst!(t3) === (a = -10, b = -10.0)
    @test t3 == Table(a = [4, 5], b = [4.0, 5.0])

    append!(t3, Table(a = [6], b = [6.0]))
    @test t3 == Table(a = [4,5,6], b = [4.0, 5.0, 6.0])

    prepend!(t3, Table(a = [3], b = [3.0]))
    @test t3 == Table(a = [3,4,5,6], b = [3.0, 4.0, 5.0, 6.0])

    deleteat!(t3, 4)
    @test t3 == Table(a = [3,4,5], b = [3.0, 4.0, 5.0])

    @test length(resize!(Table(a=[]), 100)) == 100

    @test sort(Table(a=collect(100:-1:1))) == Table(a=1:100)

    @testset "Merging Tables" begin
        t1 = Table(a = [1,2,3],)
        t2 = Table(b = [2.0, 4.0, 6.0],)
        t3 = Table(a = [1,2,3], b = [2.0, 4.0, 6.0])

        @test @inferred(map(merge, t1, t2))::Table == t3
        @test @inferred(mapview(merge, t1, t2))::Table == t3
        @test @inferred(broadcast(merge, t1, t2))::Table == t3
    end

    @testset "GetProperty on Tables" begin
        t = Table(a = [1,2,3], b = [2.0, 4.0, 6.0], c = [true, false, true])

        @test @inferred(map(getproperty(:a), t))::Vector == [1,2,3]
        @test @inferred(mapview(getproperty(:a), t))::Vector == [1,2,3]
        @test @inferred(broadcast(getproperty(:a), t))::Vector == [1,2,3]
        @test @inferred(mapreduce(getproperty(:a), +, t)) === 6
        @test @inferred(filter(getproperty(:c), t))::Table == Table(a = [1,3], b = [2.0, 6.0], c = [true, true])
        @test @inferred(findall(getproperty(:c), t))::Vector{Int} == [1, 3]

        @test @inferred(map(TypedTables.getproperties(:a), t))::Table == Table(a = [1,2,3])
        @test @inferred(mapview(TypedTables.getproperties(:a), t))::Table == Table(a = [1,2,3])
        @test @inferred(broadcast(TypedTables.getproperties(:a), t))::Table == Table(a = [1,2,3])
        @test @inferred(mapreduce(TypedTables.getproperties(:a), (acc, row) -> acc + row.a, t; init = 0)) === 6
    end

    @testset "@Select and @Compute on Tables" begin
        t = Table(a = [1,2,3], b = [2.0, 4.0, 6.0], c = [true, false, true])

        c = @Compute(2*$a)
        @test @inferred(c(t))::Vector == [2, 4, 6] # (Works because 2 * vector works)
        @test @inferred(map(c, t))::Vector == [2, 4, 6]
        @test @inferred(mapview(c, t))::MappedArray == [2, 4, 6]
        @test @inferred(broadcast(c, t))::Vector == [2, 4, 6]
        @test @inferred(mapreduce(c, +, t)) === 12

        c2 = @Compute($b > 3.0)
        @test @inferred(filter(c2, t))::Table == Table(a = [2,3], b = [4.0,6.0], c = [false,true])
        @test @inferred(findall(c2, t))::Vector{Int} == [2, 3]

        s = @Select(sum = $a + $b)
        @test @inferred(s(t))::Table == Table(sum = [3.0, 6.0, 9.0]) # (Works because vector + vector works)
        @test @inferred(map(s, t))::Table == Table(sum = [3.0, 6.0, 9.0])
        @test @inferred(mapview(s, t))::Table == Table(sum = [3.0, 6.0, 9.0])
        @test @inferred(broadcast(s, t))::Table == Table(sum = [3.0, 6.0, 9.0])
        @test @inferred(mapreduce(s, (acc, row) -> acc + row.sum, t; init = 0.0)) === 18.0
    end

    @testset "missing in Tables" begin
        t = Table(a = [1, 2, 3], b = [2.0, 4.0, missing])

        @test t[1]::eltype(t) == (a = 1, b = 2.0)
        @test isequal(t[3]::eltype(t), (a = 3, b = missing))

        @test (t == t) === missing
        @test isequal(t, t)
        @test !isless(t, t)
    end

    @testset "Tables.jl" begin
        t = Table(a = [1, 2, 3], b = [2.0, 4.0, missing])
        @test isequal(t |> columntable, getfield(t, :data))
        r = t |> rowtable
        @test length(r) == 3
        for (a, b) in zip(t, r)
            @test isequal(a, b)
        end
        @test isequal(Table(t |> columntable), t)
        @test isequal(Table(t |> rowtable), t)
    end

    @testset "group" begin
        t = Table(a = [1,2,1], b = [2.0, 4.0, 6.0])
        out = group(getproperty(:a), t)
        @test typeof(out) <: SplitApplyCombine.AbstractDictionary{Int, <:Table}
        @test out == SplitApplyCombine.dictionary([
            1 => Table(a=[1, 1], b=[2.0, 6.0]),
            2 => Table(a=[2],    b=[4.0])
        ])
    end

    @testset "innerjoin" begin
        customers = Table(id = 1:3, name = ["Alice", "Bob", "Charlie"], address = ["12 Beach Street", "163 Moon Road", "6 George Street"])
        orders = Table(customer_id = [2, 2, 3, 3], items = ["Socks", "Tie", "Shirt", "Underwear"])

        t = innerjoin(getproperty(:id), getproperty(:customer_id), customers, orders)

        @test t isa Table
        @test t == Table(id = [2, 2, 3, 3],
                         name = ["Bob", "Bob", "Charlie", "Charlie"],
                         address = ["163 Moon Road", "163 Moon Road", "6 George Street", "6 George Street"],
                         customer_id = [2, 2, 3, 3],
                         items = ["Socks", "Tie", "Shirt", "Underwear"])

        # Issue #34
        orders2 = Table(customer_id = [2, 2, 3, 3], items = ["Socks", "Tie", "Shirt", missing])
        t2 = innerjoin(getproperty(:id), getproperty(:customer_id), customers, orders2)
        @test t2 isa Table
        @test isequal(t2, Table(id = [2, 2, 3, 3],
                          name = ["Bob", "Bob", "Charlie", "Charlie"],
                          address = ["163 Moon Road", "163 Moon Road", "6 George Street", "6 George Street"],
                          customer_id = [2, 2, 3, 3],
                          items = ["Socks", "Tie", "Shirt", missing]))
    end

    @testset "adapt" begin
        tbl = Table(a = randn(Float32, 10^2), b = rand(Float64, 10^2), c = rand(1:100, 10^2))
        @test typeof(@inferred adapt(TestArrayConverter(), tbl)) == typeof(tbl)
        adapted_tbl = adapt(TestArrayConverter(), tbl)
        @test propertynames(adapted_tbl) == propertynames(tbl)
        @test adapted_tbl == tbl
    end
end
