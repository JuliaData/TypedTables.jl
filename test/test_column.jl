println("\nColumn tests")
v1 = [1,2,3]

@test Column(a,v1) == Column{a,Int64,Vector{Int64}}(v1)
@test Column(a) == Column{a,Int64,Vector{Int64}}(Vector{Int64}())
@test Column(c1,c2,c3) == Column{a,Int64,Vector{Int64}}(v1)
@test Column(a,1,2,3) == Column{a,Int64,Vector{Int64}}(v1)

@test @column(a = [1,2,3]) == Column{a,Int64,Vector{Int64}}(v1))
@test (@column a::Int64 = [1,2,3]) == Column{a,Int64,Vector{Int64}}(v1))

col1 = Column(a,v1)

@test show(col1)
