@testset "Table" begin

@testset "Constructors and macros" begin
    @test Table(@index(A::Int64,B::Float64), ([1,2,3],[2.0,4.0,6.0])) == Table{@index(A::Int64,B::Float64), Tuple{Int64,Float64}, Tuple{Vector{Int64},Vector{Float64}}}(([1,2,3],[2.0,4.0,6.0]))
    @test Table(@index(A::Int64,B::Float64)) == Table{@index(A::Int64,B::Float64), Tuple{Int64,Float64}, Tuple{Vector{Int64},Vector{Float64}}}((Int64[],Float64[]))


    @test @table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])  == Table{@index(A::Int64,B::Float64), Tuple{Int64,Float64}, Tuple{Vector{Int64},Vector{Float64}}}(([1,2,3],[2.0,4.0,6.0]))
    @test (@table A::Int64=[1,2,3] B::Float64=[2.0,4.0,6.0]) == Table{@index(A::Int64,B::Float64), Tuple{Int64,Float64}, Tuple{Vector{Int64},Vector{Float64}}}(([1,2,3],[2.0,4.0,6.0]))
end

@testset "Introspection" begin
    @test (show(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])); println(); true)

    @test names(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])) == (:A,:B)
    @test eltypes(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])) == Tuple{Int64,Float64}
    @test rename(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]),@index(A_new::Int64,B_new::Float64)) == @table(A_new::Int64=[1,2,3],B_new::Float64=[2.0,4.0,6.0])
    @test rename(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]),@field(A::Int64),@field(A_new::Int64)) == @table(A_new::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])
    @test index(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])) == @index(A::Int64,B::Float64)
    @test key(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])) == DefaultKey()
    @test keyname(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])) == :Row
    @test keytype(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])) == Int

    @test length(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])) == 3
    @test ncol(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])) == 2
    @test nrow(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])) == 3
    @test size(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])) == (3,2)
    @test size(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]),1) == 3
    @test size(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]),2) == 2
    @test eltype(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])) == Tuple{Int64,Float64}
    @test isempty(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])) == false
    @test endof(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])) == 3

    @test first(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])) == @row(A::Int64=1,B::Float64=2.0)
    @test next(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]),1) == (@row(A::Int64=1,B::Float64=2.0),2)
    @test last(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])) == @row(A::Int64=3,B::Float64=6.0)

    @test @table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])[1] == @row(A::Int64=1,B::Float64=2.0)
    @test @table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])[:] == @table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])
    @test @table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])[3:-1:1] == @table(A::Int64=[3,2,1],B::Float64=[6.0,4.0,2.0])

    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); t[1] = @row(A::Int64=4,B::Float64=0.0); t == @table(A::Int64=[4,2,3],B::Float64=[0.0,4.0,6.0]) )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); t[1:2] = t[2:3]; t == @table(A::Int64=[2,3,3],B::Float64=[4.0,6.0,6.0]) )

    # unsafe get/setindex

    @test (t=@table(A::Int64=[1,2],B::Float64=[2.0,4.0]); push!(t,@row(A::Int64=3,B::Float64=6.0)); t == @table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]) )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); pop!(t) == @row(A::Int64=3,B::Float64=6.0) && t == @table(A::Int64=[1,2],B::Float64=[2.0,4.0]) )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); append!(t,t); t == @table(A::Int64=[1,2,3,1,2,3],B::Float64=[2.0,4.0,6.0,2.0,4.0,6.0]) )
    # push/pop/append with data.

    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); empty!(t); isempty(t) == true )

    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); copy(t) == t )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); deepcopy(t) == t )

    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); Tables.head(t) == t )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); Tables.tail(t) == t )

    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); t[@field(A::Int64)] == [1,2,3] )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); t[@index(A::Int64)] == @table(A::Int64=[1,2,3]) )



end

@testset "Accessing and iterating rows" begin

end


@testset "Accessing columns and cells" begin

end

end
