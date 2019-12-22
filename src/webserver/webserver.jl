# Minimal server using the 'listen' syntax, starting with the 'inner' functions
using Sockets
using WebSockets
using DelimitedFiles, LuxurySparse
import WebSockets.handle

export run_server, naive_handler

include("webparse.jl")

function coroutine(ws)
    state = YaoWSState()
    while isopen(ws)
        data, = readguarded(ws)
        s = String(data)
        println("Received: ", s)
        if strip(s) == "q"
            writeguarded(ws, "Goodbye!")
            break
        end
        try
            msg = yaoweb_handler(s, state)
            writeguarded(ws, string(msg))
        catch err
            writeguarded(ws, string(err))
        end
    end
end

function gatekeeper(req, ws)
    orig = WebSockets.origin(req)
    println("\nOrigin:", orig, "    Target:", target(req), "    subprotocol:", subprotocol(req))
    @show dump(ws), dump(req)
    if occursin(WEBCONFIG[:LOCALIP], orig)
        coroutine(ws)
    else
        @info "Non-browser clients don't send Origin. We liberally accept the update request in this case."
        coroutine(ws)
    end
end

function run_server(handler)
    LOCALIP = WEBCONFIG[:LOCALIP]
    PORT = WEBCONFIG[:PORT]
    @info("Browser > $LOCALIP:$PORT , F12> console > ws = new WebSocket(\"ws://$LOCALIP:$PORT\") ")

    handler_wrap = WebSockets.RequestHandlerFunction(req->handler(req))
    SERVER = Sockets.listen(Sockets.InetAddr(parse(IPAddr, LOCALIP), PORT))
    @async try
        WebSockets.HTTP.listen(LOCALIP, PORT, server = SERVER, readtimeout = 0 ) do http
            if WebSockets.is_upgrade(http.message)
                WebSockets.upgrade((req, ws)->gatekeeper(req, ws), http)
            else
                handle(handler_wrap, http)
            end
        end
    catch err
        # Add your own error handling code; HTTP.jl sends error code to the client.
        @info err
        @info stacktrace(catch_backtrace())
    end
    @info("To stop serving: close(SERVER)")
    return SERVER
end

function naive_handler(req)
    BAREHTML = "<head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\">
    <title>Empty.html</title></head><body></body></html>"

    LOCALIP = WEBCONFIG[:LOCALIP]
    PORT = WEBCONFIG[:PORT]
    BODY =  "<body><p>Press F12
                <p>ws = new WebSocket(\"ws://$LOCALIP:$PORT\")
                <p>ws.onmessage = function(e){console.log(e.data)}
                <p>ws.send(\"hello!\")
                </body>"

    replace(BAREHTML, "<body></body>" => BODY) |> WebSockets.Response
end
