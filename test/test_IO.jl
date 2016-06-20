@testset "Input and output" begin

@test begin
    x = Dict{Symbol, Vector}()
    x[:A] = [1,2,3]
    x[:B] = [2.0,4.0,6.0]
    table = readtable(Val{(:A,:B)}, x)
    table == @Table(A=[1,2,3], B=[2.0,4.0,6.0])
end

@test begin
    fileio = open("data1.csv")
    table = readtable(Table{(:A,:B,:C,:D),Tuple{Vector{Int},Vector{Float64},Vector{ASCIIString},Vector{Bool}}}, fileio, header = true)
    close(fileio)
    table == @Table(A=[1,2,3], B=[2.0,4.0,6.0], C=["A","AB","ABC"], D=[true,false,true])
end

end
