local base64 = require("instant.base64")

local bit = require("bit")

events = {}

local GenerateWebSocketKey -- we must forward declare local functions because otherwise it picks the global one

local nocase

local send_text

local maskText

local convert_bytes_to_string

function GenerateWebSocketKey()
	key = {}
	math.randomseed(os.time())
	for i =0,15 do
		table.insert(key, math.random(0, 255))
	end
	
	return key
end

function nocase (s)
	s = string.gsub(s, "%a", function (c)
		if string.match(c, "[a-zA-Z]") then
			return string.format("[%s%s]", 
				string.lower(c),
				string.upper(c))
		else
			return c
		end
	end)
	return s
end

function maskText(str, mask)
	local masked = {}
	for i=0,#str-1 do
		local j = bit.band(i, 0x3)
		local trans = bit.bxor(string.byte(string.sub(str, i+1, i+1)), mask[j+1])
		table.insert(masked, trans)
	end
	return masked
end

function convert_bytes_to_string(tab)
	local s = ""
	for _,el in ipairs(tab) do
		s = s .. string.char(el)
	end
	return s
end


local function WebSocketClient(opt)
	local iptable = vim.loop.getaddrinfo(opt.uri)
	if #iptable == 0 then
		print("Could not resolve address")
		return
	end
	local ipentry = iptable[1]
	
	local port = opt.port or 80
	
	local client = vim.loop.new_tcp()
	

	local websocketkey
	local handshake_sent = false
	
	local frames = {}
	local fragmented = ""
	local remaining = 0
	local first_chunk
	local upgraded = false
	local http_chunk = ""
	
	local wsdata = ""
	local opcode
	
	local on_disconnect
	
	local max_before_frag = opt.max_before_frag or 8192
	
	local ws = {}
	function ws:connect(callbacks)
		local ret, err = client:connect(ipentry.addr, port, vim.schedule_wrap(function(err) 
			on_disconnect = callbacks.on_disconnect
			
			if err then
				if on_disconnect then
					on_disconnect()
				end
				
				error("There was an error during connection: " .. err)
				return
			end
			
			client:read_start(vim.schedule_wrap(function(err, chunk)
				if err then
					if on_disconnect then
						on_disconnect()
					end
					
					error("There was an error during connection: " .. err)
					return
				end
				
				if chunk then
					if not upgraded then
						http_chunk = http_chunk .. chunk
						if string.match(http_chunk, "\r\n\r\n$") then
							if string.match(http_chunk, nocase("^HTTP")) then
								-- can be Sec-WebSocket-Accept or Sec-Websocket-Accept
								if string.match(http_chunk, nocase("Sec%-WebSocket%-Accept")) then
									if callbacks.on_connect then
										callbacks.on_connect()
									end
									
									upgraded = true
								end
							end
							http_chunk = ""
						end
					else
						local fin
						-- if multiple tcp packets are 
						-- sent at once
						while string.len(chunk) > 0 do
							-- if tcp packets are sent
							-- fragmented
							if remaining == 0 then
								first_chunk = chunk
							end
							local b1 = string.byte(string.sub(first_chunk,1,1))
							local b2 = string.byte(string.sub(first_chunk,2,2))
							if string.len(wsdata) == 0 then
								opcode = bit.band(b1, 0xF)
							end
							fin = bit.rshift(b1, 7)
							
							if opcode == 0x1 then -- TEXT
								local paylen = bit.band(b2, 0x7F)
								local paylenlen = 0
								if paylen == 126 then -- 16 bits length
									local b3 = string.byte(string.sub(first_chunk,3,3))
									local b4 = string.byte(string.sub(first_chunk,4,4))
									paylen = bit.lshift(b3, 8) + b4
									paylenlen = 2
								elseif paylen == 127 then
									paylen = 0
									for i=0,7 do -- 64 bits length
										paylen = bit.lshift(paylen, 8) 
										paylen = paylen + string.byte(string.sub(first_chunk,i+3,i+3))
									end
									paylenlen = 8
								end
								
								if remaining == 0 then
									local text = string.sub(chunk, 2+paylenlen+1, 2+paylenlen+1+(paylen-1))
									
									chunk = string.sub(chunk, 2+paylenlen+1+paylen)
									fragmented = text
									remaining = paylen - string.len(text)
								else
									local rest = math.min(remaining, string.len(chunk))
									fragmented = fragmented .. string.sub(chunk, 1, rest)
									remaining = remaining - rest
									chunk = string.sub(chunk, rest+1)
								end
							
								if remaining == 0 then
									wsdata = wsdata .. fragmented
									if fin ~= 0 then
										if callbacks.on_text then
											callbacks.on_text(wsdata)
										end
										
										wsdata = ""
									end
								end
							
							elseif opcode == 0x9 then -- PING
								local paylen = bit.band(b2, 0x7F)
								local paylenlen = 0
								if paylen == 126 then -- 16 bits length
									local b3 = string.byte(string.sub(first_chunk,3,3))
									local b4 = string.byte(string.sub(first_chunk,4,4))
									paylen = bit.lshift(b3, 8) + b4
									paylenlen = 2
								elseif paylen == 127 then
									paylen = 0
									for i=0,7 do -- 64 bits length
										paylen = bit.lshift(paylen, 8) 
										paylen = paylen + string.byte(string.sub(first_chunk,i+3,i+3))
									end
									paylenlen = 8
								end
								
								local mask = {}
								for i=1,4 do
									table.insert(mask, math.random(0, 255))
								end
								
								local frame = {
									0x8A, 0x80,
								}
								for i=1,4 do 
									table.insert(frame, mask[i])
								end
								local s = convert_bytes_to_string(frame)
								
								client:write(s)
								
								
								chunk = ""
							
							else 
								chunk = ""
								remaining = 0
							end
						end
					end
					
				end
			end))
			client:write("GET / HTTP/1.1\r\n")
			client:write("Host: " .. opt.uri .. ":" .. port .. "\r\n")
			client:write("Upgrade: websocket\r\n")
			client:write("Connection: Upgrade\r\n")
			websocketkey = base64.encode(GenerateWebSocketKey())
			client:write("Sec-WebSocket-Key: " .. websocketkey .. "\r\n")
			client:write("Sec-WebSocket-Version: 13\r\n")
			client:write("\r\n")
			
		end))
	
		if not ret then
			error(err)
		end
	end
	
	function ws:disconnect()
		local mask = {}
		for i=1,4 do
			table.insert(mask, math.random(0, 255))
		end
		
		local frame = {
			0x88, 0x80,
		}
		for i=1,4 do 
			table.insert(frame, mask[i])
		end
		local s = convert_bytes_to_string(frame)
		
		client:write(s)
		
		
		client:close()
		client = nil
		
		if on_disconnect then
			on_disconnect()
		end
		
	end
	
	function ws:send_text(str)
		local mask = {}
		for i=1,4 do
			table.insert(mask, math.random(0, 255))
		end
		
		local masked = maskText(str, mask)
		
	
		local remain = #masked
		local sent = 0
		while remain > 0 do
			local send = math.min(max_before_frag, remain) -- max size before fragment
			remain = remain - send
			local fin
			if remain == 0 then fin = 0x80
			else fin = 0 end
			
			local opcode
			if sent == 0 then opcode = 1
			else opcode = 0 end
			
			
			local frame = {
				fin+opcode, 0x80
			}
			
			if send <= 125 then
				frame[2] = frame[2] + send
			elseif send < math.pow(2, 16) then
				frame[2] = frame[2] + 126
				local b1 = bit.rshift(send, 8)
				local b2 = bit.band(send, 0xFF)
				table.insert(frame, b1)
				table.insert(frame, b2)
			else
				frame[2] = frame[2] + 127
				for i=0,7 do
					local b = bit.band(bit.rshift(send, (7-i)*8), 0xFF)
					table.insert(frame, b)
				end
			end
			
			
			for i=1,4 do
				table.insert(frame, mask[i])
			end
			
			for i=sent+1,sent+1+(send-1) do
				table.insert(frame, masked[i])
			end
			
			local s = convert_bytes_to_string(frame)
			
			client:write(s)
			
			sent = sent + send
		end
	end
	
	
	function ws:is_active()
		return client and client:is_active()
	end

	return setmetatable({}, { __index = ws})
end

return WebSocketClient

