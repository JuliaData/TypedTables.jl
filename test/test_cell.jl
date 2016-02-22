println("\nCell tests")
@test (@cell A::Int64 = 1) == a(1)
@test (@cell a = 1) == a(1)
@test @cell(B::Float64 = 2.0) == Cell(b,2.0)
@test @cell(b = 2.0) == Cell(b,2.0)
@test Cell(Field{:A,Int64}(),1) == Cell{Field{:A,Int64}(),Int64}(1)
@test a(1)  == Cell{Field{:A,Int64}(),Int64}(1)

c1 = @cell A::Int64 = 1
c2 = @cell(A::Int64 = 2)
c3 = @cell(A::Int64 = 3)

@test name(c1) == :A
@test name(typeof(c1)) == :A
@test eltype(c1) == Int64
@test eltype(typeof(c1)) == Int64
@test show(c1) == nothing
@test length(c1) == 1
@test length(typeof(c1)) == 1

@test rename(c1, a_new) == @cell(a_new = 1)

@test copy(c1) == deepcopy(c1)
