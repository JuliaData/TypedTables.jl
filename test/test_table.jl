@testset "Table" begin

@testset "Constructors and macros" begin
    @test @inferred(Table(@index(A::Int64,B::Float64), ([1,2,3],[2.0,4.0,6.0]))) == Table{@index(A::Int64,B::Float64), Tuple{Int64,Float64}, Tuple{Vector{Int64},Vector{Float64}}}(([1,2,3],[2.0,4.0,6.0]))
    @test @inferred(Table(@index(A::Int64,B::Float64))) == Table{@index(A::Int64,B::Float64), Tuple{Int64,Float64}, Tuple{Vector{Int64},Vector{Float64}}}((Int64[],Float64[]))

    # More constructors here?

    @test @index(A::Int64,B::Float64)(([1,2,3],[2.0,4.0,6.0])) == Table{@index(A::Int64,B::Float64), Tuple{Int64,Float64}, Tuple{Vector{Int64},Vector{Float64}}}(([1,2,3],[2.0,4.0,6.0]))

    @test @table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])  == Table{@index(A::Int64,B::Float64), Tuple{Int64,Float64}, Tuple{Vector{Int64},Vector{Float64}}}(([1,2,3],[2.0,4.0,6.0]))
    @test (@table A::Int64=[1,2,3] B::Float64=[2.0,4.0,6.0]) == Table{@index(A::Int64,B::Float64), Tuple{Int64,Float64}, Tuple{Vector{Int64},Vector{Float64}}}(([1,2,3],[2.0,4.0,6.0]))
end

@testset "Introspection" begin
    id(x) = x # helpful to force @inferred to work...

    @test (show(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])); println(); true)

    @test names(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])) == (:A,:B)
    @test eltypes(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])) == Tuple{Int64,Float64}
    @test @inferred(id(rename(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]),@index(A_new::Int64,B_new::Float64)))) == @table(A_new::Int64=[1,2,3],B_new::Float64=[2.0,4.0,6.0])
    @test @inferred(id(rename(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]),@field(A::Int64),@field(A_new::Int64)))) == @table(A_new::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])
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

    @test samefields(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]), @table(B::Float64=[2.0,4.0,6.0],A::Int64=[1,2,3])) == true
    @test samefields(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]), @table(B::Float64=[2.0,4.0,6.0],A_new::Int64=[1,2,3])) == false
    @test samefields(@row(A::Int64=1,B::Float64=2.0), @table(B::Float64=[2.0,4.0,6.0],A::Int64=[1,2,3])) == true
    @test samefields(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]), @row(B::Float64=2.0,A_new::Int64=1)) == false
    @test samefields(@index(A_new::Int64,B::Float64), @table(B::Float64=[2.0,4.0,6.0],A::Int64=[1,2,3])) == false
    @test samefields(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]), @index(B::Float64,A::Int64)) == true

    @test @table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]) == @table(B::Float64=[2.0,4.0,6.0],A::Int64=[1,2,3])
    @test @table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]) != @table(B::Float64=[2.0,4.0,6.0],A_new::Int64=[1,2,3])
    @test @table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]) != @table(B::Float64=[2.0,4.0,6.0],A::Int64=[1,2,4])

    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); copy(t) == t )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); deepcopy(t) == t )
end

@testset "Accessing and iterating rows" begin
    # push/pop/append with data.

    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); empty!(t); isempty(t) == true )

    @test first(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])) == @row(A::Int64=1,B::Float64=2.0)
    @test next(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]),1) == (@row(A::Int64=1,B::Float64=2.0),2)
    @test last(@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0])) == @row(A::Int64=3,B::Float64=6.0)

    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, 1)) == @row(A::Int64=1,B::Float64=2.0) )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, :)) == @table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]) )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, 3:-1:1)) == @table(A::Int64=[3,2,1],B::Float64=[6.0,4.0,2.0]) )

    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); t[1] = @row(A::Int64=4,B::Float64=0.0); t == @table(A::Int64=[4,2,3],B::Float64=[0.0,4.0,6.0]) )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); t[1:2] = t[2:3]; t == @table(A::Int64=[2,3,3],B::Float64=[4.0,6.0,6.0]) )

    # unsafe get/setindex

    @test (t=@table(A::Int64=[1,2],B::Float64=[2.0,4.0]); push!(t,@row(A::Int64=3,B::Float64=6.0)); t == @table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]) )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); pop!(t) == @row(A::Int64=3,B::Float64=6.0) && t == @table(A::Int64=[1,2],B::Float64=[2.0,4.0]) )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); append!(t,t); t == @table(A::Int64=[1,2,3,1,2,3],B::Float64=[2.0,4.0,6.0,2.0,4.0,6.0]) )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); TypedTables.head(t) == t )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); TypedTables.tail(t) == t )
end


