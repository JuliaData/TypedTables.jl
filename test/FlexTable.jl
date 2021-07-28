@testset "FlexTable" begin
    t = @inferred(FlexTable(a = [1,2,3], b = [2.0, 4.0, 6.0]))::FlexTable

    @test FlexTable(t; c = [true,false,true]) == Table(a = [1,2,3], b = [2.0,4.0,6.0], c = [true,false,true])
    @test FlexTable(t, Table(c = [true,false,true])) == Table(a = [1,2,3], b = [2.0,4.0,6.0], c = [true,false,true])
    @test FlexTable(t; b = nothing) == Table(a = [1,2,3])

    @test columnnames(t) == (:a, :b)
    @test propertynames(t) == (:a, :b)
    @test columns(t) == (a = [1,2,3], b = [2.0, 4.0, 6.0])
    @test rows(t)::Table == t
    @test Tables.istable(t) === true
    @test Tables.rowaccess(t) === true
    @test Tables.columnaccess(t) === true
    @test Tables.schema(t) == Tables.Schema(NamedTuple{(:a,:b),Tuple{Int,Float64}})
    @test @inferred(Tables.materializer(t)(map(x -> 2*x, Tables.columns(t)))) isa FlexTable
    @test Tables.materializer(t)(map(x -> 2*x, Tables.columns(t))) == Table(a = [2,4,6], b = [4.0,8.0,12.0])

    @test t.a == [1,2,3]
    @test axes(t) === (Base.OneTo(3),)
    @test size(t) === (3,)
    @test length(t) === 3
    @test t[2] === (a = 2, b = 4.0)
    @test @inferred(t[1:2])::FlexTable == FlexTable(a = [1,2], b = [2.0,4.0])
    @test @inferred(t[:])::FlexTable == t
    @test @inferred(view(t, 1:2))::FlexTable == FlexTable(a = [1,2], b = [2.0,4.0])
    @test @inferred(view(t, :))::FlexTable == t
    @test_throws BoundsError t[4]

    @test similar(t) isa typeof(t)
    @test axes(similar(t)) === axes(t)

    @test @inferred(vcat(t))::FlexTable{1} == t
    @test @inferred(vcat(t, t))::FlexTable{1} == FlexTable(a = [1,2,3,1,2,3], b = [2.0, 4.0, 6.0, 2.0, 4.0, 6.0])
    @test @inferred(vcat(t, t, t))::FlexTable{1} == FlexTable(a = [1,2,3,1,2,3,1,2,3], b = [2.0, 4.0, 6.0, 2.0, 4.0, 6.0, 2.0, 4.0, 6.0])

    @test @inferred(hcat(t))::FlexTable{2} == FlexTable(a = hcat([1; 2; 3]), b = hcat([2.0; 4.0; 6.0]))
    @test @inferred(hcat(t, t))::FlexTable{2} == FlexTable(a = [1 1;2 2;3 3], b = [2.0 2.0; 4.0 4.0; 6.0 6.0])
    @test @inferred(hcat(t, t, t))::FlexTable{2} == FlexTable(a = [1 1 1;2 2 2;3 3 3], b = [2.0 2.0 2.0; 4.0 4.0 4.0; 6.0 6.0 6.0])
    
    @test [t t; t t]::FlexTable{2} == FlexTable(a = [1 1;2 2;3 3;1 1;2 2;3 3], b = [2.0 2.0; 4.0 4.0; 6.0 6.0; 2.0 2.0; 4.0 4.0; 6.0 6.0])
    @test @inferred(vec(t))::FlexTable{1} == t

    io = IOBuffer()
    show(io, MIME"text/plain"(), t)
    str = String(take!(io))
    @test str == """
        FlexTable with 2 columns and 3 rows:
             a  b
           ┌───────
         1 │ 1  2.0
         2 │ 2  4.0
         3 │ 3  6.0"""

    @test @inferred((x -> getproperties(x, (:b, :a)))(t))::FlexTable == FlexTable(b = [2.0, 4.0, 6.0], a = [1, 2, 3])

    @test t == t
    @test t == rows(t)
    @test rows(t) == t
    @test isequal(t, t)
    @test isequal(t, rows(t))
    @test isequal(rows(t), t)
    @test !isless(t, t)
    @test !isless(t, rows(t))
    @test !isless(rows(t), t)
    @test hash(t) == hash(rows(t))

    t2 = empty(t)
    @test t2 isa typeof(t)
    @test isempty(t2)

    t3 = copy(t)
    @test t3 isa typeof(t)
    @test t3 == t
    @test @inferred(t3[1:2])::FlexTable == FlexTable(a = [1,2], b = [2.0,4.0])
    t3[3] = (a = 4, b = 8.0)
    @test t3 == FlexTable(a = [1,2,4], b = [2.0, 4.0, 8.0])
    t3[1:2] .= Ref((a = 0, b = 0.0))
    @test t3 == FlexTable(a = [0,0,4], b = [0.0, 0.0, 8.0])
    t3[1:2] = FlexTable(a = [2,3], b = [4.0, 6.0])
    @test t3 == FlexTable(a = [2,3,4], b = [4.0, 6.0, 8.0])
    v3 = view(t3, :)
    v3[3] = (a = 5, b = 10.0)
    @test t3 == FlexTable(a = [2,3,5], b = [4.0, 6.0, 10.0])
    
    empty!(t3)
    @test isempty(t3)

    push!(t3, (a=10, b=0.0))
    @test t3 == FlexTable(a = [10], b = [0.0])

    pushfirst!(t3, (a=-10, b=-10.0))
    @test t3 == FlexTable(a = [-10, 10], b = [-10.0, 0.0])

    insert!(t3, 2, (a=5,b=5.0))
    @test t3 == FlexTable(a = [-10, 5, 10], b = [-10.0, 5.0, 0.0])

    @test splice!(t3, 2:1) == empty(t)
    @test t3 == FlexTable(a = [-10, 5, 10], b = [-10.0, 5.0, 0.0])
    @test splice!(t3, 2:1, (a=1, b=1.0)) == empty(t)
    @test t3 == FlexTable(a = [-10, 1, 5, 10], b = [-10.0, 1.0, 5.0, 0.0])
    @test splice!(t3, 3:2, Table(a=[2], b=[2.0])) == empty(t)
    @test t3 == FlexTable(a = [-10, 1, 2, 5, 10], b = [-10.0, 1.0, 2.0, 5.0, 0.0])
    @test splice!(t3, 2) === (a = 1, b = 1.0)
    @test t3 == FlexTable(a = [-10, 2, 5, 10], b = [-10.0, 2.0, 5.0, 0.0])
    @test splice!(t3, 2, (a = 3, b = 3.0)) === (a = 2, b = 2.0)
    @test t3 == FlexTable(a = [-10, 3, 5, 10], b = [-10.0, 3.0, 5.0, 0.0])
    @test splice!(t3, 2, Table(a = [4], b = [4.0])) === (a = 3, b = 3.0)
    @test t3 == FlexTable(a = [-10, 4, 5, 10], b = [-10.0, 4.0, 5.0, 0.0])

    @test pop!(t3) === (a = 10, b = 0.0)
    @test t3 == FlexTable(a = [-10, 4, 5], b = [-10.0, 4.0, 5.0])

    @test popfirst!(t3) === (a = -10, b = -10.0)
    @test t3 == FlexTable(a = [4, 5], b = [4.0, 5.0])

    append!(t3, FlexTable(a = [6], b = [6.0]))
    @test t3 == FlexTable(a = [4,5,6], b = [4.0, 5.0, 6.0])

    prepend!(t3, FlexTable(a = [3], b = [3.0]))
    @test t3 == FlexTable(a = [3,4,5,6], b = [3.0, 4.0, 5.0, 6.0])

    deleteat!(t3, 4)
    @test t3 == Table(a = [3,4,5], b = [3.0, 4.0, 5.0])

    @test length(resize!(FlexTable(a=[]), 100)) == 100

    @test sort(FlexTable(a=collect(100:-1:1))) == FlexTable(a=1:100)

    # setproperty!
    t4 = FlexTable(a = [1,2,3])
    t4.b = [2.0, 4.0, 6.0]
    @test t4 == t
    t4.b = nothing
    @test t4 == FlexTable(a = [1,2,3])

    @testset "Merging FlexTables" begin
        t1 = FlexTable(a = [1,2,3],)
        t2 = FlexTable(b = [2.0, 4.0, 6.0],)
        t3 = FlexTable(a = [1,2,3], b = [2.0, 4.0, 6.0])

        @test (map(merge, t1, t2))::FlexTable == t3
        @test (mapview(merge, t1, t2))::FlexTable == t3
        @test (broadcast(merge, t1, t2)) == t3
    end

    @testset "GetProperty on FlexTables" begin
        t = FlexTable(a = [1, 2, 3], b = [2.0, 4.0, 6.0], c = [true, false, true])

        @test map(getproperty(:a), t)::Vector == [1,2,3]
        @test mapview(getproperty(:a), t)::Vector == [1,2,3]
        @test broadcast(getproperty(:a), t)::Vector == [1,2,3]
        @test mapreduce(getproperty(:a), +, t) === 6
        @test filter(getproperty(:c), t)::FlexTable == FlexTable(a = [1,3], b = [2.0, 6.0], c = [true, true])
        @test findall(getproperty(:c), t)::Vector{Int} == [1, 3]

        @test map(getproperties((:a,)), t)::FlexTable == FlexTable(a = [1,2,3])
        @test mapview(getproperties((:a,)), t)::FlexTable == FlexTable(a = [1,2,3])
        @test broadcast(getproperties((:a,)), t) == FlexTable(a = [1,2,3])
        @test mapreduce(getproperties((:a,)), (acc, row) -> acc + row.a, t; init = 0) === 6
    end

    @testset "@Select and @Compute on FlexTables" begin
        t = FlexTable(a = [1, 2, 3], b = [2.0, 4.0, 6.0], c = [true, false, true])

        c = @Compute(2*$a)
        @test c(t)::Vector == [2, 4, 6] # (Works because 2 * vector works)
        @test map(c, t)::Vector == [2, 4, 6]
        @test mapview(c, t)::MappedArray == [2, 4, 6]
        @test broadcast(c, t)::Vector == [2, 4, 6]
        @test mapreduce(c, +, t) === 12

        c2 = @Compute($b > 3.0)
        @test filter(c2, t)::FlexTable == FlexTable(a = [2,3], b = [4.0,6.0], c = [false,true])
        @test findall(c2, t)::Vector{Int} == [2, 3]

        s = @Select(sum = $a + $b)
        @test s(t)::FlexTable == FlexTable(sum = [3.0, 6.0, 9.0]) # (Works because vector + vector works)
        @test map(s, t)::FlexTable == FlexTable(sum = [3.0, 6.0, 9.0])
        @test mapview(s, t)::FlexTable == FlexTable(sum = [3.0, 6.0, 9.0])
        @test broadcast(s, t) == FlexTable(sum = [3.0, 6.0, 9.0])
        @test mapreduce(s, (acc, row) -> acc + row.sum, t; init = 0.0) === 18.0
    end

    @testset "missing in FlexTables" begin
        t = FlexTable(a = [1, 2, 3], b = [2.0, 4.0, missing])

        @test t[1]::eltype(t) == (a = 1, b = 2.0)
        @test isequal(t[3]::eltype(t), (a = 3, b = missing))

        @test (t == t) === missing
        @test isequal(t, t)
        @test !isless(t, t)
    end

    @testset "Tables.jl" begin
        t = FlexTable(a = [1, 2, 3], b = [2.0, 4.0, missing])
        @test isequal(t |> columntable, getfield(t, :data))
        r = t |> rowtable
        @test length(r) == 3
        for (a, b) in zip(t, r)
            @test isequal(a, b)
        end
        @test isequal(FlexTable(t |> columntable), t)
        @test isequal(FlexTable(t |> rowtable), t)
    end

    @testset "group" begin
        t = FlexTable(a = [1, 2, 1], b = [2.0, 4.0, 6.0])
        out = group(getproperty(:a), t)
        @test typeof(out) <: Dictionary{Int}
        @test out == dictionary([
            1 => FlexTable(a=[1, 1], b=[2.0, 6.0]),
            2 => FlexTable(a=[2],    b=[4.0])
        ])
    end

    @testset "innerjoin" begin
        customers = FlexTable(id = 1:3, name = ["Alice", "Bob", "Charlie"], address = ["12 Beach Street", "163 Moon Road", "6 George Street"])
        orders = FlexTable(customer_id = [2, 2, 3, 3], items = ["Socks", "Tie", "Shirt", "Underwear"])

        t = innerjoin(getproperty(:id), getproperty(:customer_id), customers, orders)

        @test t isa FlexTable
        @test t == FlexTable(id = [2, 2, 3, 3],
                             name = ["Bob", "Bob", "Charlie", "Charlie"],
                             address = ["163 Moon Road", "163 Moon Road", "6 George Street", "6 George Street"],
                             customer_id = [2, 2, 3, 3],
                             items = ["Socks", "Tie", "Shirt", "Underwear"])
    end

    @testset "adapt" begin
        tbl = FlexTable(a = randn(Float32, 10^2), b = rand(Float64, 10^2), c = rand(1:100, 10^2))
        @test typeof(@inferred adapt(TestArrayConverter(), tbl)) == typeof(tbl)
        adapted_tbl = adapt(TestArrayConverter(), tbl)
        @test propertynames(adapted_tbl) == propertynames(tbl)
        @test adapted_tbl == tbl
    end
end
