@testset "Cell" begin

a = Field{:A,Int64}()
b = Field{:B,Float64}()
a_new = Field{:A_new,Int64}()

@testset "Constructors and macros" begin
    @test (@cell A::Int64 = 1) == a(1)
    @test (@cell a = 1) == a(1)
    @test @cell(B::Float64 = 2.0) == Cell(b,2.0)
    @test @cell(b = 2.0) == Cell(b,2.0)
    @test Cell(Field{:A,Int64}(),1) == Cell{Field{:A,Int64}(),Int64}(1)
    @test a(1)  == Cell{Field{:A,Int64}(),Int64}(1)
end

c1 = @cell A::Int64 = 1
c2 = @cell(A::Int64 = 2)
c3 = @cell(A::Int64 = 3)

@testset "Introspection" begin
    @test name(c1) == :A
    @test name(typeof(c1)) == :A
    @test eltype(c1) == Int64
    @test eltype(typeof(c1)) == Int64
    @test show(c1) == nothing
    println()
    @test length(c1) == 1
    @test length(typeof(c1)) == 1

    @test rename(c1, a_new) == @cell(a_new = 1)
end

@testset "Accessing and interating" begin
    @test copy(c1) == deepcopy(c1)
    @test c1[1] == c1
    @test c1[a] == 1
    @test first(c1) == c1
    @test endof(c1) == 1
end

end
