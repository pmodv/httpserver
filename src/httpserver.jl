using HTTP

function bootServer()
    @info "Booting Server"
    server_ref[] = HTTP.serve!(dispatch, "0.0.0.0", 8080)
    wait(server_ref[])
end