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

     @test FieldIndex(a) == FieldIndex{(a,)}()
     @test FieldIndex((a,b)) == FieldIndex{(a,b)}()
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

    @test names(rename(idx,a,a_new)) == (:A_new,:B)
    @test names(rename(idx,FieldIndex(a),FieldIndex(a_new))) == (:A_new,:B)
end

@testset "Accessing and iterating" begin
    @test first(idx) == a
    @test idx[1] == a
    @test idx[Val{1}] == a
    @test idx[Val{:A}] == 1
    @test idx[:] == idx
    @test idx[1:2] == idx
    @test idx[Val{1:2}] == idx
    @test idx[Val{(1,2)}] == idx
    @test idx[Val{(:A,:B)}] == (1,2)

    @test idx[a] == 1
    @test idx[idx] == (1,2)
end

@testset "Union, intersect, setdiff, +, -" begin
    @test union(a) == FieldIndex(a)
    @test union(a,b) == idx
    @test union(a,b,c,d) == FieldIndex((a,b,c,d))

    @test intersect(a,b) == FieldIndex(())
    @test intersect(a,a) == FieldIndex((a,))
    @test intersect(idx,a) == FieldIndex((a,))
    @test intersect(idx,idx) == idx

    @test setdiff(a,a) == FieldIndex(())
    @test setdiff(idx,b) == FieldIndex((a,))
    @test setdiff(idx,idx) == FieldIndex(())
    @test setdiff(idx,c) == idx
    @test setdiff(idx,FieldIndex(c)) == idx

    @test a+b+c+d == FieldIndex((a,b,c,d))
    @test idx - b == FieldIndex((a,))
end

end
