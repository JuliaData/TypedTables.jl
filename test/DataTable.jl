@testset "DataTable" begin
    t = @inferred(DataTable(a = [1,2,3], b = [2.0, 4.0, 6.0]))::DataTable{1}

    @test DataTable(t; c = [true,false,true]) == Table(a = [1,2,3], b = [2.0,4.0,6.0], c = [true,false,true])
    @test DataTable(t, Table(c = [true,false,true])) == Table(a = [1,2,3], b = [2.0,4.0,6.0], c = [true,false,true])
    @test DataTable(t; b = nothing) == Table(a = [1,2,3])
end