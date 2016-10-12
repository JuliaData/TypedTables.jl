@testset "Table" begin

@testset "Constructors and macros" begin
    @test @inferred(Table{(:A, :B)}(([1,2,3], [2.0,4.0,6.0]))) == Table{(:A, :B), Tuple{Vector{Int},Vector{Float64}}}(([1,2,3],[2.0,4.0,6.0]))
    @test @inferred(Table{(:A, :B), Tuple{Vector{Int}, Vector{Float64}}}()) == Table{(:A, :B), Tuple{Vector{Int},Vector{Float64}}}((Int[],Float64[]))

    @test @inferred(Table{(:A, :B)}(([1,2,3],[2.0,4.0,6.0]), Val{false})) == Table{(:A, :B), Tuple{Vector{Int},Vector{Float64}}}(([1,2,3],[2.0,4.0,6.0]), Val{true})

    @test @Table(A=[1,2,3], B=[2.0,4.0,6.0])  == Table{(:A, :B), Tuple{Vector{Int},Vector{Float64}}}(([1,2,3],[2.0,4.0,6.0]))
    @test (@Table A=[1,2,3] B=[2.0,4.0,6.0]) == Table{(:A, :B), Tuple{Vector{Int},Vector{Float64}}}(([1,2,3],[2.0,4.0,6.0]))
    @test @Table(A::Vector{Int}=[1,2,3], B::Vector{Float64}=[2.0,4.0,6.0]) == Table{(:A, :B), Tuple{Vector{Int},Vector{Float64}}}(([1,2,3],[2.0,4.0,6.0]))
    @test (@Table A::Vector{Int}=[1,2,3] B::Vector{Float64}=[2.0,4.0,6.0]) == Table{(:A, :B), Tuple{Vector{Int},Vector{Float64}}}(([1,2,3],[2.0,4.0,6.0]))
end

@testset "Introspection" begin
    t = @Table(A=[1,2,3],B=[2.0,4.0,6.0])

    @test (show(t); println(); true)

    @test names(t) == (:A,:B)
    @test names(typeof(t)) == (:A,:B)
    @test names(Table{(:A,:B)}) == (:A,:B)
    @test eltypes(t) == Tuple{Int,Float64}
    @test eltypes(typeof(t)) == Tuple{Int,Float64}
    @test storagetypes(t) == Tuple{Vector{Int},Vector{Float64}}
    @test storagetypes(typeof(t)) == Tuple{Vector{Int},Vector{Float64}}

    @test @inferred(rename(t, Val{(:A_new, :B_new)})) == @Table(A_new=[1,2,3],B_new=[2.0,4.0,6.0])
    @test @inferred(rename(t, Val{:A}, Val{:A_new})) == @Table(A_new=[1,2,3],B=[2.0,4.0,6.0])

    @test length(t) == 3
    @test ncol(t) == 2
    @test nrow(t) == 3
    #@test size(t) == (3,)
    #@test size(t,1) == 3
    @test ndims(t) == 1
    @test isempty(t) == false
    @test endof(t) == 3

    @test @Table(A=[1,2,3],B=[2.0,4.0,6.0]) == @Table(B=[2.0,4.0,6.0],A=[1,2,3])
    @test @Table(A=[1,2,3],B=[2.0,4.0,6.0]) != @Table(B=[2.0,4.0,6.0],A_new=[1,2,3])
    @test @Table(A=[1,2,3],B=[2.0,4.0,6.0]) != @Table(B=[2.0,4.0,6.0],A=[1,2,4])

    @test copy(t) == t
end

