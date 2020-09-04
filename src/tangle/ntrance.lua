local client

local base64 = {}

local websocketkey

events = {}

iptable = {}

frames = {}

local ignores

local old_namespace

local b64 = 0
for i=string.byte('a'), string.byte('z') do base64[b64] = string.char(i) b64 = b64+1 end
for i=string.byte('A'), string.byte('Z') do base64[b64] = string.char(i) b64 = b64+1 end
for i=string.byte('0'), string.byte('9') do base64[b64] = string.char(i) b64 = b64+1 end
base64[b64] = '+' b64 = b64+1
base64[b64] = '/'


local GenerateWebSocketKey -- we must forward declare local functions because otherwise it picks the global one

local OpAnd, OpOr, OpRshift, OpLshift

local ConvertToBase64

local ConvertBytesToString

local SendText

local OpXor

local nocase

function GenerateWebSocketKey()
	key = {}
	for i =0,15 do
		table.insert(key, math.floor(math.random()*255))
	end
	
	return key
end

function OpAnd(a, b)
	return vim.api.nvim_call_function("and", {a, b})
end

function OpOr(a, b)
	return vim.api.nvim_call_function("or", {a, b})
end

function OpRshift(a, b)
	return math.floor(a/math.pow(2, b))
end

function OpLshift(a, b)
	return a*math.pow(2, b)
end

