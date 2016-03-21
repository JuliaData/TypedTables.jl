@testset "Input and output" begin

@test begin
    index = @index(A::Int, B::Float64)
    x = Dict{Symbol, Vector}()
    x[:A] = [1,2,3]
    x[:B] = [2.0,4.0,6.0]
    table = readtable(index, x)
    table == @table(A::Int=[1,2,3], B::Float64=[2.0,4.0,6.0])
end

@test begin
    index = @index(A::Int,B::Float64,C::ASCIIString,D::Bool)
    fileio = open("data1.csv")
    table = readtable(index, fileio, header = true)
    close(fileio)
    table == @table(A::Int=[1,2,3],B::Float64=[2.0,4.0,6.0],C::ASCIIString=["A","AB","ABC"],D::Bool=[true,false,true])
end

end
