println("\nFieldIndex tests")

#@test @index(a::Int64) == FieldIndex{(Field{:a,Int64}(),)}()
#@test @index(a::Int64,b::Float64) == FieldIndex{(Field{:a,Int64}(),Field{:b,Float64}())}()

#@test idx[a] ==
