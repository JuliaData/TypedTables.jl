@testset "Column" begin

@testset "Constructors" begin
    v1 = [1,2,3]

    @test @inferred(Column{:A}(v1)) == Column{:A, Vector{Int}}(v1)
    @test @inferred(Column{:A, Vector{Int}}()) == Column{:A, Vector{Int}}(Vector{Int}())

    @test @Column(A = [1,2,3]) == Column{:A, Vector{Int}}(v1)
    @test (@Column A = [1,2,3]) == Column{:A, Vector{Int}}(v1)
    @test @Column(A::Vector{Int} = [1,2,3]) == Column{:A, Vector{Int}}(v1)
    @test (@Column A::Vector{Int} = [1,2,3]) == Column{:A, Vector{Int}}(v1)

    @test Column{:A, Vector{Float64}}([1,2,3]) == @Column(A=[1.0,2.0,3.0])
    @test convert(Column{:A, Vector{Float64}}, @Column(A=[1,2,3])) == @Column(A=[1.0,2.0,3.0])
end



@testset "Introspection" begin
    v1 = [1,2,3]
    col1 = Column{:A}(v1)

    @test (show(col1); println(); true)

    @test name(col1) == :A
    @test name(typeof(col1)) == :A
    @test eltype(col1) == Int
    @test eltype(typeof(col1)) == Int

    @test @inferred(rename(col1, Val{:A_new})) == @Column(A_new = v1)

    @test length(col1) == 3
    @test ncol(col1) == 1
    @test nrow(col1) == 3
    @test ndims(col1) == 1
    @test size(col1) == (3,)
    @test size(col1,1) == 3
    @test isempty(col1) == false
    @test endof(col1) == 3

end

@testset "Accessing and iterating" begin
    v1 = [1,2,3]
    col1 = Column{:A}(v1)

    @test map(x->x^2, col1) == v1.^2

    @test @inferred(getindex(col1, 2))   == 2
    @test @inferred(getindex(col1, 2:3)) == @Column A=[2,3]
    @test @inferred(getindex(col1, :))   == col1

    @test (col1_copy = copy(col1); col1_copy[3] = col1[1]; col1_copy == Column{:A}([1,2,1]))
    @test (col1_copy = copy(col1); col1_copy[3:-1:2] = col1[2:3]; col1_copy == Column{:A}([1,3,2]))
    @test (col1_copy = copy(col1); col1_copy[:] = col1[:]; col1_copy == Column{:A}([1,2,3]))

    @test (col1_copy = copy(col1); @inbounds col1_copy[3] = col1[1]; col1_copy == Column{:A}([1,2,1]))
    @test (col1_copy = copy(col1); @inbounds col1_copy[3:-1:2] = col1[2:3]; col1_copy == Column{:A}([1,3,2]))
    @test (col1_copy = copy(col1); @inbounds col1_copy[:] = col1[:]; col1_copy == Column{:A}([1,2,3]))

    @test first(col1) == 1
    @test next(col1,start(col1)) == (1, 2)
    @test last(col1) == 3

    @test (col1_copy = copy(col1); col1_copy[2] = 3; col1_copy.data == [1,3,3])
    @test (col1_copy = deepcopy(col1); col1_copy[2] = Cell{:A}(3); col1_copy.data == [1,3,3])
end

@testset "Composing and concatenating" begin
    c1 = @Cell(A = 1)
    c2 = @Cell(A = 2)
    c3 = @Cell(A = 3)
    v1 = [1,2,3]
    col1 = Column{:A}(v1)

    @test @inferred(vcat(c1)) == Column{:A}([1])
    @test @inferred(vcat(c1,c2,c3)) == col1
    @test (vcat(col1,c1)) == @Column A = [1,2,3,1] # inference fails for mixed scalar-vector vcat() (TODO fix upstream?)
    @test (vcat(c1,col1)) == @Column A = [1,1,2,3] # inference fails for mixed scalar-vector vcat() (TODO fix upstream?)
    @test @inferred(vcat(col1,col1)) == @Column A = [1,2,3,1,2,3]
end

end
