local client

local base64 = {}

local websocketkey

events = {}

iptable = {}

frames = {}

-- this global variable can be set to a local scope once 
-- autocommands registration is natively supported in
-- lua
has_attached = {} 

local detach = {}

local queue

local ignores = {}

local single_buffer

local InstantRoot

local initialized

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

local writeChanges

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
	initialized = false
	table.insert(events, "sending request")
	local encoded = vim.fn.json_encode({
		["type"] = "request",
	})
	SendText(encoded)
	
	
end


function StartClient(first, appuri, port)
	if not vim.g.instant_username or string.len(vim.g.instant_username) == 0 then
		error("Please specify a username in vim.g.instant_username")
	end
	
	detach = {}
	
	queue = {}
	
	initialized = false
	
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
			
				for _,bufhandle in ipairs(vim.api.nvim_list_bufs()) do
					if vim.api.nvim_buf_is_loaded(bufhandle) then
						DetachFromBuffer(bufhandle)
					end
				end
				StopClient()
				
				writeChanges()
				
				return
			end
			
			table.insert(events, "err: " .. vim.inspect(err) .. " chunk: " .. vim.inspect(chunk))
			
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
						
						if decoded then
							if decoded["type"] == "text" then
								if single_buffer then
									local buf = vim.api.nvim_get_current_buf()
									local tick = vim.api.nvim_buf_get_changedtick(buf)+1
									ignores[buf][tick] = true
									
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
									-- table.insert(events, "buf " .. buf .. " set_lines start: " .. decoded["start"] .. " end: " .. decoded["end"] .. " lines: " .. vim.inspect(lines))
									vim.api.nvim_buf_set_lines(
										buf, 
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
									
								else 
									local filename = vim.api.nvim_call_function("simplify", {InstantRoot .. decoded["filename"]})
									local in_buffer = vim.api.nvim_call_function("bufnr", { filename .. "$" }) ~= -1
									
									local in_directory = string.len(filename) > 0 and string.sub(filename, 1, #InstantRoot) == InstantRoot
									
									if in_buffer and in_directory then
										local buf = vim.api.nvim_call_function("bufnr", { filename .. "$" })
										
										local tick = vim.api.nvim_buf_get_changedtick(buf)+1
										ignores[buf][tick] = true
										
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
										-- table.insert(events, "buf " .. buf .. " set_lines start: " .. decoded["start"] .. " end: " .. decoded["end"] .. " lines: " .. vim.inspect(lines))
										vim.api.nvim_buf_set_lines(
											buf, 
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
										
									elseif in_directory then
										if string.len(vim.api.nvim_call_function("glob", { filename })) == 0 then
											local new_file = io.open(filename, "w")
											table.insert(events, "created new file " .. filename)
											new_file:close()
										end
										
										table.insert(events, "queue up edits for " .. filename)
										table.insert(queue, decoded)
										
									end
								end
							end
							
							if decoded["type"] == "request" then
								if single_buffer then
									local lines = vim.api.nvim_buf_get_lines(
										bufhandle,
										0, -1, true)
									
									local encoded = vim.fn.json_encode({
										["type"] = "initial",
										["content"] = table.concat(lines, '\n')
									})
									
									SendText(encoded)
									
								else 
									local filelist = vim.api.nvim_call_function("glob", { InstantRoot .. "**" })
									local files = {}
									if string.len(filelist) > 0 then
										for file in vim.gsplit(filelist, '\n') do
											table.insert(files, file)
										end
									end
									table.insert(events, "files found : " .. table.concat(files, " "))
									
									local contents = {}
									for _,file in ipairs(files) do
										local in_buffer = vim.api.nvim_call_function("bufnr", { file .. "$" }) ~= -1
										
										local lines
										if in_buffer then
											lines = vim.api.nvim_buf_get_lines(
												vim.api.nvim_call_function("bufnr", { file  .. "$" }), 
												0, -1, true)
										else 
											lines = {}
											for line in io.lines(file) do
												table.insert(lines, line)
											end
										end
										
										local content = {
											filename = string.sub(file, string.len(InstantRoot)+1),
											text = table.concat(lines, '\n')
										}
										table.insert(contents, content)
										
									end
									local encoded = vim.fn.json_encode({
										["type"] = "initial",
										["contents"] = contents
									})
									
									SendText(encoded)
									
								end
							end
							
							if decoded["type"] == "initial" and not initialized then
								if single_buffer then
									table.insert(events, "setting initial content for single buffer")
									if decoded["contents"] then 
										table.insert(events, "ERROR: Initial content for directory sharing but in single buffer sharing")
										error("Initial content for directory sharing but in single buffer sharing")
									end
									
									local lines = {}
									for line in vim.gsplit(decoded["content"], "\n") do
										table.insert(lines, line)
									end
									
									local buf = vim.api.nvim_get_current_buf()
									local tick = vim.api.nvim_buf_get_changedtick(buf)+1
									ignores[buf][tick] = true
									
									vim.api.nvim_buf_set_lines(
										vim.api.nvim_get_current_buf(),
										0, -1, false, lines)
									
								else 
									if decoded["content"] then 
										table.insert(events, "ERROR: Initial content for single buffer sharing but in directory sharing")
										error("ERROR: Initial content for single buffer sharing but in directory sharing")
									end
									
									for _,content in ipairs(decoded["contents"]) do 
										local filename = InstantRoot .. content["filename"]
										local in_buffer = vim.api.nvim_call_function("bufnr", { filename .. "$" }) ~= -1
										
										local lines = {}
										for line in vim.gsplit(content["text"], '\n') do
											table.insert(lines, line)
										end
										
										if in_buffer then
											local buf = vim.api.nvim_call_function("bufnr", { filename .. "$" })
											
											local tick = vim.api.nvim_buf_get_changedtick(buf)+1
											ignores[buf][tick] = true
											
											vim.api.nvim_buf_set_lines(
												vim.api.nvim_call_function("bufnr", { filename .. "$" }),
												0, 
												-1, 
												false, 
												lines)
											
										else 
											local syncfile = io.open(filename, "w")
											for _,line in ipairs(lines) do
												syncfile:write(line .. '\n')
											end
											syncfile:close()
											
										end
									end
								end
								print("Connected!")
								initialized = true
							end
							
							if decoded["type"] == "response" then
								if decoded["is_first"] and first then
									print("Connected!")
									initialized = true
								elseif not decoded["is_first"] and not first then
									table.insert(events, "sending request")
									local encoded = vim.fn.json_encode({
										["type"] = "request",
									})
									SendText(encoded)
									
									
								elseif decoded["is_first"] and not first then
									table.insert(events, "ERROR: Tried to join an empty server")
									print("ERROR: Tried to join an empty server")
									for _,bufhandle in ipairs(vim.api.nvim_list_bufs()) do
										if vim.api.nvim_buf_is_loaded(bufhandle) then
											DetachFromBuffer(bufhandle)
										end
									end
									StopClient()
									
									writeChanges()
									
								elseif not decoded["is_first"] and first then
									table.insert(events, "ERROR: Tried to start a server which is already busy")
									print("ERROR: Tried to start a server which is already busy")
									for _,bufhandle in ipairs(vim.api.nvim_list_bufs()) do
										if vim.api.nvim_buf_is_loaded(bufhandle) then
											DetachFromBuffer(bufhandle)
										end
									end
									StopClient()
									
									writeChanges()
									
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
	if not initialized then
		return
	end
	
	if single_buffer then
		return
	end
	local bufhandle = vim.api.nvim_get_current_buf()
	table.insert(events, "bufhandle is " .. vim.inspect(bufhandle))
	table.insert(events, "has_attached[bufhandle] is " .. vim.inspect(has_attached[bufhandle]))
	if has_attached[bufhandle] then
		table.insert(events, "buffer is already attached")
		return
	end
	
	local buf_filename = vim.api.nvim_buf_get_name(bufhandle)
	local is_in_root = string.len(buf_filename) > 0 and string.sub(buf_filename, 1, #InstantRoot) == InstantRoot
	
	if string.match(buf_filename, "instant.json$") then
		return
	end
	
	if is_in_root then
		table.insert(events, "Attaching callback to " .. bufhandle)
		ignores[bufhandle] = {}
		
		local i = 1
		while i <= #queue do
			local decoded = queue[i]
			local filename = vim.api.nvim_call_function("simplify", {InstantRoot .. decoded["filename"]})
			local buf = vim.api.nvim_call_function("bufnr", { filename .. "$" })
			
			if bufhandle == buf then
				local tick = vim.api.nvim_buf_get_changedtick(buf)+1
				ignores[buf][tick] = true
				
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
				-- table.insert(events, "buf " .. buf .. " set_lines start: " .. decoded["start"] .. " end: " .. decoded["end"] .. " lines: " .. vim.inspect(lines))
				vim.api.nvim_buf_set_lines(
					buf, 
					decoded["start"], 
					decoded["end"], 
					false, 
					lines)
				
				table.remove(queue, i)
			else
				i = i + 1
			end
		end
		
		local lines = vim.api.nvim_buf_get_lines(
			bufhandle,
			0, -1, true)
		local encoded = vim.fn.json_encode({
			["filename"] = string.sub(vim.api.nvim_buf_get_name(bufhandle), #InstantRoot+1),
			["type"] = "text",
			["start"] = 0,
			["end"]   = -1,
			["last"]   = -1,
			["author"] = vim.g.instant_username,
			["text"] = table.concat(lines, '\n')
		})
		SendText(encoded)
		
		
		local attach_success = vim.api.nvim_buf_attach(bufhandle, false, {
			on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
				if detach[buf] then
					table.insert(events, "Detached from buffer " .. buf)
					detach[buf] = nil
					return true
				end
				
				if ignores[buf][changedtick] then
					ignores[buf][changedtick] = nil
					return
				end
				
				local lines = vim.api.nvim_buf_get_lines(buf, firstline, new_lastline, true)
				
				local filename
				if not single_buffer then
					filename = string.sub(vim.api.nvim_buf_get_name(bufhandle), #InstantRoot+1)
				end
				
				local encoded = vim.fn.json_encode({
					["filename"] = filename,
					["type"] = "text",
					["start"] = firstline,
					["end"]   = lastline,
					["last"]   = new_lastline,
					["author"] = vim.g.instant_username,
					["text"] = table.concat(lines, '\n')
				})
				
				SendText(encoded)
				
			end,
			on_detach = function(_, buf)
				table.insert(events, "detached " .. bufhandle)
				has_attached[bufhandle] = nil
			end
		})
		
		if attach_success then
			has_attached[bufhandle] = true
			table.insert(events, "has_attached[" .. bufhandle .. "] = true")
		end
		
		table.insert(events, "Attach was " .. vim.inspect(attach_success))
	end
end

local function DetachFromBuffer(bufnr)
	table.insert(events, "Detaching from buffer...")
	detach[bufnr] = true
end

function writeChanges()
	local files = {}
	for _,decoded in ipairs(queue) do
		files[decoded["filename"]] = true
	end
	
	for file,_ in pairs(files) do
		local filename = vim.api.nvim_call_function("simplify", {InstantRoot .. file})
		
		local filelines = {}
		for line in io.lines(filename) do
			table.insert(filelines, line)
		end
		
		i = 1
		while i <= #queue do 
			local decoded = queue[i]
			if decoded["filename"] == file then
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
				
				for i=decoded["start"], decoded["end"]-1 do
					table.remove(filelines, i+1)
				end
				
				for i,line in ipairs(lines) do
					table.insert(filelines, decoded["start"]+i, line)
				end
				
				
				table.remove(queue, i)
			else 
				i = i + 1
			end
		end
		local outfile = io.open(filename, "w")
		for _,line in ipairs(filelines) do
			outfile:write(line .. "\n")
		end
		outfile:close()
		
	end
end


local function Start(first, cur_buffer, host, port)
	single_buffer = cur_buffer

	if not cur_buffer then
		local directory = vim.api.nvim_call_function("getcwd", {})
		if vim.api.nvim_call_function("isdirectory", { directory }) == 0 then
			error("The directory " .. directory .. " has not been found")
		end
		InstantRoot = vim.api.nvim_call_function("fnamemodify", {directory, ":p"})
		table.insert(events, "The instant directory root is " .. InstantRoot)
		
		if string.len(vim.api.nvim_call_function("glob", { InstantRoot .. "*" })) ~= 0 and string.len(vim.api.nvim_call_function("glob", { InstantRoot .. "instant.json" })) == 0 then
			error("The current directory is not empty nor does it contain a instant.json settings file")
			return
		end
		
		
		if string.len(vim.api.nvim_call_function("glob", { "**" })) == 0 then
			local settings = {}
			settings["createddate"] = os.date("!%c") .. " UTC"
			settings["author"] = vim.g.instant_username
			
			local settingsFile = io.open("instant.json", "w")
			settingsFile:write(vim.fn.json_encode(settings))
			settingsFile:close()
		end
		
	end
	StartClient(first, host, port)
	
	if not cur_buffer then
		for _,bufhandle in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(bufhandle) then
				local buf_filename = vim.api.nvim_buf_get_name(bufhandle)
				local is_in_root = string.len(buf_filename) > 0 and string.sub(buf_filename, 1, #InstantRoot) == InstantRoot
				
				if is_in_root then
					table.insert(events, "Attaching to buffer " .. bufhandle)
					ignores[bufhandle] = {}
					
					local attach_success = vim.api.nvim_buf_attach(bufhandle, false, {
						on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
							if detach[buf] then
								table.insert(events, "Detached from buffer " .. buf)
								detach[buf] = nil
								return true
							end
							
							if ignores[buf][changedtick] then
								ignores[buf][changedtick] = nil
								return
							end
							
							local lines = vim.api.nvim_buf_get_lines(buf, firstline, new_lastline, true)
							
							local filename
							if not single_buffer then
								filename = string.sub(vim.api.nvim_buf_get_name(bufhandle), #InstantRoot+1)
							end
							
							local encoded = vim.fn.json_encode({
								["filename"] = filename,
								["type"] = "text",
								["start"] = firstline,
								["end"]   = lastline,
								["last"]   = new_lastline,
								["author"] = vim.g.instant_username,
								["text"] = table.concat(lines, '\n')
							})
							
							SendText(encoded)
							
						end,
						on_detach = function(_, buf)
							table.insert(events, "detached " .. bufhandle)
							has_attached[bufhandle] = nil
						end
					})
					
					if attach_success then
						has_attached[bufhandle] = true
						table.insert(events, "has_attached[" .. bufhandle .. "] = true")
					end
					
				end
				
			end
		end
		
	else 
		local bufhandle = vim.api.nvim_get_current_buf()
		ignores[bufhandle] = {}
		
		local attach_success = vim.api.nvim_buf_attach(bufhandle, false, {
			on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
				if detach[buf] then
					table.insert(events, "Detached from buffer " .. buf)
					detach[buf] = nil
					return true
				end
				
				if ignores[buf][changedtick] then
					ignores[buf][changedtick] = nil
					return
				end
				
				local lines = vim.api.nvim_buf_get_lines(buf, firstline, new_lastline, true)
				
				local filename
				if not single_buffer then
					filename = string.sub(vim.api.nvim_buf_get_name(bufhandle), #InstantRoot+1)
				end
				
				local encoded = vim.fn.json_encode({
					["filename"] = filename,
					["type"] = "text",
					["start"] = firstline,
					["end"]   = lastline,
					["last"]   = new_lastline,
					["author"] = vim.g.instant_username,
					["text"] = table.concat(lines, '\n')
				})
				
				SendText(encoded)
				
			end,
			on_detach = function(_, buf)
				table.insert(events, "detached " .. bufhandle)
				has_attached[bufhandle] = nil
			end
		})
		
		if attach_success then
			has_attached[bufhandle] = true
			table.insert(events, "has_attached[" .. bufhandle .. "] = true")
		end
		
		
	end
end

local function Stop()
	for _,bufhandle in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufhandle) then
			DetachFromBuffer(bufhandle)
		end
	end
	StopClient()
	
	writeChanges()
	
	print("Disconnected!")
end


return {
Start = Start,
Stop = Stop,

Refresh = Refresh,

AttachToBuffer = AttachToBuffer,

}

