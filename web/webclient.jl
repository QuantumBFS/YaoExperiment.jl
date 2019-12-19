using WebSockets

const IP = "0.0.0.0"
const PORT = 8000
const KEY = "12345678"

function do_auth_res(data)
    @show data
    data == "AUTH:SUCCESS"
end

function do_handle_res(data)
    @show data
end

function send_message(message, ws_client)
    writeguarded(ws_client, "AUTH:$KEY")
    data, success = readguarded(ws_client)
    if !do_auth_res(data |> String)
        println("authentication fail!")
        return
    end
    writeguarded(ws_client, message)
    data, success = readguarded(ws_client)
    do_handle_res(data |> String)
end

send_message(message) = x->send_message(message, x)

MSG = "CNOT 0 1"
ws = WebSockets.open(send_message(MSG), "ws://$IP:$PORT")
