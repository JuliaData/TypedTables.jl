@testset "Row" begin

@testset "Constructors and macros" begin
    @test @inferred(Row(Field{:A,Int64}(),(1,))) == Row{FieldIndex{(Field{:A,Int64}(),)}(),Tuple{Int64}}((1,))
    @test @inferred(Row(Field{:A,Int64}(),1)) == Row{FieldIndex{(Field{:A,Int64}(),)}(),Tuple{Int64}}((1,))
    @test @inferred(Row((Field{:A,Int64}(),Field{:B,Float64}()),(1,2.0))) == Row{FieldIndex{(Field{:A,Int64}(),Field{:B,Float64}())}(),Tuple{Int64,Float64}}((1,2.0))
    @test @inferred(Row(FieldIndex{(Field{:A,Int64}(),Field{:B,Float64}())}(),(1,2.0))) == Row{FieldIndex{(Field{:A,Int64}(),Field{:B,Float64}())}(),Tuple{Int64,Float64}}((1,2.0))

    @test @index(A::Int64,B::Float64)((1,2.0)) == Row{FieldIndex{(Field{:A,Int64}(),Field{:B,Float64}())}(),Tuple{Int64,Float64}}((1,2.0))

    @test @row(A::Int64=1, B::Float64=2.0) == Row{FieldIndex{(Field{:A,Int64}(),Field{:B,Float64}())}(),Tuple{Int64,Float64}}((1,2.0))
    @test (@row A::Int64=1 B::Float64=2.0)  == Row{FieldIndex{(Field{:A,Int64}(),Field{:B,Float64}())}(),Tuple{Int64,Float64}}((1,2.0))
end

@testset "Introspection" begin
    @test names(@row(A::Int64=1, B::Float64=2.0)) == (:A,:B)
    @test names(typeof(@row(A::Int64=1, B::Float64=2.0))) == (:A,:B)
    @test eltypes(@row(A::Int64=1, B::Float64=2.0)) == Tuple{Int64,Float64}
    @test eltypes(typeof(@row(A::Int64=1, B::Float64=2.0))) == Tuple{Int64,Float64}
    @test @inferred(index(Row{FieldIndex{(Field{:A,Int64}(),Field{:B,Float64}())}(),Tuple{Int64,Float64}}((1,2.0)))) == @index(A::Int64,B::Float64)
    @test @inferred(index(typeof(Row{FieldIndex{(Field{:A,Int64}(),Field{:B,Float64}())}(),Tuple{Int64,Float64}}((1,2.0))))) == @index(A::Int64,B::Float64)
    @test length(@row(A::Int64=1, B::Float64=2.0)) == 2
    @test length(typeof(@row(A::Int64=1, B::Float64=2.0))) == 2
    @test endof(@row(A::Int64=1, B::Float64=2.0)) == 2
    @test ncol(@row(A::Int64=1, B::Float64=2.0)) == 2
    @test ncol(typeof(@row(A::Int64=1, B::Float64=2.0))) == 2
    @test nrow(@row(A::Int64=1, B::Float64=2.0)) == 1
    @test nrow(typeof(@row(A::Int64=1, B::Float64=2.0))) == 1

    @test (show(@row(A::Int64=1, B::Float64=2.0));println();true)

    @test names(rename(@index(A::Int64,B::Float64),@field(A::Int64),@field(A_new::Int64))) == (:A_new,:B)
    @test names(rename(@index(A::Int64,B::Float64),@index(A::Int64),@index(A_new::Int64))) == (:A_new,:B)

    @test samefields(@row(A::Int64=1, B::Float64=2.0), @row(B::Float64=2.0, A::Int64=1)) == true
    @test samefields(@index(A::Int64, B::Float64), @row(B::Float64=2.0, A::Int64=1)) == true
    @test samefields(@row(A::Int64=1, B::Float64=2.0), @index(B::Float64, A_new::Int64)) == false

    @test @row(A::Int64=1, B::Float64=2.0) == @row(A::Int64=1, B::Float64=2.0)
    @test @row(A::Int64=1, B::Float64=2.0) == @row(B::Float64=2.0, A::Int64=1)
    @test @row(A::Int64=1, B::Float64=2.0) != @row(B::Float64=2.0, A::Int64=3)
end

@testset "Accessing and iterating" begin
    @test copy(@row(A::Int64=1,B::Float64=2.0)) == @row(A::Int64=1,B::Float64=2.0)
    @test deepcopy(@row(A::Int64=1,B::Float64=2.0)) == @row(A::Int64=1,B::Float64=2.0)

    @test (@row(A::Int64=1,B::Float64=2.0))[@field(A::Int64)] == 1
    @test (@row(A::Int64=1,B::Float64=2.0))[Val{1}] == @cell(A::Int64=1)
    @test (@row(A::Int64=1,B::Float64=2.0))[Val{:A}] == 1
    @test (@row(A::Int64=1,B::Float64=2.0))[@index(B::Float64,A::Int64)] == @row(B::Float64=2.0,A::Int64=1)
    @test (@row(A::Int64=1,B::Float64=2.0))[Val{(1,2)}] == @row(A::Int64=1,B::Float64=2.0)
    @test (@row(A::Int64=1,B::Float64=2.0))[Val{(:A,:B)}] == @row(A::Int64=1,B::Float64=2.0)
    #@test (@row(A::Int64=1,B::Float64=2.0))[2:-1:1] == @row(B::Float64=2.0,A::Int64=1)
    @test (@row(A::Int64=1,B::Float64=2.0))[:] == (@row(A::Int64=1,B::Float64=2.0))
end

@testset "Composing and Concatenating" begin
    cell_a = @cell(A::Int64=1)
    cell_b = @cell(B::Float64=2.0)
    cell_c = @cell(C::Bool=true)
    row_a = @row(A::Int64=1)
    row_b = @row(B::Float64=2.0)

    @test @inferred(hcat(cell_a)) == Row{@index(A::Int64),Tuple{Int64}}((1,))
    @test @inferred(hcat(row_a)) == Row{@index(A::Int64),Tuple{Int64}}((1,))

    @test @inferred(hcat(cell_a, cell_b)) == Row{@index(A::Int64,B::Float64),Tuple{Int64,Float64}}((1,2.0))
    @test @inferred(hcat(cell_a, row_b)) == Row{@index(A::Int64,B::Float64),Tuple{Int64,Float64}}((1,2.0))
    @test @inferred(hcat(row_a, cell_b)) == Row{@index(A::Int64,B::Float64),Tuple{Int64,Float64}}((1,2.0))
    @test @inferred(hcat(row_a, row_b)) == Row{@index(A::Int64,B::Float64),Tuple{Int64,Float64}}((1,2.0))

    @test @inferred(hcat(cell_a, cell_b, cell_c)) == Row{@index(A::Int64,B::Float64,C::Bool),Tuple{Int64,Float64,Bool}}((1,2.0,true))
end

end
