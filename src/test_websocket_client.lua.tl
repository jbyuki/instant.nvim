@*=
@requires
@start_client

@requires+=
local websocket_client = require("instant.websocket_client")

@start_client+=
local ws_client = websocket_client { uri = "127.0.0.1", port = 8080 }
ws_client:connect {
	on_connect = function()
		print("Connected!")
	end,
	on_text = function(wsdata)
		print("wsdata " .. wsdata)
	end,
	on_disconnect = function()
		print("Disconnected.")
	end
}
