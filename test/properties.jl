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