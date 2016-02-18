using Tables
using Base.Test

# Field tests
#local a, b
a = 0
b = 0
@test (a = @field a::Int64 )   == Field{:a,Int64}()
@test (b = @field(b::Float64)) == Field{:b,Float64}()

@test name(a) == :a == name(typeof(a))
@test eltype(a) == Int64 == eltype(typeof(a))
show(a)
@test length(a) == 1


# Cell tests
#local c1,c2
@test (c1 = @cell a::Int64 = 1 )   == Cell(b,1) == Cell{Field{:a,Int64}(),Int64}(1)
@test (c2 = @cell(b::Float64 = 2.0)) == Cell(a,2.0) == Cell{Field{:b,Float64}(),Float64}(2.0)

@test name(c1) == :a == name(typeof(c1))
@test eltype(a) == Int64 == eltype(typeof(a))
show(a)
@test length(a) == 1

# Column tests


# FieldIndex tests
@test (idx = @index(a::Int64) == FieldIndex{(Field{:a,Int64}(),Field{:b,Float64})}()
@test idx[a] ==


# Row tests


#




end
