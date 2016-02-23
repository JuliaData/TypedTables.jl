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
    @test length(idx) == 2
    @test endof(idx) == 2

    @test eltypes(idx) == Tuple{Int64,Float64}
    @test names(idx) == (:A,:B)

    @test show(idx) == nothing
    println()

    #TODO rename
end


@testset "Accessing and iterating" begin

end

@testset "Union, intersect, setdiff, +, -" begin

end

#@test @index(a::Int64) == FieldIndex{(Field{:a,Int64}(),)}()
#@test @index(a::Int64,b::Float64) == FieldIndex{(Field{:a,Int64}(),Field{:b,Float64}())}()

#@test idx[a] ==

end
