@testset "Property interface" begin
    @test @inferred(getproperty(:b)((a=1,b=2.0,c=false))) === 2.0

    @test @inferred(getproperties(:b)((a=1,b=2.0,c=false))) === (b = 2.0,)
end