println("\nField tests")
@test (@field A::Int64)    == Field{:A,Int64}()
@test @field(B::Float64) == Field{:B,Float64}()

a = Field{:A,Int64}()
b = Field{:B,Float64}()
a_new = Field{:A_new,Int64}()

@test name(Field{:A,Int64}()) == :A
@test name(Field{:A,Int64}) == :A
@test eltype(Field{:A,Int64}()) == Int64
@test eltype(Field{:A,Int64}) == Int64
@test show(a) == nothing
@test length(a) == 1
