@../lua/instant/server.lua=
@requires
@script_variables
local MSG_TYPE = {
@message_types
}
@declare_functions
@functions

return {
	@export_symbols
}

@requires+=
local websocket_server = require("instant.websocket_server")

@script_variables+=
local num_connected = 0
local ws_server

@export_symbols+=
StartServer = StartServer,

@functions+=
local function StartServer(host, port)
	local host = host or "127.0.0.1"
	local port = port or 8080

	ws_server = websocket_server { host = host, port = port }

	ws_server:listen {
		on_connect = function(conn) 
			num_connected = num_connected + 1
			print("Peer connected! " .. num_connected .. " connected.")
			@notify_peer_connected
			@client_connected
		end
	}
	print("Server is listening on port " .. port .. "...")
end

@client_connected+=
conn:attach {
	on_text = function(wsdata)
		vim.schedule(function()
			@decode_json
			if decoded then
				@if_text_broadcast_to_others
				@if_request_send_to_first_client_in_list
				@if_initial_broadcast_to_others
				@if_available_send_response_back
				@if_data_send_to_other_clients
				else 
					table.insert(events, "Unknown message " .. vim.inspect(decoded))
				end
			end
		end)
	end,
	on_disconnect = function()
		vim.schedule(function()
			num_connected = math.max(num_connected - 1, 0)
			print("Disconnected. " .. num_connected .. " client(s) remaining.")
			@check_if_no_more_peer
			@send_client_disconnect
		end)
	end,
}

@message_types+=
TEXT = 1,
AVAILABLE = 2,
REQUEST = 3,
INITIAL = 6,
INFO = 5,
CONNECT = 7,
DISCONNECT = 8,
DATA = 9,

@decode_json+=
local decoded = vim.api.nvim_call_function("json_decode", {  wsdata })

@if_text_broadcast_to_others+=
if decoded[1] == MSG_TYPE.TEXT then
	for id, client in pairs(ws_server.conns) do
		if id ~= conn.id then
			client:send_text(wsdata)
		end
	end

@if_request_send_to_first_client_in_list+=
elseif decoded[1] == MSG_TYPE.REQUEST then
	if num_connected > 1 then
		-- only send request to one other client
		for id, client in pairs(ws_server.conns) do
			if id ~= conn.id then
				client:send_text(wsdata)
				break
			end
		end
	end

@if_initial_broadcast_to_others+=
elseif decoded[1] == MSG_TYPE.INITIAL then
	for id, client in pairs(ws_server.conns) do
		if id ~= conn.id then
			client:send_text(wsdata)
		end
	end

@script_variables+=
local is_initialized = false
local session_share = false

@if_available_send_response_back+=
elseif decoded[1] == MSG_TYPE.INFO then
	if not is_initialized then
		session_share = decoded[2]
		is_initialized = true
	end

	local response = {
		MSG_TYPE.AVAILABLE,
		num_connected == 1,
		conn.id,
		session_share
	}

	@send_current_connected_client_to_client
	@send_client_connect_to_other_clients
	@save_client_id

	conn:send_json(response);

@check_if_no_more_peer+=
if num_connected  == 0 then
	is_initialized = false
end

@send_client_connect_to_other_clients+=
connect = {
	MSG_TYPE.CONNECT,
	conn.id,
	decoded[3],
}

for id, client in pairs(ws_server.conns) do
	if id ~= conn.id then
		client:send_json(connect)
	end
end

@script_variables+=
local usernames = {}

@save_client_id+=
usernames[conn.id] = decoded[3]

@send_client_disconnect+=
usernames[conn.id] = nil

local disconnect = {
	MSG_TYPE.DISCONNECT,
	conn.id,
}

for id, client in pairs(ws_server.conns) do
	if id ~= conn.id then
		client:send_json(disconnect)
	end
end

@send_current_connected_client_to_client+=
for id, name in pairs(usernames) do
	local connect = { MSG_TYPE.CONNECT, id, name }
	conn:send_json(connect);
end

@if_data_send_to_other_clients+=
elseif decoded[1] == MSG_TYPE.DATA then
	for id, client in pairs(ws_server.conns) do
		if id ~= conn.id then
			client:send_text(wsdata)
		end
	end

@functions+=
local function StopServer()
	vim.schedule(function() 
		ws_server:close()
		num_connected = 0
		is_initialized = false
		print("Server shutdown.") 
	end)
end

@export_symbols+=
StopServer = StopServer,
