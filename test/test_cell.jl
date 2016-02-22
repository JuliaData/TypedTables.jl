println("\nCell tests")
@test (@cell a::Int64 = 1) == a(1)
@test @cell(b::Float64 = 2.0) == Cell(b,2.0)
@test Cell(Field{:a,Int64}(),1) == Cell{Field{:a,Int64}(),Int64}(1)
@test a(1)  == Cell{Field{:a,Int64}(),Int64}(1)

c1 = @cell a::Int64 = 1
c2 = @cell(a::Int64 = 2)
c3 = @cell(a::Int64 = 3)

@test name(c1) == :a
@test name(typeof(c1)) == :a
@test eltype(c1) == Int64
@test eltype(typeof(c1)) == Int64
@test show(c1) == nothing
@test length(c1) == 1
@test length(typeof(c1)) == 1

@test rename(c1, @field a_new::Int64) == @cell(a_new::Int64 = 1)

@test copy(c1) == deepcopy(c1)
