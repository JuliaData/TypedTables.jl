@testset "FieldIndex" begin

a = Field{:A,Int64}()
b = Field{:B,Float64}()
c = Field{:C,Bool}()
d = Field{:D,Int32}()

a_new = Field{:A_new,Int64}()
a_32 = Field{:A,Int32}()

@testset "Constructors and macros" begin
     @test @index(A::Int64, B::Float64) == FieldIndex{(a,b)}()
     @test (@index A::Int64 B::Float64) == FieldIndex{(a,b)}()

     @test @inferred(FieldIndex(a)) == FieldIndex{(a,)}()
     @test @inferred(FieldIndex((a,b))) == FieldIndex{(a,b)}()
end

idx = FieldIndex{(a,b)}()

@testset "Introspection" begin
    @test ncol(idx) == 2
    @test ncol(typeof(idx)) == 2
    @test length(idx) == 2
    @test length(typeof(idx)) == 2
    @test endof(idx) == 2

    @test eltypes(idx) == Tuple{Int64,Float64}
    @test eltypes(typeof(idx)) == Tuple{Int64,Float64}
    @test names(idx) == (:A,:B)
    @test names(typeof(idx)) == (:A,:B)

    @test (show(idx); println(); true)

    @test names(@inferred(rename(idx,a,a_new))) == (:A_new,:B)
    @test names(@inferred(rename(idx,FieldIndex(a),FieldIndex(a_new)))) == (:A_new,:B)

    @test samefields(idx,idx) == true
    @test samefields(a+b,b+a) == true
    @test samefields(a+b,b+c) == false
end

@testset "Accessing and iterating" begin
    @test @inferred(first(idx)) == a
    @test idx[1] == a
    @test @inferred(getindex(idx, Val{1})) == a
    @test @inferred(getindex(idx, Val{:A})) == 1
    @test @inferred(getindex(idx, :)) == idx
    @test idx[1:2] == idx
    @test getindex(idx, Val{1:2}) == idx # Can't run @inferred, @code_warntype or return_types() here - problem in Base??
    @test @inferred(getindex(idx, Val{(1,2)})) == idx
    @test @inferred(getindex(idx, Val{(:A,:B)})) == (1,2)

    @test idx[a] == 1
    @test idx[idx] == (1,2)
end

@testset "Union, intersect, setdiff, +, -" begin
    @test @inferred(union(a)) == FieldIndex(a)
    @test @inferred(union(a,b)) == idx
    @test @inferred(union(a,b,c,d)) == FieldIndex((a,b,c,d))

    @test @inferred(intersect(a,b)) == FieldIndex(())
    @test @inferred(intersect(a,a)) == FieldIndex((a,))
    @test @inferred(intersect(idx,a)) == FieldIndex((a,))
    @test @inferred(intersect(idx,idx)) == idx

    @test @inferred(setdiff(a,a)) == FieldIndex(())
    @test @inferred(setdiff(idx,b)) == FieldIndex((a,))
    @test @inferred(setdiff(idx,idx)) == FieldIndex(())
    @test @inferred(setdiff(idx,c)) == idx
    @test @inferred(setdiff(idx,FieldIndex(c))) == idx

    @test @inferred(+(a,b,c,d)) == FieldIndex((a,b,c,d))
    @test @inferred(-(idx, b)) == FieldIndex((a,))
end

end
