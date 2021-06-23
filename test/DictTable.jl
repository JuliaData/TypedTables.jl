@testset "DictTable" begin
    inds = Indices(['A', 'B', 'C'])
    col_a = Dictionary(inds, [1, 2, 3])
    col_b = Dictionary(inds, [2.0, 4.0, 6.0])
    col_c = Dictionary(inds, [true,false,true])

    t = @inferred(DictTable(a = col_a, b = col_b))::DictTable

    @test DictTable(t) == t
    @test DictTable(t; c = col_c) == DictTable(a = col_a, b = col_b, c = col_c)
    @test DictTable(t, DictTable(c = col_c)) == DictTable(a = col_a, b = col_b, c = col_c)
    @test DictTable(t; b = nothing) == DictTable(a = col_a)

    @test columnnames(t) == (:a, :b)
    @test propertynames(t) == (:a, :b)
    @test columns(t) == (a = col_a, b = col_b)
    @test rows(t) === t
    @test Tables.istable(t) === true
    @test Tables.rowaccess(t) === true
    @test Tables.columnaccess(t) === true
    @test Tables.schema(t) == Tables.Schema(NamedTuple{(:a,:b),Tuple{Int,Float64}})
    @test @inferred(Tables.materializer(t)(map(x -> 2 .* x, Tables.columns(t)))) isa DictTable
    @test Tables.materializer(t)(map(x -> 2 .* x, Tables.columns(t))) == DictTable(a = 2 .* col_a, b = 2 .* col_b)

    @test t.a == col_a
    @test keys(t) === inds
    @test length(t) === 3
    @test @inferred(t['B']) === (a = 2, b = 4.0)
    @test @inferred(getindices(t, keys(t)))::DictTable == t
    @test @inferred(getindices(t, Indices(['A', 'C'])))::DictTable == DictTable(a = Dictionary(['A', 'C'], [1, 3]), b = Dictionary(['A', 'C'], [2.0, 6.0]))
    @test @inferred(view(t, keys(t)))::DictTable == t
    @test @inferred(view(t, Indices(['A', 'C'])))::DictTable == DictTable(a = Dictionary(['A', 'C'], [1, 3]), b = Dictionary(['A', 'C'], [2.0, 6.0]))
    @test_throws IndexError t['D']

    @test similar(t) isa typeof(t)
    @test keys(similar(t)) === keys(t)

    io = IOBuffer()
    show(io, MIME"text/plain"(), t)
    str = String(take!(io))
    @test str == """
        DictTable with 2 columns and 3 rows:
             a  b
           ┌───────
         A │ 1  2.0
         B │ 2  4.0
         C │ 3  6.0"""

    @test @inferred(TypedTables.getproperties((:b, :a))(t))::DictTable == DictTable(b = col_b, a = col_a)

    @test t == t
    @test isequal(t, t)
    @test !isless(t, t)

    t2 = empty(t)
    @test t2 isa typeof(t)
    @test isempty(t2)

    t3 = copy(t)
    @test t3 isa typeof(t)
    @test t3 == t
    t3['C'] = (a = 4, b = 8.0)
    @test t3['C'] === (a = 4, b = 8.0)
    v3 = view(t3, keys(t3))
    v3['C'] = (a = 5, b = 10.0)
    @test t3['C'] === (a = 5, b = 10.0)
    
    empty!(t3)
    @test isempty(t3)

    insert!(t3, 'D', (a = 10, b = 0.0))
    @test length(t3) === 1
    @test t3['D'] === (a = 10, b = 0.0)
    delete!(t3, 'D')
    @test isempty(t3)

    @testset "Merging Tables" begin
        i = Indices(['A', 'B', 'C'])
        t1 = DictTable(a = Dictionary(i, [1,2,3]),)
        t2 = DictTable(b = Dictionary(i, [2.0, 4.0, 6.0]),)
        t3 = DictTable(a = Dictionary(i, [1,2,3]), b = Dictionary(i, [2.0, 4.0, 6.0]))

        @test @inferred(map(merge, t1, t2))::DictTable == t3
        @test @inferred(mapview(merge, t1, t2))::DictTable == t3
        @test @inferred(broadcast(merge, t1, t2))::DictTable == t3
    end

    @testset "GetProperty on Tables" begin
        i = Indices(['A', 'B', 'C'])
        t = DictTable(a = Dictionary(i, [1,2,3]), b = Dictionary(i, [2.0, 4.0, 6.0]), c = Dictionary(i, [true, false, true]))

        @test @inferred(map(getproperty(:a), t))::Dictionary == Dictionary(i, [1,2,3])
        @test @inferred(mapview(getproperty(:a), t))::Dictionary == Dictionary(i, [1,2,3])
        @test @inferred(broadcast(getproperty(:a), t))::Dictionary == Dictionary(i, [1,2,3])
        @test @inferred(mapreduce(getproperty(:a), +, t)) === 6
        i2 = Indices(['A', 'C'])
        @test @inferred(filter(getproperty(:c), t))::DictTable == DictTable(a = Dictionary(i2, [1,3]), b = Dictionary(i2, [2.0, 6.0]), c = Dictionary(i2, [true, true]))
        @test @inferred(findall(getproperty(:c), t))::Indices{Char} == i2

        @test @inferred(map(getproperties((:a,)), t))::DictTable == DictTable(a = Dictionary(i, [1,2,3]))
        @test @inferred(mapview(getproperties((:a,)), t))::DictTable == DictTable(a = Dictionary(i, [1,2,3]))
        @test @inferred(broadcast(getproperties((:a,)), t))::DictTable == DictTable(a = Dictionary(i, [1,2,3]))
        @test @inferred(mapreduce(getproperties((:a,)), (acc, row) -> acc + row.a, t; init = 0)) === 6
    end

    # @testset "@Select and @Compute on Tables" begin
    #     t = Table(a = [1,2,3], b = [2.0, 4.0, 6.0], c = [true, false, true])

    #     c = @Compute(2*$a)
    #     @test @inferred(c(t))::Vector == [2, 4, 6] # (Works because 2 * vector works)
    #     @test @inferred(map(c, t))::Vector == [2, 4, 6]
    #     @test @inferred(mapview(c, t))::MappedArray == [2, 4, 6]
    #     @test @inferred(broadcast(c, t))::Vector == [2, 4, 6]
    #     @test @inferred(mapreduce(c, +, t)) === 12

    #     c2 = @Compute($b > 3.0)
    #     @test @inferred(filter(c2, t))::Table == Table(a = [2,3], b = [4.0,6.0], c = [false,true])
    #     @test @inferred(findall(c2, t))::Vector{Int} == [2, 3]

    #     s = @Select(sum = $a + $b)
    #     @test @inferred(s(t))::Table == Table(sum = [3.0, 6.0, 9.0]) # (Works because vector + vector works)
    #     @test @inferred(map(s, t))::Table == Table(sum = [3.0, 6.0, 9.0])
    #     @test @inferred(mapview(s, t))::Table == Table(sum = [3.0, 6.0, 9.0])
    #     @test @inferred(broadcast(s, t))::Table == Table(sum = [3.0, 6.0, 9.0])
    #     @test @inferred(mapreduce(s, (acc, row) -> acc + row.sum, t; init = 0.0)) === 18.0
    # end

    # @testset "missing in Tables" begin
    #     t = Table(a = [1, 2, 3], b = [2.0, 4.0, missing])

    #     @test t[1]::eltype(t) == (a = 1, b = 2.0)
    #     @test isequal(t[3]::eltype(t), (a = 3, b = missing))

    #     @test (t == t) === missing
    #     @test isequal(t, t)
    #     @test !isless(t, t)
    # end

    # @testset "Tables.jl" begin
    #     t = Table(a = [1, 2, 3], b = [2.0, 4.0, missing])
    #     @test isequal(t |> columntable, getfield(t, :data))
    #     r = t |> rowtable
    #     @test length(r) == 3
    #     for (a, b) in zip(t, r)
    #         @test isequal(a, b)
    #     end
    #     @test isequal(Table(t |> columntable), t)
    #     @test isequal(Table(t |> rowtable), t)
    # end

    # @testset "group" begin
    #     t = Table(a = [1,2,1], b = [2.0, 4.0, 6.0])
    #     out = group(getproperty(:a), t)
    #     @test typeof(out) <: Dict{Int, <:Table}
    #     @test out == Dict(1 => Table(a=[1, 1], b=[2.0, 6.0]),
    #                       2 => Table(a=[2],    b=[4.0]))
    # end

    # @testset "innerjoin" begin
    #     customers = Table(id = 1:3, name = ["Alice", "Bob", "Charlie"], address = ["12 Beach Street", "163 Moon Road", "6 George Street"])
    #     orders = Table(customer_id = [2, 2, 3, 3], items = ["Socks", "Tie", "Shirt", "Underwear"])

    #     t = innerjoin(getproperty(:id), getproperty(:customer_id), customers, orders)

    #     @test t isa Table
    #     @test t == Table(id = [2, 2, 3, 3],
    #                      name = ["Bob", "Bob", "Charlie", "Charlie"],
    #                      address = ["163 Moon Road", "163 Moon Road", "6 George Street", "6 George Street"],
    #                      customer_id = [2, 2, 3, 3],
    #                      items = ["Socks", "Tie", "Shirt", "Underwear"])

    #     # Issue #34
    #     orders2 = Table(customer_id = [2, 2, 3, 3], items = ["Socks", "Tie", "Shirt", missing])
    #     t2 = innerjoin(getproperty(:id), getproperty(:customer_id), customers, orders2)
    #     @test t2 isa Table
    #     @test isequal(t2, Table(id = [2, 2, 3, 3],
    #                       name = ["Bob", "Bob", "Charlie", "Charlie"],
    #                       address = ["163 Moon Road", "163 Moon Road", "6 George Street", "6 George Street"],
    #                       customer_id = [2, 2, 3, 3],
    #                       items = ["Socks", "Tie", "Shirt", missing]))
    # end
end
