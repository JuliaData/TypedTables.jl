using Tables
using Base.Test

# write your own tests here
@test (a = @field a::Int) == Field{:a,Int}()
@test (b = @field(b::Float64)) == Field{:b,Float64}()

@test (idx = @index(a::Int) == FieldIndex{(Field{:a,Int}(),Field{:b,Float64})}()
@test (b = @field(b::Float64)) == Field{:a,Int}()



end
