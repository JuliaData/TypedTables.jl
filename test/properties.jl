@testset "Property interface" begin
    nt = (a=1, b=2.0, c=false, d=:abc)

    @test @inferred((x -> getproperty(:b)(x))(nt)) === 2.0

    @test @inferred((x -> getproperties(x, (:a, :c)))(nt)) === (a = 1, c = false)
    @test @inferred((x -> getproperties((:a, :c))(x))(nt)) === (a = 1, c = false)

    if VERSION >= v"1.1" 
        @test @inferred((x -> deleteproperty(x, :b))(nt)) === (a = 1, c = false, d = :abc)
        @test @inferred((x -> deleteproperties(x, (:b, :d)))(nt)) === (a = 1, c = false)
    else
        # Inference doesn't seem to handle this on Julia 1.0 (but can on 1.1)
        @test (x -> deleteproperty(x, :b))(nt) === (a = 1, c = false, d = :abc)
        @test (x -> deleteproperties(x, (:b, :d)))(nt) === (a = 1, c = false)
    end

    c1 = @Compute($b)
    @test c1 isa TypedTables.GetProperty
    @test @inferred(c1(nt)) === 2.0

    c2 = @Compute(2*$b)
    @test @inferred(c2(nt)) === 4.0

    c3 = @Compute($a + 2*$b)
    @test @inferred(c3(nt)) === 5.0

    s1 = @Select(a)
    @test s1 isa TypedTables.GetProperties
    @test @inferred(s1(nt)) === (a = 1,)

    s2 = @Select(c,b,a)
    @test s1 isa TypedTables.GetProperties
    @test @inferred(s2(nt)) === (c = false, b = 2.0, a = 1)

    s3 = @Select(a, c = $c, d = $a + 2*$b)
    @test @inferred(s3(nt)) === (a = 1, c = false, d = 5.0)
end

@testset "documented property and macro contracts" begin
    row = (a=1, b=2, c=true)
    @test TypedTables.propertytype(row) === identity
    @test_throws ErrorException deleteproperty(row,:absent)
    @test (@Compute(abs($a)))(row) == 1
    @test (@Compute($a + $b))(row) == 3
    @test (@Compute($a + $a + 1))(row) == 3
    @test (@Compute($c && $a < $b))(row) == true
    @test (@Select(renamed=$a,total=$a+$a+$b))(row) == (renamed=1,total=4)
    table=Table(a=[1,2,3],b=[2,4,6],c=[true,false,true])
    pair=@Compute($a + $b)
    general=@Compute($a + $b + ($c ? 1 : 0))
    predicate=@Compute($c && $a < $b)
    @test map(pair,table)==[3,6,9]
    @test broadcast(pair,table)==[3,6,9]
    @test map(general,table)==[4,6,10]
    @test collect(TypedTables.mapview(general,table))==[4,6,10]
    @test broadcast(general,table)==[4,6,10]
    @test mapreduce(general,+,table)==20
    @test findall(predicate,table)==[1,3]
    @test map(identity,table)==table
    @test map(identity,table).a !== table.a
    @test map(merge,table)==table
    @test map(merge,table).a !== table.a
    @test TypedTables.mapview(merge,table)===table
    for T in (Table, FlexTable)
        @test Tables.istable(T) === true
        @test Tables.rowaccess(T) === true
        @test Tables.columnaccess(T) === true
    end
end
