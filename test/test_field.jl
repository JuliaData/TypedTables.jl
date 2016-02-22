println("\nField tests")
@test (@field a::Int64)    == Field{:a,Int64}()
@test @field(b::Float64) == Field{:b,Float64}()

a = Field{:a,Int64}()
b = Field{:b,Float64}()

@test name(Field{:a,Int64}()) == :a
@test name(Field{:a,Int64}) == :a
@test eltype(Field{:a,Int64}()) == Int64
@test eltype(Field{:a,Int64}) == Int64
@test show(a) == nothing
@test length(a) == 1