@testset "Accessing and iterating rows" begin
    # push/pop/append with data.

    @test (t=@Table(A=[1,2,3],B=[2.0,4.0,6.0]); empty!(t); isempty(t) == true )

    @test first(@Table(A=[1,2,3],B=[2.0,4.0,6.0])) == @Row(A=1,B=2.0)
    @test next(@Table(A=[1,2,3],B=[2.0,4.0,6.0]),1) == (@Row(A=1,B=2.0),2)
    @test last(@Table(A=[1,2,3],B=[2.0,4.0,6.0])) == @Row(A=3,B=6.0)

    @test (t=@Table(A=[1,2,3],B=[2.0,4.0,6.0]); @inferred(getindex(t, 1)) == @Row(A=1,B=2.0) )
    @test (t=@Table(A=[1,2,3],B=[2.0,4.0,6.0]); @inferred(getindex(t, :)) == @Table(A=[1,2,3],B=[2.0,4.0,6.0]) )
    @test (t=@Table(A=[1,2,3],B=[2.0,4.0,6.0]); @inferred(getindex(t, 3:-1:1)) == @Table(A=[3,2,1],B=[6.0,4.0,2.0]) )

    @test (t=@Table(A=[1,2,3],B=[2.0,4.0,6.0]); t[1] = @Row(A=4,B=0.0); t == @Table(A=[4,2,3],B=[0.0,4.0,6.0]) )
    @test (t=@Table(A=[1,2,3],B=[2.0,4.0,6.0]); t[1] = @Row(B=0.0,A=4); t == @Table(A=[4,2,3],B=[0.0,4.0,6.0]) )
    @test (t=@Table(A=[1,2,3],B=[2.0,4.0,6.0]); t[1:2] = t[2:3]; t == @Table(A=[2,3,3],B=[4.0,6.0,6.0]) )

    # unsafe get/setindex

    @test (t=@Table(A=[1,2],B=[2.0,4.0]); push!(t,@Row(A=3,B=6.0)); t == @Table(A=[1,2,3],B=[2.0,4.0,6.0]) )
    @test (t=@Table(A=[1,2,3],B=[2.0,4.0,6.0]); pop!(t) == @Row(A=3,B=6.0) && t == @Table(A=[1,2],B=[2.0,4.0]) )
    @test (t=@Table(A=[1,2,3],B=[2.0,4.0,6.0]); append!(t,t); t == @Table(A=[1,2,3,1,2,3],B=[2.0,4.0,6.0,2.0,4.0,6.0]) )
    @test (t=@Table(A=[1,2,3],B=[2.0,4.0,6.0]); TypedTables.head(t) == t )
    @test (t=@Table(A=[1,2,3],B=[2.0,4.0,6.0]); TypedTables.tail(t) == t )
end


@testset "Accessing columns and cells" begin
    @test (t=@Table(A=[1,2,3],B=[2.0,4.0,6.0]); @inferred(getindex(t, Val{:A})) == [1,2,3] )
    @test (t=@Table(A=[1,2,3],B=[2.0,4.0,6.0]); @inferred(getindex(t, Val{(:A,)})) == @Table(A=[1,2,3]) )

    # TODO Simultaneous indexing row and column
    # Single Row
    @test (t=@Table(A=[1,2,3],B=[2.0,4.0,6.0]); @inferred(getindex(t, 1, Val{:A})) == 1 )
    @test (t=@Table(A=[1,2,3],B=[2.0,4.0,6.0]); @inferred(getindex(t, 1, Val{(:A,)})) == @Row(A=1) )

    # Multiple rows
    @test (t=@Table(A=[1,2,3],B=[2.0,4.0,6.0]); @inferred(getindex(t, :, Val{:A})) == [1,2,3] )
    @test (t=@Table(A=[1,2,3],B=[2.0,4.0,6.0]); @inferred(getindex(t, :, Val{(:A,)})) == @Table(A=[1,2,3]) )

    @test (t=@Table(A=[1,2,3],B=[2.0,4.0,6.0]); @inferred(getindex(t, 1, :)) == @Row(A=1,B=2.0) )
    @test (t=@Table(A=[1,2,3],B=[2.0,4.0,6.0]); @inferred(getindex(t, :, :)) == @Table(A=[1,2,3],B=[2.0,4.0,6.0]) )

