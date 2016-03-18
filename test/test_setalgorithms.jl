@testset "Set Algorithms" begin

col_a1 = @column A::Int64 =   [1,   2,   4,   1,   4,   1]
col_b1 = @column B::Float64 = [1.0, 2.0, 1.0, 2.0, 4.0, 1.0]

col_a2 = @column A::Int64 =   [2,   3,   4,   4]
col_b2 = @column B::Float64 = [0.0, 0.0, 0.0, 4.0]

table1 = hcat(col_a1, col_b1)
table2 = hcat(col_a2, col_b2)

@test Set(unique(col_a1).data) == Set([1,2,4])
@test (unique!(col_a2); Set(col_a2.data) == Set([2,3,4]))

@test length(unique(table1)) == 5
@test (tmp = copy(table1); unique!(tmp); tmp == unique(table1))

@test length(union(col_a1,col_a2)) == 4
@test length(setdiff(col_a1,col_a2)) == 1
@test length(intersect(unique(col_a1),col_a2)) == 2 # there may be a problem with Julia's intersect for non-unique inputs...

@test length(union(table1,table2)) == 8
@test length(setdiff(table1,table2)) == 4
@test length(intersect(table1,table2)) == 1


end