@testset "Accessing columns and cells" begin
    id(x) = x # helpful to force @inferred to work...

    field_a = @field(A::Int64)
    index_a = @index(A::Int64)

    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, field_a)) == [1,2,3] )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, index_a)) == @table(A::Int64=[1,2,3]) )

    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, Val{1})) == @column(A::Int64=[1,2,3]) )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, Val{:A})) == [1,2,3] )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, Val{(1,)})) == @table(A::Int64=[1,2,3]) )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, Val{(:A,)})) == @table(A::Int64=[1,2,3]) )

    # Simultaneous indexing row and column
    # Single Row
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, 1, field_a)) == 1 )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, 1, index_a)) == @row(A::Int64=1) )

    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, 1, Val{1})) == @cell(A::Int64=1) )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, 1, Val{:A})) == 1 )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, 1, Val{(1,)})) == @row(A::Int64=1) )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, 1, Val{(:A,)})) == @row(A::Int64=1) )

    # Multiple rows
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, :, field_a)) == [1,2,3] )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, :, index_a)) == @table(A::Int64=[1,2,3]) )

    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, :, Val{1})) == @column(A::Int64=[1,2,3]) )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, :, Val{:A})) == [1,2,3] )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, :, Val{(1,)})) == @table(A::Int64=[1,2,3]) )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, :, Val{(:A,)})) == @table(A::Int64=[1,2,3]) )

    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, 1, :)) == @row(A::Int64=1,B::Float64=2.0) )
    @test (t=@table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]); @inferred(getindex(t, :, :)) == @table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0]) )
end

@testset "Concatenation" begin
    @test (r=@row(A::Int64=1,B::Float64=2.0); t = @inferred(vcat(r)); t == @table(A::Int64=[1],B::Float64=[2.0]) )
    @test (r=@row(A::Int64=1,B::Float64=2.0); t = @inferred(vcat(r,r)); t == @table(A::Int64=[1,1],B::Float64=[2.0,2.0]) )
    @test (r=@row(A::Int64=1,B::Float64=2.0); t = @inferred(vcat(r,r,r)); t == @table(A::Int64=[1,1,1],B::Float64=[2.0,2.0,2.0]) )

    @test (r=@row(A::Int64=1,B::Float64=2.0); t = vcat(r); t2 = @inferred(vcat(r,t)); t2 == @table(A::Int64=[1,1],B::Float64=[2.0,2.0]) )
    @test (r=@row(A::Int64=1,B::Float64=2.0); t = vcat(r); t2 = @inferred(vcat(t,r)); t2 == @table(A::Int64=[1,1],B::Float64=[2.0,2.0]) )
    @test (r=@row(A::Int64=1,B::Float64=2.0); t = vcat(r); t2 = @inferred(vcat(t,t)); t2 == @table(A::Int64=[1,1],B::Float64=[2.0,2.0]) )
    @test (r=@row(A::Int64=1,B::Float64=2.0); t = vcat(r); t2 = @inferred(vcat(t,t,t)); t2 == @table(A::Int64=[1,1,1],B::Float64=[2.0,2.0,2.0]) )

    @test (c=@column(A::Int64=[1,2,3]); t = @inferred(hcat(c)); t == @table(A::Int64=[1,2,3]) )
    @test (c1=@column(A::Int64=[1,2,3]); c2=@column(B::Float64=[2.0,4.0,6.0]); t = @inferred(hcat(c1,c2)); t == @table(A::Int64=[1,2,3], B::Float64=[2.0,4.0,6.0]) )
    @test (c1=@column(A::Int64=[1,2,3]); c2=@column(B::Float64=[2.0,4.0,6.0]); c3=@column(C::Bool=[true,false,false]); t = @inferred(hcat(c1,c2,c3)); t == @table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0],C::Bool=[true,false,false]) )

    @test (t=@table(A::Int64=[1,2,3]); t2 = @inferred(hcat(t)); t2 == @table(A::Int64=[1,2,3]) )
    @test (c1=@column(A::Int64=[1,2,3]); c2=@column(B::Float64=[2.0,4.0,6.0]); t = @inferred(hcat(hcat(c1),c2)); t == @table(A::Int64=[1,2,3], B::Float64=[2.0,4.0,6.0]) )
    @test (c1=@column(A::Int64=[1,2,3]); c2=@column(B::Float64=[2.0,4.0,6.0]); t = @inferred(hcat(c1,hcat(c2))); t == @table(A::Int64=[1,2,3], B::Float64=[2.0,4.0,6.0]) )
    @test (c1=@column(A::Int64=[1,2,3]); c2=@column(B::Float64=[2.0,4.0,6.0]); t = @inferred(hcat(hcat(c1),hcat(c2))); t == @table(A::Int64=[1,2,3], B::Float64=[2.0,4.0,6.0]) )
    @test (c1=@column(A::Int64=[1,2,3]); c2=@column(B::Float64=[2.0,4.0,6.0]); c3=@column(C::Bool=[true,false,false]); t = @inferred(hcat(hcat(c1),c2,c3)); t == @table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0],C::Bool=[true,false,false]) )
    @test (c1=@column(A::Int64=[1,2,3]); c2=@column(B::Float64=[2.0,4.0,6.0]); c3=@column(C::Bool=[true,false,false]); t = @inferred(hcat(c1,hcat(c2),c3)); t == @table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0],C::Bool=[true,false,false]) )
    @test (c1=@column(A::Int64=[1,2,3]); c2=@column(B::Float64=[2.0,4.0,6.0]); c3=@column(C::Bool=[true,false,false]); t = @inferred(hcat(hcat(c1),hcat(c2),c3)); t == @table(A::Int64=[1,2,3],B::Float64=[2.0,4.0,6.0],C::Bool=[true,false,false]) )


end

end
