# Copyright (c) 2016 Changhyun Kwon, Oscar Dowson, and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

import Pkg
Pkg.pkg"add MathOptInterface#od/nlp-expr"

using Test

@testset "PATH" begin
    @testset "$(file)" for file in ["C_API.jl", "MOI_wrapper.jl"]
        println("Running: $(file)")
        include(file)
    end
end
