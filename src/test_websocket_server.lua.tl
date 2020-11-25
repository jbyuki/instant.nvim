@*=
@requires
@script_variables
@listen_server

@requires+=
local websocket_server = require("instant.websocket_server")

@listen_server+=
local ws_server = websocket_server {}
ws_server:listen {
	on_connect = function(conn) 
		num_connected = num_connected + 1
		table.insert(events, "Peer connected!")
		@client_connected
	end
}
table.insert(events, "starting ...")
print("Server is listening on port 8080...")

@script_variables+=
events = {}
local num_connected = 0

@client_connected+=
conn:attach {
	on_text = function(data)
		@decode_message
		if decoded then
			@if_request_send_to_first_client_in_list
			@if_text_broadcast_to_others
			@if_initial_broadcast_to_others
			@if_available_send_response_back
			@if_data_send_to_other_clients
		end
	end,
	on_disconnect = function()
		@remove_client_from_clients
		num_connected = num_connected - 1
		table.insert(events, num_connected .. " client(s) remaining.")
		@check_if_no_more_peer
		@send_client_disconnect
	end,
}
