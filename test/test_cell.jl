@testset "Cell" begin

@testset "Constructors and macros" begin
    @test @inferred(Cell{:A}(1)) == Cell{:A, Int}(1)

    @test (@Cell A::Int64 = 1) == Cell{:A, Int}(1)
    @test (@Cell A = 1) == Cell{:A, Int}(1)
    @test @Cell(B::Float64 = 2.0) == Cell{:B, Float64}(2.0)
    @test @Cell(B = 2.0) == Cell{:B, Float64}(2.0)
end

@testset "Introspection" begin
    c1 = @Cell A::Int = 1


    @test name(c1) == :A
    @test name(typeof(c1)) == :A
    @test eltype(c1) == Int
    @test eltype(typeof(c1)) == Int
    @test show(c1) == nothing
    println()
    @test length(c1) == 1
    #@test length(typeof(c1)) == 1

    @test @inferred(rename(c1, Val{:A_new})) == @Cell(A_new = 1)
end

@testset "Accessing and interating" begin
    c1 = @Cell A::Int = 1

    @test copy(c1) == c1
    @test c1[] == c1.data
    @test c1[1] == c1.data
    @test c1[Val{:A}] == c1.data
    @test @inferred(first(c1)) == c1.data
    @test endof(c1) == c1.data
end

end
