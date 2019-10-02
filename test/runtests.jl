using PATH, Test

@testset "PATH" begin
    @testset "$(file)" for file in ["C_API.jl", "MOI_wrapper.jl"]
        include(file)
    end
end
