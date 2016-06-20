@testset "Row" begin

@testset "Constructors and macros" begin
    @test @inferred(Row{(:A,)}((1,))) == Row{(:A,), Tuple{Int64}}((1,))

    @test @Row(A=1, B=2.0) == Row{(:A,:B), Tuple{Int,Float64}}((1,2.0))
    @test (@Row A=1 B=2.0) == Row{(:A,:B), Tuple{Int,Float64}}((1,2.0))
    @test @Row(A::Int=1, B::Float64=2.0) == Row{(:A,:B), Tuple{Int,Float64}}((1,2.0))
    @test (@Row A::Int=1 B::Float64=2.0) == Row{(:A,:B), Tuple{Int,Float64}}((1,2.0))
end

@testset "Introspection" begin
    r = Row{(:A,:B)}((1,2.0))
    @test names(r) == (:A,:B)
    @test names(Row{(:A,:B)}) == (:A,:B)
    @test names(typeof(r)) == (:A,:B)
    @test eltypes(r) == Tuple{Int64,Float64}
    @test eltypes(typeof(r)) == Tuple{Int64,Float64}
    @test length(r) == 1
    @test endof(@Row(A::Int64=1, B::Float64=2.0)) == 1
    @test ncol(r) == 2
    @test ncol(Row{(:A,:B)}) == 2
    @test ncol(typeof(r)) == 2
    @test nrow(r) == 1

    @test (show(@Row(A::Int64=1, B::Float64=2.0));println();true)

    @test names(@inferred(rename(r, Val{(:A_new, :B_new)}))) == (:A_new, :B_new)
    @test names(@inferred(rename(r, Val{:A}, Val{:A_new}))) == (:A_new, :B)

    @test @Row(A::Int64=1, B::Float64=2.0) == @Row(A::Int64=1, B::Float64=2.0)
    @test @Row(A::Int64=1, B::Float64=2.0) == @Row(B::Float64=2.0, A::Int64=1)
    @test @Row(A::Int64=1, B::Float64=2.0) != @Row(B::Float64=2.0, A::Int64=3)
end

@testset "Accessing and iterating" begin
    r = Row{(:A,:B)}((1, 2.0))
    @test copy(r) == r

    @test r[] == r
    @test r[1] == r
    @test r[:] == r

    @test r[Val{:A}] == 1
    @test r[Val{(:A,:B)}] == r
    @test r[Val{(:B,:A)}] == Row{(:B,:A)}((2.0, 1))

    @test permutecols(r, Val{(:B,:A)}) == Row{(:B,:A)}((2.0, 1))
end


@testset "Composing and Concatenating" begin
    cell_a = @Cell(A::Int64=1)
    cell_b = @Cell(B::Float64=2.0)
    cell_c = @Cell(C::Bool=true)
    row_a = @Row(A::Int64=1)
    row_b = @Row(B::Float64=2.0)

    @test @inferred(hcat(cell_a)) == Row{(:A,),Tuple{Int64}}((1,))
    @test @inferred(hcat(row_a)) == Row{(:A,),Tuple{Int64}}((1,))

    @test @inferred(hcat(cell_a, cell_b)) == Row{(:A,:B),Tuple{Int64,Float64}}((1,2.0))
    @test @inferred(hcat(cell_a, row_b)) == Row{(:A,:B),Tuple{Int64,Float64}}((1,2.0))
    @test @inferred(hcat(row_a, cell_b)) == Row{(:A,:B),Tuple{Int64,Float64}}((1,2.0))
    @test @inferred(hcat(row_a, row_b)) == Row{(:A,:B),Tuple{Int64,Float64}}((1,2.0))

    @test @inferred(hcat(cell_a, cell_b, cell_c)) == Row{(:A,:B,:C),Tuple{Int64,Float64,Bool}}((1,2.0,true))
end

end