function ConvertToBase64(array)
	local i
	local str = ""
	for i=0,#array-3,3 do
		local b1 = array[i+0+1]
		local b2 = array[i+1+1]
		local b3 = array[i+2+1]

		local c1 = OpRshift(b1, 2)
		local c2 = OpLshift(OpAnd(b1, 0x3), 4)+OpRshift(b2, 4)
		local c3 = OpLshift(OpAnd(b2, 0xF), 2)+OpRshift(b3, 6)
		local c4 = OpAnd(b3, 0x3F)

		str = str .. base64[c1]
		str = str .. base64[c2]
		str = str .. base64[c3]
		str = str .. base64[c4]
	end

	local rest = #array * 8 - #str * 6
	if rest == 8 then
		local b1 = array[#array]
	
		local c1 = OpRshift(b1, 2)
		local c2 = OpLshift(OpAnd(b1, 0x3), 4)
	
		str = str .. base64[c1]
		str = str .. base64[c2]
		str = str .. "="
		str = str .. "="
	
	elseif rest == 16 then
		local b1 = array[i+0+1]
		local b2 = array[i+1+1]
	
		local c1 = OpRshift(b1, 2)
		local c2 = OpLshift(OpAnd(b1, 0x3), 4)+OpRshift(b2, 4)
		local c3 = OpLshift(OpAnd(b2, 0xF), 2)
	
		str = str .. base64[c1]
		str = str .. base64[c2]
		str = str .. base64[c3]
		str = str .. "="
	end
	

	return str
end

function ConvertBytesToString(tab)
	local s = ""
	for _,el in ipairs(tab) do
		s = s .. string.char(el)
	end
	return s
end

function SendText(str)
	local mask = {}
	for i=1,4 do
		table.insert(mask, math.floor(math.random() * 255))
	end
	
	local masked = {}
	for i=0,#str-1 do
		local j = i%4
		local trans = OpXor(string.byte(string.sub(str, i+1, i+1)), mask[j+1])
		table.insert(masked, trans)
	end
	
	local frame = {
		0x81, 0x80
	}
	
	if #masked <= 125 then
		frame[2] = frame[2] + #masked
	elseif #masked < math.pow(2, 16) then
		frame[2] = frame[2] + 126
		local b1 = OpRshift(#masked, 8)
		local b2 = OpAnd(#masked, 0xFF)
		table.insert(frame, b1)
		table.insert(frame, b2)
	else
		frame[2] = frame[2] + 127
		for i=0,7 do
			local b = OpAnd(OpRshift(#masked, (7-i)*8), 0xFF)
			table.insert(frame, b)
		end
	end
	
	
	for i=1,4 do
		table.insert(frame, mask[i])
	end
	
	for i=1,#masked do
		table.insert(frame, masked[i])
	end
	
	local s = ConvertBytesToString(frame)
	
	client:write(s)
	
end

function OpXor(a, b)
	return vim.api.nvim_call_function("xor", {a, b})
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

local function Refresh()
	vim.b.initialized = false
	table.insert(events, "sending request")
	local encoded = vim.fn.json_encode({
		["type"] = "request",
	})
	SendText(encoded)
	
	
end


function StartClient(first, appuri, port)
	if not vim.g.ntrance_username or string.len(vim.g.ntrance_username) == 0 then
		error("Please specify a username in vim.g.ntrance_username")
	end
	
	vim.b.detach = false
	
	ignores = {}
	
	vim.b.initialized = false
	
	old_namespace = {}
	
	port = port or 80
	
	client = vim.loop.new_tcp()
	iptable = vim.loop.getaddrinfo(appuri)
	if #iptable == 0 then
		print("Could not resolve address")
		return
	end
	local ipentry = iptable[1]
	
	client:connect(ipentry.addr, port, vim.schedule_wrap(function(err) 
		if err then
			table.insert(events, "connection err " .. vim.inspect(err))
			error("There was an error during connection: " .. err)
			return
		end
		
		client:read_start(vim.schedule_wrap(function(err, chunk)
			if err then
				table.insert(events, "connection err " .. vim.inspect(err))
				error("There was an error during connection: " .. err)
			
				local mask = {}
				for i=1,4 do
					table.insert(mask, math.floor(math.random() * 255))
				end
				
				local frame = {
					0x88, 0x80,
				}
				for i=1,4 do 
					table.insert(frame, mask[i])
				end
				local s = ConvertBytesToString(frame)
				
				client:write(s)
				
				
				client:close()
				
			
				return
			end
			table.insert(events, "err: " .. vim.inspect(err) .. " chunk: " .. vim.inspect(chunk))
			
			table.insert(events, chunk)
			if chunk then
				if string.match(chunk, nocase("^HTTP")) then
					-- can be Sec-WebSocket-Accept or Sec-Websocket-Accept
					if string.match(chunk, nocase("Sec%-WebSocket%-Accept")) then
						table.insert(events, "handshake was successful")
						local encoded = vim.fn.json_encode({
							["type"] = "available"
						})
						SendText(encoded)
						
						
					end
				else
					local opcode
					local b1 = string.byte(string.sub(chunk,1,1))
					table.insert(frames, "FIN " .. OpAnd(b1, 0x80))
					table.insert(frames, "OPCODE " .. OpAnd(b1, 0xF))
					local b2 = string.byte(string.sub(chunk,2,2))
					table.insert(frames, "MASK " .. OpAnd(b2, 0x80))
					opcode = OpAnd(b1, 0xF)
					
					if opcode == 0x1 then -- TEXT
						local paylen = OpAnd(b2, 0x7F)
						local paylenlen = 0
						if paylen == 126 then -- 16 bits length
							local b3 = string.byte(string.sub(chunk,3,3))
							local b4 = string.byte(string.sub(chunk,4,4))
							paylen = OpLshift(b3, 8) + b4
							paylenlen = 2
						elseif paylen == 127 then
							paylen = 0
							for i=0,7 do -- 64 bits length
								paylen = OpLshift(paylen, 8) 
								paylen = paylen + string.byte(string.sub(chunk,i+3,i+3))
							end
							paylenlen = 8
						end
						table.insert(frames, "PAYLOAD LENGTH " .. paylen)
						
						local text = string.sub(chunk, 2+paylenlen+1)
						
						local decoded = vim.fn.json_decode(text)
						
						if decoded and vim.b.attached then
							if decoded["type"] == "text" then
								local tick = vim.api.nvim_buf_get_changedtick(vim.api.nvim_get_current_buf())+1
								ignores[tick] = true
								
								local lines = {}
								-- if it's an empty string, fill lines with an empty array
								-- otherwise with gsplit it will put an empty string into
								-- the array like : { "" }
								if string.len(decoded["text"]) == 0 then
									if decoded["start"] == decoded["end"] then -- new line
										lines = { "" }
									elseif decoded["end"] == decoded["last"] then -- just delete line content but keep it
										lines = { "" }
									else -- delete lines
										lines = {}
									end
								else 
									for line in vim.gsplit(decoded["text"], '\n') do
										table.insert(lines, line)
									end
								end
								-- table.insert(events, "set_lines start: " .. decoded["start"] .. " end: " .. decoded["end"] .. " lines: " .. vim.inspect(lines))
								vim.api.nvim_buf_set_lines(
									vim.api.nvim_get_current_buf(), 
									decoded["start"], 
									decoded["end"], 
									false, 
									lines)
								
								if old_namespace[decoded["author"]] then
									vim.api.nvim_buf_clear_namespace(
										vim.api.nvim_get_current_buf(),
										old_namespace[decoded["author"]],
										0, -1)
									old_namespace[decoded["author"]] = nil
								end
								
								old_namespace[decoded["author"]] = 
									vim.api.nvim_buf_set_virtual_text(
										vim.api.nvim_get_current_buf(),
										0, 
										math.max(decoded["last"]-1, 0), 
										{{ " | " .. decoded["author"], "Special" }}, 
										{})
								
							end
							
							if decoded["type"] == "request" then
								local numlines = vim.api.nvim_buf_line_count(vim.api.nvim_get_current_buf())
								
								local lines = vim.api.nvim_buf_get_lines(
									vim.api.nvim_get_current_buf(), 
									0, 
									numlines, 
									true)
								
								local encoded = vim.fn.json_encode({
									["type"] = "initial",
									["text"] = table.concat(lines, '\n')
								})
								
								SendText(encoded)
								
							end
							
							if decoded["type"] == "initial" and not vim.b.initialized then
								local lines = {}
								for line in vim.gsplit(decoded["text"], '\n') do
									table.insert(lines, line)
								end
								
								local tick = vim.api.nvim_buf_get_changedtick(vim.api.nvim_get_current_buf())+1
								ignores[tick] = true
								
								vim.api.nvim_command("normal ggdG")
								
								local tick = vim.api.nvim_buf_get_changedtick(vim.api.nvim_get_current_buf())+1
								ignores[tick] = true
								
								vim.api.nvim_buf_set_lines(
									vim.api.nvim_get_current_buf(), 
									0, 
									#lines, 
									false, 
									lines)
								
								print("Connected!")
								vim.b.initialized = true
							end
							
							if decoded["type"] == "response" then
								if decoded["is_first"] and first then
									print("Connected!")
									vim.b.initialized = true
								elseif not decoded["is_first"] and not first then
									table.insert(events, "sending request")
									local encoded = vim.fn.json_encode({
										["type"] = "request",
									})
									SendText(encoded)
									
									
								elseif decoded["is_first"] and not first then
									table.insert(events, "ERROR: Tried to join an empty server")
									print("ERROR: Tried to join an empty server")
									local mask = {}
									for i=1,4 do
										table.insert(mask, math.floor(math.random() * 255))
									end
									
									local frame = {
										0x88, 0x80,
									}
									for i=1,4 do 
										table.insert(frame, mask[i])
									end
									local s = ConvertBytesToString(frame)
									
									client:write(s)
									
									
									client:close()
									
								elseif not decoded["is_first"] and first then
									table.insert(events, "ERROR: Tried to start a server which is already busy")
									print("ERROR: Tried to start a server which is already busy")
									local mask = {}
									for i=1,4 do
										table.insert(mask, math.floor(math.random() * 255))
									end
									
									local frame = {
										0x88, 0x80,
									}
									for i=1,4 do 
										table.insert(frame, mask[i])
									end
									local s = ConvertBytesToString(frame)
									
									client:write(s)
									
									
									client:close()
									
								end
							end
							
						else
							table.insert(events, "Could not decode json " .. text)
						end
						
					end
					
					if opcode == 0x9 then -- PING
						local paylen = OpAnd(b2, 0x7F)
						local paylenlen = 0
						if paylen == 126 then -- 16 bits length
							local b3 = string.byte(string.sub(chunk,3,3))
							local b4 = string.byte(string.sub(chunk,4,4))
							paylen = OpLshift(b3, 8) + b4
							paylenlen = 2
						elseif paylen == 127 then
							paylen = 0
							for i=0,7 do -- 64 bits length
								paylen = OpLshift(paylen, 8) 
								paylen = paylen + string.byte(string.sub(chunk,i+3,i+3))
							end
							paylenlen = 8
						end
						table.insert(frames, "PAYLOAD LENGTH " .. paylen)
						
						table.insert(frames, "SENT PONG")
						local mask = {}
						for i=1,4 do
							table.insert(mask, math.floor(math.random() * 255))
						end
						
						local frame = {
							0x8A, 0x80,
						}
						for i=1,4 do 
							table.insert(frame, mask[i])
						end
						local s = ConvertBytesToString(frame)
						
						client:write(s)
						
						
					end
					
				end
			end
			
		end))
		client:write("GET / HTTP/1.1\r\n")
		client:write("Host: " .. appuri .. ":" .. port .. "\r\n")
		client:write("Upgrade: websocket\r\n")
		client:write("Connection: Upgrade\r\n")
		websocketkey = ConvertToBase64(GenerateWebSocketKey())
		client:write("Sec-WebSocket-Key: " .. websocketkey .. "\r\n")
		client:write("Sec-WebSocket-Version: 13\r\n")
		client:write("\r\n")
		
	end))
end

local function StopClient()
	local mask = {}
	for i=1,4 do
		table.insert(mask, math.floor(math.random() * 255))
	end
	
	local frame = {
		0x88, 0x80,
	}
	for i=1,4 do 
		table.insert(frame, mask[i])
	end
	local s = ConvertBytesToString(frame)
	
	client:write(s)
	
	
	client:close()
	
end



local function AttachToBuffer()
	local bufnr = vim.api.nvim_get_current_buf()
	
	vim.b.attached = true
	table.insert(events, "Attaching to buffer " .. bufnr)
	vim.api.nvim_buf_attach(bufnr, false, {
		on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
			if vim.b.detach then
				table.insert(events, "Detached from buffer")
				return true
			end
			
			if ignores[changedtick] then
				ignores[changedtick] = nil
				return
			end
			
			local lines = vim.api.nvim_buf_get_lines(bufnr, firstline, new_lastline, true)
			
			local encoded = vim.fn.json_encode({
				["type"] = "text",
				["start"] = firstline,
				["end"]   = lastline,
				["last"]   = new_lastline,
				["author"] = vim.g.ntrance_username,
				["text"] = table.concat(lines, '\n')
			})
			
			SendText(encoded)
			
		end
	})
	
end

local function DetachFromBuffer()
	table.insert(events, "Detaching from buffer...")
	vim.b.detach = true
end


local function Start(first, host, port)
	StartClient(first, host, port)
	AttachToBuffer()
	
end

local function Stop()
	DetachFromBuffer()
	StopClient()
	
end


return {
Start = Start,
Stop = Stop,

Refresh = Refresh,

}

