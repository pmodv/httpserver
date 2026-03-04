using HTTP
using JSON3

# ---------------------------------------------------------------------------
# Model definition
# mutable because we update the field value of an existing struct in this server
# ---------------------------------------------------------------------------

mutable struct Model
    x::Int32
end

# ---------------------------------------------------------------------------
# Business logic helpers
# ---------------------------------------------------------------------------

function simulate(a::Int32)
    model_local = Model(a)
    println("Simulation Complete for model with parameter ", model_local.x)
end

function setValue!(m::Model, a::Int32)
    m.x = a          # mutate existing model
    return m.x
end

getValue(m::Model) = m.x
getModel(m::Model) = m

# ---------------------------------------------------------------------------
# Global model instance (default value 3000)
# ---------------------------------------------------------------------------

const model = Model(3000)

# ---------------------------------------------------------------------------
# Router
# ---------------------------------------------------------------------------

const ROUTER = HTTP.Router()

# GET /set/{x}  — update model value, return old and new
function handle_set(req::HTTP.Request)
    # Extract path parameter from the URL  e.g. /set/42
    x_str = HTTP.URIs.splitpath(req.target)[2]   # ["set", "42"]
    x = Int32(parse(Int, x_str))

    prior = getValue(model)
    new_val = setValue!(model, x)
    println("New model created with field value ", new_val)

    body = Dict("New model value is" => new_val,
                "Prior model value was" => prior)
    return HTTP.Response(200,
        ["Content-Type" => "application/json"],
        JSON3.write(body))
end

# GET /get  — return current model and its type
function handle_get(req::HTTP.Request)
    current = getModel(model)
    body = Dict("Model is" => Dict("x" => current.x),
                "Model type is:" => string(typeof(model)))
    return HTTP.Response(200,
        ["Content-Type" => "application/json"],
        JSON3.write(body))
end

# POST /check  — return model if its value matches the posted value
function handle_check(req::HTTP.Request)
    payload = JSON3.read(String(req.body))
    search_value = Int32(payload[:value])

    if isequal(search_value, getValue(model))
        println("Model is available for value ", search_value)
        body = Dict("Available model is:" => Dict("x" => model.x),
                    "Model type is:" => string(typeof(model)))
        return HTTP.Response(200,
            ["Content-Type" => "application/json"],
            JSON3.write(body))
    else
        println("Model with value ", search_value, " does not exist.")
        body = Dict("Error" => "Queried model does not exist")
        return HTTP.Response(404,
            ["Content-Type" => "application/json"],
            JSON3.write(body))
    end
end

# GET /simulate/{x}  — run simulation with given parameter
function handle_simulate(req::HTTP.Request)
    x_str = HTTP.URIs.splitpath(req.target)[2]
    x = Int32(parse(Int, x_str))
    simulate(x)
    body = Dict("Simulation State:" => "Simulation executed")
    return HTTP.Response(200,
        ["Content-Type" => "application/json"],
        JSON3.write(body))
end

# GET /kill  — graceful shutdown
const server_ref = Ref{Any}(nothing)

function handle_kill(req::HTTP.Request)
    @async begin
        sleep(0.1)
        close(server_ref[])
    end
    return HTTP.Response(200, "Server is Shutdown")
end

# Default 404 handler
function handle_404(req::HTTP.Request)
    return HTTP.Response(404, "This endpoint does not exist")
end

# ---------------------------------------------------------------------------
# Register routes
# ---------------------------------------------------------------------------

HTTP.register!(ROUTER, "GET",  "/set/{x}",    handle_set)
HTTP.register!(ROUTER, "GET",  "/get",         handle_get)
HTTP.register!(ROUTER, "POST", "/check",       handle_check)
HTTP.register!(ROUTER, "GET",  "/simulate/{x}",handle_simulate)
HTTP.register!(ROUTER, "GET",  "/kill",        handle_kill)

# Catch-all for unmatched routes
function dispatch(req::HTTP.Request)
    try
        return ROUTER(req)
    catch e
        if isa(e, HTTP.Exceptions.HTTPError)
            rethrow()
        end
        return handle_404(req)
    end
end

# ---------------------------------------------------------------------------
# Start server
# ---------------------------------------------------------------------------

println("Starting server on 0.0.0.0:8080 ...")
server_ref[] = HTTP.serve!(dispatch, "0.0.0.0", 8080)
wait(server_ref[])
println("Server stopped.")