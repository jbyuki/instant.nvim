local websocket_server = require("instant.websocket_server")

local num_connected = 0
local ws_server

local is_initialized = false
local session_share = false

local usernames = {}

local MSG_TYPE = {
TEXT = 1,
AVAILABLE = 2,
REQUEST = 3,
INITIAL = 6,
INFO = 5,
CONNECT = 7,
DISCONNECT = 8,
DATA = 9,

}
local function StartServer(host, port)
	local host = host or "127.0.0.1"
	local port = port or 8080

	ws_server = websocket_server { host = host, port = port }

	ws_server:listen {
		on_connect = function(conn) 
			num_connected = num_connected + 1
			print("Peer connected! " .. num_connected .. " connected.")
			conn:attach {
				on_text = function(wsdata)
					vim.schedule(function()
						local decoded = vim.api.nvim_call_function("json_decode", {  wsdata })
						table.insert(events, "MSG " .. vim.inspect(decoded))
						
						if decoded then
							if decoded[1] == MSG_TYPE.TEXT then
								for id, client in pairs(ws_server.conns) do
									if id ~= conn.id then
										client:send_text(wsdata)
									end
								end
							
							elseif decoded[1] == MSG_TYPE.REQUEST then
								if num_connected > 1 then
									-- only send request to one other client
									for id, client in pairs(ws_server.conns) do
										if id ~= conn.id then
											table.insert(events, "sending to " .. id)
											client:send_text(wsdata)
											table.insert(events, "done")
											break
										end
									end
								end
							
							elseif decoded[1] == MSG_TYPE.INITIAL then
								for id, client in pairs(ws_server.conns) do
									if id ~= conn.id then
										client:send_text(wsdata)
									end
								end
							
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
							
								for id, name in pairs(usernames) do
									local connect = { MSG_TYPE.CONNECT, id, name }
									conn:send_json(connect);
								end
								
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
								
								usernames[conn.id] = decoded[3]
								
							
								conn:send_json(response);
							
							elseif decoded[1] == MSG_TYPE.DATA then
								for id, client in pairs(ws_server.conns) do
									if id ~= conn.id then
										client:send_text(wsdata)
									end
								end
							
							else 
								table.insert(events, "Unknown message " .. vim.inspect(decoded))
							end
						end
					end)
				end,
				on_disconnect = function()
					vim.schedule(function()
						num_connected = num_connected - 1
						print("Disconnected. " .. num_connected .. " client(s) remaining.")
						if num_connected  == 0 then
							is_initialized = false
						end
						
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
						
					end)
				end,
			}
			
		end
	}
	print("Server is listening on port " .. port .. "...")
end

local function StopServer()
	ws_server:close()
	vim.schedule(function() print("Server shutdown.") end)
end


return {
	StartServer = StartServer,
	
	StopServer = StopServer,
}

