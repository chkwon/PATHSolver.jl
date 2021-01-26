using Test

@testset "PATH" begin
    @testset "$(file)" for file in ["C_API.jl", "MOI_wrapper.jl"]
        println("Running: $(file)")
        include(file)
    end
end
