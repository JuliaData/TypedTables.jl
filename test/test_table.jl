@testset "Table" begin

@testset "Constructors and macros" begin
    @test Table(@index(A::Int,B::Float64), ([1,2,3],[2.0,4.0,6.0])) == Table{@index(A::Int64,B::Float64), Tuple{Int64,Float64}, Tuple{Vector{Int64},Vector{Float64}}}(([1,2,3],[2.0,4.0,6.0]))

    @test @table(A::Int=[1,2,3],B::Float64=[2.0,4.0,6.0])  == Table{@index(A::Int64,B::Float64), Tuple{Int64,Float64}, Tuple{Vector{Int64},Vector{Float64}}}(([1,2,3],[2.0,4.0,6.0]))
    @test (@table A::Int=[1,2,3] B::Float64=[2.0,4.0,6.0]) == Table{@index(A::Int64,B::Float64), Tuple{Int64,Float64}, Tuple{Vector{Int64},Vector{Float64}}}(([1,2,3],[2.0,4.0,6.0]))
end

@testset "Introspection" begin
    @test (show(@table(A::Int=[1,2,3],B::Float64=[2.0,4.0,6.0])); println(); true)
end

@testset "Accessing and iterating rows" begin

end


@testset "Accessing columns and cells" begin

end

end
