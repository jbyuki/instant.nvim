-- Generated using ntangle.nvim
local num_connected = 0
local ws_server

local is_initialized = false
local session_share = false

local usernames = {}

local log_filename
if vim.g.debug_instant then
  log_filename = vim.fn.stdpath('data') .. "/instant.log"
end

local log

local function StartServer(host, port)
	local host = host or "127.0.0.1"
	local port = port or 8080

	ws_server = websocket_server { host = host, port = port }

	ws_server:listen {
		on_connect = function(conn) 
			num_connected = num_connected + 1
      vim.schedule(function()
        print("Peer connected! " .. num_connected .. " connected.")
        log("Peer connected! ", num_connected)
      end)
			conn:attach {
				on_text = function(wsdata)
					vim.schedule(function()
						local decoded = vim.api.nvim_call_function("json_decode", {  wsdata })

						if decoded then
			        log("Receive ", vim.inspect(decoded))
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
											client:send_text(wsdata)
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

			        elseif decoded[1] == MSG_TYPE.MARK then
			        	for id, client in pairs(ws_server.conns) do
			        		if id ~= conn.id then
			        			client:send_text(wsdata)
			        		end
			        	end
							else 
								error("Unknown message " .. vim.inspect(decoded))
							end
						end
					end)
				end,
				on_disconnect = function()
					vim.schedule(function()
						num_connected = math.max(num_connected - 1, 0)
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
  log("Server on port ", port)
end

local function StopServer()
	vim.schedule(function() 
		ws_server:close()
		num_connected = 0
    usernames = {}
		is_initialized = false
		print("Server shutdown.") 
	end)
end

function log(...)
  if log_filename then
    vim.schedule(function()
      local elems = { ... }
      for i=1,#elems do
        elems[i] = tostring(elems[i])
      end

      local line table.concat(elems, " ")
        local f = io.open(log_filename, "a")
        if f then
          f:write(line .. "\n")
          f:close()
        end
      end
    end)
  end
end

return log

