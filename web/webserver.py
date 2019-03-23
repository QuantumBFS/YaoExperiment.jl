import logging, re
from websocket_server import WebsocketServer

IP = '127.0.0.1'
PORT = 13254
PRI_KEY = "12345678"
def match_key(KEY):
    if KEY == PRI_KEY:
        return True
    else:
        return False

def on_connect(client, server):
    print("New Client %d Joined!"%client['id'])

def on_disconnect(client, server):
    print("Client %d Left!"%client['id'])

def on_message(client, server, message):
    print("RECEIVED:", message)
    if client.get("authenticated"):
        ret = do_message(message)
        server.send_message(client, ret)
    else:
        res = re.match(r"AUTH:([A-Za-z0-9@#$%^&+=]{8,})", message)
        if res:
            if match_key(res.group(1)):
                client["authenticated"] = True
                ret = "SUCCESS"
            else:
                ret = "FAIL"
        else:
            ret = "NAN"
        server.send_message(client, "AUTH:%s"%ret)

def do_message(message):
    print("handling: ", message)
    return "successfully handled: %s"%message

server = WebsocketServer(PORT, host=IP, loglevel=logging.INFO)
server.set_fn_new_client(on_connect)
server.set_fn_client_left(on_disconnect)
server.set_fn_message_received(on_message)

server.run_forever()
