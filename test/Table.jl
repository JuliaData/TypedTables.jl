@testset "Table" begin
    t = @inferred(Table(a = [1,2,3], b = [2.0, 4.0, 6.0]))::Table

    @test Table(t) == t
    @test Table(t; c = [true,false,true]) == Table(a = [1,2,3], b = [2.0,4.0,6.0], c = [true,false,true])
    @test Table(t, Table(c = [true,false,true])) == Table(a = [1,2,3], b = [2.0,4.0,6.0], c = [true,false,true])
    @test Table(t; b = nothing) == Table(a = [1,2,3])

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

    @test @inferred(vcat(t, t))::Table == Table(a = [1,2,3,1,2,3], b = [2.0, 4.0, 6.0, 2.0, 4.0, 6.0])
    @test @inferred(hcat(t, t))::Table == Table(a = [1 1;2 2;3 3], b = [2.0 2.0; 4.0 4.0; 6.0 6.0])
    # TODO hvcat

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
    @test splice!(t3, 3:2, (a=[2], b=[2.0])) == empty(t)
    @test t3 == Table(a = [-10, 1, 2, 5, 10], b = [-10.0, 1.0, 2.0, 5.0, 0.0])
    @test splice!(t3, 2) === (a = 1, b = 1.0)
    @test t3 == Table(a = [-10, 2, 5, 10], b = [-10.0, 2.0, 5.0, 0.0])
    @test splice!(t3, 2, (a = 3, b = 3.0)) === (a = 2, b = 2.0)
    @test t3 == Table(a = [-10, 3, 5, 10], b = [-10.0, 3.0, 5.0, 0.0])
    @test splice!(t3, 2, (a = [4], b = [4.0])) === (a = 3, b = 3.0)
    @test t3 == Table(a = [-10, 4, 5, 10], b = [-10.0, 4.0, 5.0, 0.0])

    @test pop!(t3) === (a = 10, b = 0.0)
    @test t3 == Table(a = [-10, 4, 5], b = [-10.0, 4.0, 5.0])

    @test popfirst!(t3) === (a = -10, b = -10.0)
    @test t3 == Table(a = [4, 5], b = [4.0, 5.0])

    append!(t3, Table(a = [6], b = [6.0]))
    @test t3 == Table(a = [4,5,6], b = [4.0, 5.0, 6.0])

    prepend!(t3, Table(a = [3], b = [3.0]))
    @test t3 == Table(a = [3,4,5,6], b = [3.0, 4.0, 5.0, 6.0])

    @testset "Merging Tables" begin
        t1 = Table(a = [1,2,3],)
        t2 = Table(b = [2.0, 4.0, 6.0],)
        t3 = Table(a = [1,2,3], b = [2.0, 4.0, 6.0])

        @test @inferred(map(merge, t1, t2))::Table == t3
        @test @inferred(mapview(merge, t1, t2))::Table == t3
        @test @inferred(broadcast(merge, t1, t2))::Table == t3
    end

    @testset "GetProperty on Tables" begin
        t = Table(a = [1,2,3], b = [2.0, 4.0, 6.0])

        @test @inferred(map(getproperty(:a), t))::Vector == [1,2,3]
        @test @inferred(mapview(getproperty(:a), t))::Vector == [1,2,3]
        @test @inferred(broadcast(getproperty(:a), t))::Vector == [1,2,3]
    end

    @testset "missing in tables" begin
        t = Table(a = [1, 2, 3], b = [2.0, 4.0, missing])

        @test t[1]::eltype(t) == (a = 1, b = 2.0)
        @test isequal(t[3]::eltype(t), (a = 3, b = missing))
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
        @test typeof(out) <: Dict{Int, <:Table}
        @test out == Dict(1 => Table(a=[1, 1], b=[2.0, 6.0]),
                          2 => Table(a=[2],    b=[4.0]))
    end
end
