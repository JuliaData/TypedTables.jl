using TypedTables
using NullableArrays

if VERSION >= v"0.5-"
    using Base.Test
else
    using BaseTestNext
    const Test = BaseTestNext
end

@testset "Tables tests" begin

include("test_cell.jl")
include("test_column.jl")
include("test_row.jl")
include("test_table.jl")

#include("test_join.jl")
include("test_setalgorithms.jl")
include("test_IO.jl")

end
