include_relative(x) = haskey(ENV, "JULIAHUB_APP_URL") ? include(joinpath(pwd(), "bin", x)) : include(x)

include_relative("httpserver.jl")

httpserver.bootServer()