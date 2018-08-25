@testset "FlexTable" begin
    t = @inferred(FlexTable(a = [1,2,3], b = [2.0, 4.0, 6.0]))::FlexTable

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

    @test @inferred(vcat(t, t))::FlexTable{1} == FlexTable(a = [1,2,3,1,2,3], b = [2.0, 4.0, 6.0, 2.0, 4.0, 6.0])
    @test @inferred(hcat(t, t))::FlexTable{2} == FlexTable(a = [1 1;2 2;3 3], b = [2.0 2.0; 4.0 4.0; 6.0 6.0])
    # TODO hvcat

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
    @test splice!(t3, 3:2, (a=[2], b=[2.0])) == empty(t)
    @test t3 == FlexTable(a = [-10, 1, 2, 5, 10], b = [-10.0, 1.0, 2.0, 5.0, 0.0])
    @test splice!(t3, 2) === (a = 1, b = 1.0)
    @test t3 == FlexTable(a = [-10, 2, 5, 10], b = [-10.0, 2.0, 5.0, 0.0])
    @test splice!(t3, 2, (a = 3, b = 3.0)) === (a = 2, b = 2.0)
    @test t3 == FlexTable(a = [-10, 3, 5, 10], b = [-10.0, 3.0, 5.0, 0.0])
    @test splice!(t3, 2, (a = [4], b = [4.0])) === (a = 3, b = 3.0)
    @test t3 == FlexTable(a = [-10, 4, 5, 10], b = [-10.0, 4.0, 5.0, 0.0])

    @test pop!(t3) === (a = 10, b = 0.0)
    @test t3 == FlexTable(a = [-10, 4, 5], b = [-10.0, 4.0, 5.0])

    @test popfirst!(t3) === (a = -10, b = -10.0)
    @test t3 == FlexTable(a = [4, 5], b = [4.0, 5.0])

    append!(t3, FlexTable(a = [6], b = [6.0]))
    @test t3 == FlexTable(a = [4,5,6], b = [4.0, 5.0, 6.0])

    prepend!(t3, FlexTable(a = [3], b = [3.0]))
    @test t3 == FlexTable(a = [3,4,5,6], b = [3.0, 4.0, 5.0, 6.0])

    @testset "Merging FlexTables" begin
        t1 = FlexTable(a = [1,2,3],)
        t2 = FlexTable(b = [2.0, 4.0, 6.0],)
        t3 = FlexTable(a = [1,2,3], b = [2.0, 4.0, 6.0])

        @test @inferred(map(merge, t1, t2))::FlexTable == t3
        @test @inferred(mapview(merge, t1, t2))::FlexTable == t3
        @test @inferred(broadcast(merge, t1, t2))::FlexTable == t3
    end

    @testset "GetProperty on FlexTables" begin
        t = FlexTable(a = [1,2,3], b = [2.0, 4.0, 6.0])

        @test map(getproperty(:a), t)::Vector == [1,2,3]
        @test mapview(getproperty(:a), t)::Vector == [1,2,3]
        @test broadcast(getproperty(:a), t)::Vector == [1,2,3]
    end

    # setproperty!
    t4 = FlexTable(a = [1,2,3])
    t4.b = [2.0, 4.0, 6.0]
    @test t4 == t
end