end

@testset "Concatenation" begin
    @test (r=@Row(A=1,B=2.0); t = @inferred(vcat(r)); t == @Table(A=[1],B=[2.0]) )
    @test (r=@Row(A=1,B=2.0); t = @inferred(vcat(r,r)); t == @Table(A=[1,1],B=[2.0,2.0]) )
    @test (r=@Row(A=1,B=2.0); t = (vcat(r,r,r)); t == @Table(A=[1,1,1],B=[2.0,2.0,2.0]) )

    @test (r=@Row(A=1,B=2.0); t = vcat(r); t2 = (vcat(r,t)); t2 == @Table(A=[1,1],B=[2.0,2.0]) )
    @test (r=@Row(A=1,B=2.0); t = vcat(r); t2 = (vcat(t,r)); t2 == @Table(A=[1,1],B=[2.0,2.0]) )
    @test (r=@Row(A=1,B=2.0); t = vcat(r); t2 = @inferred(vcat(t,t)); t2 == @Table(A=[1,1],B=[2.0,2.0]) )
    @test (r=@Row(A=1,B=2.0); t = vcat(r); t2 = @inferred(vcat(t,t,t)); t2 == @Table(A=[1,1,1],B=[2.0,2.0,2.0]) )

    @test (c=@Column(A=[1,2,3]); t = @inferred(hcat(c)); t == @Table(A=[1,2,3]) )
    @test (c1=@Column(A=[1,2,3]); c2=@Column(B=[2.0,4.0,6.0]); t = @inferred(hcat(c1,c2)); t == @Table(A=[1,2,3], B=[2.0,4.0,6.0]) )
    @test (c1=@Column(A=[1,2,3]); c2=@Column(B=[2.0,4.0,6.0]); c3=@Column(C=[true,false,false]); t = @inferred(hcat(c1,c2,c3)); t == @Table(A=[1,2,3],B=[2.0,4.0,6.0],C=[true,false,false]) )

    @test (t=@Table(A=[1,2,3]); t2 = @inferred(hcat(t)); t2 == @Table(A=[1,2,3]) )
    @test (c1=@Column(A=[1,2,3]); c2=@Column(B=[2.0,4.0,6.0]); t = @inferred(hcat(hcat(c1),c2)); t == @Table(A=[1,2,3], B=[2.0,4.0,6.0]) )
    @test (c1=@Column(A=[1,2,3]); c2=@Column(B=[2.0,4.0,6.0]); t = @inferred(hcat(c1,hcat(c2))); t == @Table(A=[1,2,3], B=[2.0,4.0,6.0]) )
    @test (c1=@Column(A=[1,2,3]); c2=@Column(B=[2.0,4.0,6.0]); t = @inferred(hcat(hcat(c1),hcat(c2))); t == @Table(A=[1,2,3], B=[2.0,4.0,6.0]) )
    @test (c1=@Column(A=[1,2,3]); c2=@Column(B=[2.0,4.0,6.0]); c3=@Column(C=[true,false,false]); t = @inferred(hcat(hcat(c1),c2,c3)); t == @Table(A=[1,2,3],B=[2.0,4.0,6.0],C=[true,false,false]) )
    @test (c1=@Column(A=[1,2,3]); c2=@Column(B=[2.0,4.0,6.0]); c3=@Column(C=[true,false,false]); t = @inferred(hcat(c1,hcat(c2),c3)); t == @Table(A=[1,2,3],B=[2.0,4.0,6.0],C=[true,false,false]) )
    @test (c1=@Column(A=[1,2,3]); c2=@Column(B=[2.0,4.0,6.0]); c3=@Column(C=[true,false,false]); t = @inferred(hcat(hcat(c1),hcat(c2),c3)); t == @Table(A=[1,2,3],B=[2.0,4.0,6.0],C=[true,false,false]) )
end

end
