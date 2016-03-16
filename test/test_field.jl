@testset "Field" begin

@testset "Constructors and macros" begin
    @test (@field A::Int64)  == Field{:A,Int64}()
    @test @field(B::Float64) == Field{:B,Float64}()
end

@testset "Introspection" begin
    a = Field{:A,Int64}()
    b = Field{:B,Float64}()
    a_new = Field{:A_new,Int64}()

    @test name(Field{:A,Int64}()) == :A
    @test name(Field{:A,Int64}) == :A
    @test eltype(Field{:A,Int64}()) == Int64
    @test eltype(Field{:A,Int64}) == Int64
    @test (show(a);println();true)
    @test length(a) == 1
    @test samefield(a,a) == true
    @test samefield(a,b) == false
end

@testset "DefaultKey" begin
    @test (show(DefaultKey());println();true)
    @test eltype(DefaultKey()) == Int
    @test eltype(DefaultKey) == Int
    @test name(DefaultKey()) == :Row
    @test name(DefaultKey) == :Row
end

end
