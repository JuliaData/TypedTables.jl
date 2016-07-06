@testset "@col" begin
    t = @Table(A=[1,2,3],B=[2.0,4.0,6.0])

    @test @col(t, A) == [1,2,3]
    @test @col(t, A, B) == t
end

@testset "@select" begin
    t = @Table(A=[1,2,3],B=[2.0,4.0,6.0])

    @test @select(t, A) == @Table(A=[1,2,3])
    @test @select(t, A, C = B) == @Table(A=[1,2,3],C=[2.0,4.0,6.0])
    @test @select(t, C = (A,B) -> A+B) == @Table(C=[3.0,6.0,9.0])
end

@testset "@filter etc" begin
    t = @Table(A=[1,2,3],B=[2.0,4.0,6.0])

    @test @filter(t, A -> A>1) == @Table(A=[2,3], B=[4.0,6.0])
    @test @filter(t, A -> A>1, B -> B < 4.5) == @Table(A=[2],B=[4.0])

    @test (t2 = copy(t); @filter!(t2, A -> A>1, B -> B < 4.5); t2 == @Table(A=[2],B=[4.0]))

    @test @filter_mask(t, A -> A>1, B -> B < 4.5) == [false,true,false]
end
