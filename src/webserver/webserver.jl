# Minimal server using the 'listen' syntax, starting with the 'inner' functions
using Sockets
using WebSockets
using DelimitedFiles, LuxurySparse
import WebSockets.handle

export run_server, naive_handler

include("webparse.jl")

struct YaoWSInfo
    LOCALIP
    PORT
    state
end

function coroutine(ws, state)
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

function gatekeeper(req, ws, info)
    orig = WebSockets.origin(req)
    println("\nOrigin:", orig, "    Target:", target(req), "    subprotocol:", subprotocol(req))
    if occursin(info.LOCALIP, orig)
        coroutine(ws, info.state)
    else
        @info "Non-browser clients don't send Origin. We liberally accept the update request in this case."
        coroutine(ws, info.state)
    end
end

function run_server(handler;
    LOCALIP = string(Sockets.getipaddr()),
    PORT::Int=8080,
    )
    @info("Browser > $LOCALIP:$PORT , F12> console > ws = new WebSocket(\"ws://$LOCALIP:$PORT\") ")

    info = YaoWSInfo(LOCALIP, PORT, YaoWSState())
    handler_wrap = WebSockets.RequestHandlerFunction(req->handler(req, info))
    SERVER = Sockets.listen(Sockets.InetAddr(parse(IPAddr, LOCALIP), PORT))
    @async try
        WebSockets.HTTP.listen(LOCALIP, PORT, server = SERVER, readtimeout = 0 ) do http
            if WebSockets.is_upgrade(http.message)
                WebSockets.upgrade((req, ws)->gatekeeper(req, ws, info), http)
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

function naive_handler(req, info)
    BAREHTML = "<head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\">
    <title>Empty.html</title></head><body></body></html>"

    LOCALIP = info.LOCALIP
    PORT = info.PORT
    BODY =  "<body><p>Press F12
                <p>ws = new WebSocket(\"ws://$LOCALIP:$PORT\")
                <p>ws.onmessage = function(e){console.log(e.data)}
                <p>ws.send(\"hello!\")
                </body>"

    replace(BAREHTML, "<body></body>" => BODY) |> WebSockets.Response
end
