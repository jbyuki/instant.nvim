@*=
@requires
@script_variables
@fill_base64_table

@declare_functions
@functions


@start_client
@stop_client

@detach_from_buffer
@write_queued_changes

@start_function
@stop_function

@status_function

return {
@export_symbols
}

@script_variables+=
local client

@start_client+=
local function StartClient(first, appuri, port)
	@check_if_has_username
	@init_client
	@set_port_as_80_if_not_provided
	client = vim.loop.new_tcp()
	@get_ip_address

	client:connect(ipentry.addr, port, vim.schedule_wrap(function(err) 
		@check_for_connection_errors
		client:read_start(vim.schedule_wrap(function(err, chunk)
			@check_for_connection_errors_when_connected
			@read_response
		end))
		@opening_handshake
	end))
end

@stop_client+=
local function StopClient()
	@send_close_frame
	@close_client
end

@close_client+=
client:close()

@declare_functions+=
local GenerateWebSocketKey -- we must forward declare local functions because otherwise it picks the global one

@functions+=
function GenerateWebSocketKey()
	@generate_16_bytes_array
	return key
end

@generate_16_bytes_array+=
key = {}
for i =0,15 do
	table.insert(key, math.floor(math.random()*255))
end

@script_variables+=
local base64 = {}

@fill_base64_table+=
local b64 = 0
for i=string.byte('a'), string.byte('z') do base64[b64] = string.char(i) b64 = b64+1 end
for i=string.byte('A'), string.byte('Z') do base64[b64] = string.char(i) b64 = b64+1 end
for i=string.byte('0'), string.byte('9') do base64[b64] = string.char(i) b64 = b64+1 end
base64[b64] = '+' b64 = b64+1
base64[b64] = '/'

@declare_functions+=
local OpAnd, OpOr, OpRshift, OpLshift

@functions+=
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

@declare_functions+=
local ConvertToBase64

@functions+=
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

	@add_padding_characters_to_24_multiple

	return str
end

@add_padding_characters_to_24_multiple+=
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
	local b1 = array[#array-1]
	local b2 = array[#array]

	local c1 = OpRshift(b1, 2)
	local c2 = OpLshift(OpAnd(b1, 0x3), 4)+OpRshift(b2, 4)
	local c3 = OpLshift(OpAnd(b2, 0xF), 2)

	str = str .. base64[c1]
	str = str .. base64[c2]
	str = str .. base64[c3]
	str = str .. "="
end

@script_variables+=
local websocketkey

@opening_handshake+=
client:write("GET / HTTP/1.1\r\n")
client:write("Host: " .. appuri .. ":" .. port .. "\r\n")
client:write("Upgrade: websocket\r\n")
client:write("Connection: Upgrade\r\n")
websocketkey = ConvertToBase64(GenerateWebSocketKey())
client:write("Sec-WebSocket-Key: " .. websocketkey .. "\r\n")
client:write("Sec-WebSocket-Version: 13\r\n")
client:write("\r\n")

@client_connected+=
print("client connected!")

@declare_functions+=
local ConvertBytesToString

@functions+=
function ConvertBytesToString(tab)
	local s = ""
	for _,el in ipairs(tab) do
		s = s .. string.char(el)
	end
	return s
end

@convert_frame_to_string+=
local s = ConvertBytesToString(frame)

@send_frame+=
client:write(s)

@script_variables+=
events = {}

@read_response+=
table.insert(events, "err: " .. vim.inspect(err) .. " chunk: " .. vim.inspect(chunk))

@declare_functions+=
local SendText

@functions+=
function SendText(str)
	@generate_mask
	@mask_text
	@create_base_frame
	@convert_frame_to_string
	@send_frame
end

@generate_mask+=
local mask = {}
for i=1,4 do
	table.insert(mask, math.floor(math.random() * 255))
end

@declare_functions+=
local OpXor

@functions+=
function OpXor(a, b)
	return vim.api.nvim_call_function("xor", {a, b})
end

@mask_text+=
local masked = {}
for i=0,#str-1 do
	local j = i%4
	local trans = OpXor(string.byte(string.sub(str, i+1, i+1)), mask[j+1])
	table.insert(masked, trans)
end

@create_base_frame+=
local frame = {
	0x81, 0x80
}

@write_payload_length

for i=1,4 do
	table.insert(frame, mask[i])
end

for i=1,#masked do
	table.insert(frame, masked[i])
end

@script_variables+=
iptable = {}

@get_ip_address+=
iptable = vim.loop.getaddrinfo(appuri)
if #iptable == 0 then
	print("Could not resolve address")
	return
end
local ipentry = iptable[1]

@declare_functions+=
local nocase

@functions+=
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

@read_response+=
if chunk then
	if string.match(chunk, nocase("^HTTP")) then
		-- can be Sec-WebSocket-Accept or Sec-Websocket-Accept
		if string.match(chunk, nocase("Sec%-WebSocket%-Accept")) then
			table.insert(events, "handshake was successful")
			@handshake_finished
		end
	else
		local opcode, fin
		if remaining == 0 then
			first_chunk = chunk
		end
		@read_opcode
		@do_opcode
	end
end

@script_variables+=
local fragmented = ""
local remaining = 0
local first_chunk

@do_opcode+=
if opcode == 0x1 then -- TEXT
	if remaining == 0 then
		@read_payload_length
		@read_payload
		fragmented = text
		remaining = paylen - string.len(text)
	else
		fragmented = fragmented .. chunk
		remaining = remaining - string.len(chunk)
	end

	if remaining == 0 then
		@interpret_received_text
	end
end

@script_variables+=
frames = {}

@read_opcode+=
local b1 = string.byte(string.sub(first_chunk,1,1))
table.insert(frames, "FIN " .. OpAnd(b1, 0x80))
table.insert(frames, "OPCODE " .. OpAnd(b1, 0xF))
local b2 = string.byte(string.sub(first_chunk,2,2))
table.insert(frames, "MASK " .. OpAnd(b2, 0x80))
opcode = OpAnd(b1, 0xF)
fin = OpRshift(b1, 7)

@read_payload_length+=
local paylen = OpAnd(b2, 0x7F)
local paylenlen = 0
if paylen == 126 then -- 16 bits length
	local b3 = string.byte(string.sub(first_chunk,3,3))
	local b4 = string.byte(string.sub(first_chunk,4,4))
	paylen = OpLshift(b3, 8) + b4
	paylenlen = 2
elseif paylen == 127 then
	paylen = 0
	for i=0,7 do -- 64 bits length
		paylen = OpLshift(paylen, 8) 
		paylen = paylen + string.byte(string.sub(first_chunk,i+3,i+3))
	end
	paylenlen = 8
end
table.insert(frames, "PAYLOAD LENGTH " .. paylen)

@read_payload+=
local text = string.sub(chunk, 2+paylenlen+1)
if string.len(text) < 40 then
	table.insert(frames, "TEXT " .. text)
else
	table.insert(frames, "TEXT " .. string.sub(text, 1, 15) .. " .. " .. string.sub(text, string.len(text)-15))
end
table.insert(frames, "TEXT LEN " .. string.len(text))

@send_close_frame+=
@generate_mask
local frame = {
	0x88, 0x80,
}
for i=1,4 do 
	table.insert(frame, mask[i])
end
@convert_frame_to_string
@send_frame

@do_opcode+=
if opcode == 0x9 then -- PING
	@read_payload_length
	@send_pong
end

@send_pong+=
table.insert(frames, "SENT PONG")
@generate_mask
local frame = {
	0x8A, 0x80,
}
for i=1,4 do 
	table.insert(frame, mask[i])
end
@convert_frame_to_string
@send_frame

@write_payload_length+=
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

@script_variables+=
-- this global variable can be set to a local scope once 
-- autocommands registration is natively supported in
-- lua
has_attached = {} 

@register_buf_change_callback+=
local attach_success = vim.api.nvim_buf_attach(bufhandle, false, {
	on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
		@return_true_if_detach
		@if_ignore_tick_return
		vim.schedule(function()
			@get_both_ranges
			@if_text_was_insert_add_new_text
			@if_text_was_deleted_remove_text
		end)
	end,
	on_detach = function(_, buf)
		table.insert(events, "detached " .. bufhandle)
		has_attached[bufhandle] = nil
	end
})

if attach_success then
	@get_buffer_lines
	@init_pids_of_buffer_content
	@init_prev_of_buffer_content
	has_attached[bufhandle] = true
	table.insert(events, "has_attached[" .. bufhandle .. "] = true")
end

@check_if_buffer_is_not_attached_already+=
table.insert(events, "bufhandle is " .. vim.inspect(bufhandle))
table.insert(events, "has_attached[bufhandle] is " .. vim.inspect(has_attached[bufhandle]))
if has_attached[bufhandle] then
	table.insert(events, "buffer is already attached")
	return
end

@script_variables+=
local detach = {}

@init_client+=
detach = {}

@return_true_if_detach+=
if detach[buf] then
	table.insert(events, "Detached from buffer " .. buf)
	detach[buf] = nil
	return true
end

@detach_from_buffer+=
local function DetachFromBuffer(bufnr)
	table.insert(events, "Detaching from buffer...")
	detach[bufnr] = true
end

@get_both_ranges+=
local cur_range = ""
for _,line in ipairs(vim.api.nvim_buf_get_lines(buf, firstline, new_lastline, false)) do
	cur_range = cur_range .. "\n" .. line
end

@script_variables+=
local prev = { "" }

@get_both_ranges+=
local prev_range = ""
for l=firstline,lastline-1 do
	if prev[l+1] then 
		prev_range = prev_range .. "\n" .. prev[l+1]
	end
end

@if_text_was_insert_add_new_text+=
if string.len(cur_range) > string.len(prev_range) then
	@get_xor_range_inserted
	if toadd then
		@add_new_to_prev
	end

@get_xor_range_inserted+=
local x, y = 0, 0
local toadd
for i=1,#cur_range do
	local c = string.sub(cur_range, i, i)
	if c ~= string.sub(prev_range, i, i) then
		toadd = string.sub(cur_range, i, string.len(cur_range) - string.len(prev_range) + i - 1)
		break
	end
	if c == "\n" then 
		x = 0
		y = y + 1 
	else 
		x = x + 1
	end
end

@add_new_to_prev+=
local px, py = x+1, firstline+y
for c in vim.gsplit(toadd, "") do
	if c == "\n" then
		@insert_newline_character
		table.insert(prev, py+1, "")
		py = py + 1
		px = 1
	else
		@insert_normal_character
		prev[py] = string.sub(prev[py], 1, px-1) .. c .. string.sub(prev[py], px)
		px = px + 1
	end
end

@if_text_was_deleted_remove_text+=
else
	@change_new_line_front_and_back
	@get_xor_range_deleted
	if todelete then
		@delete_in_prev
	end
end

@change_new_line_front_and_back+=
if string.len(cur_range) > 0 then
	cur_range = string.sub(cur_range, 2) .. "\n"
end
if string.len(prev_range) > 0 then
	prev_range = string.sub(prev_range, 2) .. "\n"
end

@get_xor_range_deleted+=
local x, y = 0, 0
local todelete
for i=1,#prev_range do
	local c = string.sub(prev_range, i, i)
	if c ~= string.sub(cur_range, i, i) then
		todelete = string.sub(prev_range, i, string.len(prev_range) - string.len(cur_range) + i - 1)
		break
	end
	if c == "\n" then 
		x = 0
		y = y + 1 
	else 
		x = x + 1
	end
end

@delete_in_prev+=
local px, py = x+1, firstline+y+1
for c in vim.gsplit(todelete, "") do
	if c == "\n" then
		if #prev > 1 then
			@delete_newline_character
			table.remove(prev, py)
		end
	else
		py = math.min(py, #prev)
		@delete_regular_character
		prev[py] = string.sub(prev[py], 1, px-1) .. string.sub(prev[py], px+1)
	end
end

@script_variables+=
-- pos = [(num, site)]
local MAXINT = 2^15 -- can be adjusted
local startpos, endpos = {{0, 0}}, {{MAXINT, 0}}
-- line = [pos]
-- pids = [line]
pids = {}

@init_client+=
local middlepos = genPID(startpos, endpos, agent, 1)
pids = {
	{ startpos },
	{ middlepos },
	{ endpos },
}

@declare_functions+=
local genPID

@functions+=
function genPID(p, q, s, i)
	local a = (p[i] and p[i][1]) or 0
	local b = (q[i] and q[i][1]) or MAXINT

	if a+1 < b then
		return {{math.random(a+1,b-1), s}}
	end

	local G = genPID(p, q, s, i+1)
	table.insert(G, 1, {
		(p[i] and p[i][1]) or 0, 
		(p[i] and p[i][2]) or s})
	return G
end

@functions+=
local function afterPID(x, y)
	if x == #pids[y] then return pids[y+1][1]
	else return pids[y][x+1] end
end

@script_variables+=
local agent = 0

@init_client_id+=
agent = decoded["client_id"]

@declare_functions+=
local SendOp

@functions+=
function SendOp(op)
	@encode_operation_in_json_object
	@send_encoded
end

@encode_operation_in_json_object+=
local obj = {
	["type"] = "text",
	["ops"] = { op },
	["author"] = vim.api.nvim_get_var("instant_username"),
}
local encoded = vim.api.nvim_call_function("json_encode", { obj })

@insert_newline_character+=
px = #pids[py+1]
local before_pid = pids[py+1][px]
local after_pid = afterPID(px, py+1)
local new_pid = genPID(before_pid, after_pid, agent, 1)
table.insert(pids, py+2, {new_pid})
SendOp { "ins", "\n", before_pid, new_pid }

@insert_normal_character+=
local before_pid = pids[py+1][px]
local after_pid = afterPID(px, py+1)
local new_pid = genPID(before_pid, after_pid, agent, 1)
table.insert(pids[py+1], px+1, new_pid)
SendOp { "ins", c, before_pid, new_pid }

@delete_newline_character+=
SendOp { "del", pids[py+1][1] }
table.remove(pids, py+1)

@delete_regular_character+=
SendOp { "del", pids[py+1][px+1] }
table.remove(pids[py+1], px+1)

@interpret_received_text+=
@decode_json
if decoded then
	-- table.insert(events, "received " .. text)
	@if_text_do_actions
	@if_request_send_all_lines
	@if_initial_and_not_initialized_set_buffer_lines
	@if_available_check_if_its_ok
	@if_status_echo_status
else
	table.insert(events, "Could not decode json " .. fragmented)
end

@if_text_do_actions+=
if decoded["type"] == "text" then
	local buf = vim.api.nvim_get_current_buf()
	@play_operations
	@clear_virtual_for_username
	@set_virtual_text_for_usernames
end

@get_buffer_number_of_filename+=
local buf = vim.api.nvim_call_function("bufnr", { filename .. "$" })

@decode_json+=
local decoded = vim.api.nvim_call_function("json_decode", {fragmented})

@script_variables+=
local ignores = {}

@init_buffer_attach+=
ignores[bufhandle] = {}

@get_changedtick_and_add_to_ignore+=
local tick = vim.api.nvim_buf_get_changedtick(buf)+1
ignores[buf][tick] = true

@if_ignore_tick_return+=
if ignores[buf][changedtick] then
	ignores[buf][changedtick] = nil
	return
end

@play_operations+=
local ops = decoded["ops"]
local opline = 0
for _,op in ipairs(ops) do
	@get_changedtick_and_add_to_ignore
	if op[1] == "ins" then
		@apply_insert_operation
	elseif op[1] == "del" then
		@apply_delete_operation
	end
end

@set_op_line_insert+=
opline = y-2

@set_op_line_delete+=
opline = sy-2

@apply_insert_operation+=
@find_pid_of_element_just_before
@set_op_line_insert
@insert_pid
@insert_character_with_pid_position
@insert_character_in_prev

@functions+=
local function findCharPosition(opid)
	local x, y = 1, 1
	local px, py = 1, 1
	for _,lpid in ipairs(pids) do
		x = 1 
		for _,pid in ipairs(lpid) do
			if not isLower(pid, opid) then 
				return px, py
			end
			px, py = x, y
			x = x + 1 
		end
		y = y + 1
	end
end

@find_pid_of_element_just_before+=
local x, y = findCharPosition(op[3])

@insert_pid+=
if op[2] == "\n" then table.insert(pids, y+1, { op[4] })
else table.insert(pids[y], x+1, op[4] ) end

@insert_character_with_pid_position+=
if op[2] == "\n" then 
	vim.api.nvim_buf_set_lines(buf, y-1, y-1, true, { "" })
else 
	local curline = vim.api.nvim_buf_get_lines(buf, y-2, y-1, true)[1]
	curline = string.sub(curline, 1, x-1) .. op[2] .. string.sub(curline, x)
	vim.api.nvim_buf_set_lines(buf, y-2, y-1, true, { curline })
end

@apply_delete_operation+=
@find_pid_of_element_to_delete
@set_op_line_delete
@delete_pid
@delete_character_with_pid_position
@delete_character_in_prev

@find_pid_of_element_to_delete+=
local sx, sy = findCharPosition(op[2])

@delete_pid+=
if sx == 1 then
	table.remove(pids, sy)
else
	table.remove(pids[sy], sx)
end

@delete_character_with_pid_position+=
if sx == 1 then
	vim.api.nvim_buf_set_lines(buf, sy-2, sy-1, true, {})
else
	if sy > 1 then
		local curline = vim.api.nvim_buf_get_lines(buf, sy-2, sy-1, true)[1]
		curline = string.sub(curline, 1, sx-2) .. string.sub(curline, sx)
		vim.api.nvim_buf_set_lines(buf, sy-2, sy-1, true, { curline })
	end
end

@insert_character_in_prev+=
if op[2] == "\n" then 
	table.insert(prev, y, "")
else 
	local curline = prev[y-1]
	curline = string.sub(curline, 1, x-1) .. op[2] .. string.sub(curline, x)
	prev[y-1] = curline
end

@delete_character_in_prev+=
if sx == 1 then
	table.remove(prev, sy-1)
else
	if sy > 1 then
		local curline = prev[sy-1]
		curline = string.sub(curline, 1, sx-2) .. string.sub(curline, sx)
		prev[sy-1] = curline
	end
end

@declare_functions+=
local isLower

@functions+=
function isLower(a, b)
	for i, ai in ipairs(a) do
		if i > #b then return false end
		local bi = b[i]
		if ai[1] < bi[1] then return true
		elseif ai[1] > bi[1] then return false
		elseif ai[2] < bi[2] then return true
		elseif ai[2] > bi[2] then return false
		end
	end
	return true
end

@set_lines+=
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

@set_port_as_80_if_not_provided+=
port = port or 80

@script_variables+=
local single_buffer

@start_function+=
local function Start(first, cur_buffer, host, port)
	@check_if_client_is_not_connected

	single_buffer = cur_buffer

	@start
	@attach_to_current_buffer
end

@start+=
StartClient(first, host, port)

@stop_function+=
local function Stop()
	if initialized then
		@stop
		print("Disconnected!")
		initialized = false
	end
end

@stop+=
for _,bufhandle in ipairs(vim.api.nvim_list_bufs()) do
	if vim.api.nvim_buf_is_loaded(bufhandle) then
		DetachFromBuffer(bufhandle)
	end
end
StopClient()

@export_symbols+=
Start = Start,
Stop = Stop,

@if_request_send_all_lines+=
if decoded["type"] == "request" then
	@get_all_lines_in_current_buffer
	@encode_initial_content_single
	@send_encoded
end

@handshake_finished+=
local obj = {
	["type"] = "available"
}
local encoded = vim.api.nvim_call_function("json_encode", { obj })
@send_encoded

@send_encoded+=
if not encoded then
	print("line number " .. debug.getinfo(1).currentline)
end
SendText(encoded)
-- table.insert(events, "sent " .. encoded)

@script_variables+=
local initialized

@init_client+=
initialized = false

@if_initial_and_not_initialized_set_buffer_lines+=
if decoded["type"] == "initial" and not initialized then
	@get_lines_of_initial_single
	@set_lines_for_initial_prev
	@set_pids_for_initial
	local buf = vim.api.nvim_get_current_buf()
	@get_changedtick_and_add_to_ignore
	@set_lines_in_current_buffer
	print("Connected!")
	initialized = true
end

@if_available_check_if_its_ok+=
if decoded["type"] == "response" then
	if decoded["is_first"] and first then
		@init_client_id
		print("Connected!")
		initialized = true
	elseif not decoded["is_first"] and not first then
		@init_client_id
		@send_request_for_initial_content
	elseif decoded["is_first"] and not first then
		table.insert(events, "ERROR: Tried to join an empty server")
		print("ERROR: Tried to join an empty server")
		@stop
	elseif not decoded["is_first"] and first then
		table.insert(events, "ERROR: Tried to start a server which is already busy")
		print("ERROR: Tried to start a server which is already busy")
		@stop
	end
end

@send_request_for_initial_content+=
table.insert(events, "sending request")
local obj = {
	["type"] = "request",
}
local encoded = vim.api.nvim_call_function("json_encode", { obj })
@send_encoded

@check_for_connection_errors+=
if err then
	table.insert(events, "connection err " .. vim.inspect(err))
	error("There was an error during connection: " .. err)
	return
end

@functions+=
local function Refresh()
	initialized = false
	@send_request_for_initial_content
end

@export_symbols+=
Refresh = Refresh,

@check_if_has_username+=
local v, username = pcall(function() return vim.api.nvim_get_var("instant_username") end)
if not v then
	error("Please specify a username in g:instant_username")
end

@script_variables+=
local old_namespace

@init_client+=
old_namespace = {}

@clear_virtual_for_username+=
if old_namespace[decoded["author"]] then
	vim.api.nvim_buf_clear_namespace(
		vim.api.nvim_get_current_buf(),
		old_namespace[decoded["author"]],
		0, -1)
	old_namespace[decoded["author"]] = nil
end

@set_virtual_text_for_usernames+=
old_namespace[decoded["author"]] = 
	vim.api.nvim_buf_set_virtual_text(
		vim.api.nvim_get_current_buf(),
		0, 
		math.max(opline, 0), 
		{{ " | " .. decoded["author"], "Special" }}, 
		{})

@check_for_connection_errors_when_connected+=
if err then
	table.insert(events, "connection err " .. vim.inspect(err))
	error("There was an error during connection: " .. err)

	@stop
	return
end

@attach_to_current_buffer+=
local bufhandle = vim.api.nvim_get_current_buf()
@init_buffer_attach
@register_buf_change_callback

@get_all_lines_in_current_buffer+=
local lines = vim.api.nvim_buf_get_lines(
	bufhandle,
	0, -1, true)

@encode_initial_content_single+=
local obj = {
	["type"] = "initial",
	["pids"] = pids,
	["content"] = table.concat(lines, '\n')
}
local encoded = vim.api.nvim_call_function("json_encode", { obj })

@get_lines_of_initial_single+=
local lines = {}
for line in vim.gsplit(decoded["content"], "\n") do
	table.insert(lines, line)
end

@set_lines_for_initial_prev+=
prev = {}

for line in vim.gsplit(decoded["content"], "\n") do
	table.insert(prev, line)
end

@set_pids_for_initial+=
pids = decoded["pids"]

@set_lines_in_current_buffer+=
vim.api.nvim_buf_set_lines(
	vim.api.nvim_get_current_buf(),
	0, -1, false, lines)

@status_function+=
local function Status()
	if client and client:is_active() then
		@send_server_status
	else
		print("Disconnected")
	end
end

@send_server_status+=
local obj = {
	["type"] = "status",
}
local encoded = vim.api.nvim_call_function("json_encode", { obj })
@send_encoded

@export_symbols+=
Status = Status,

@if_status_echo_status+=
if decoded["type"] == "status" then
	table.insert(events, "Connected: " .. tostring(decoded["num_clients"]) .. " client(s).")
	print("Connected: " .. tostring(decoded["num_clients"]) .. " client(s).")
end

@check_if_client_is_not_connected+=
if client and client:is_active() then
	error("Client is already connected. Use InstantStop first to disconnect.")
end

@get_buffer_lines+=
local lines = vim.api.nvim_buf_get_lines(bufhandle, 0, -1, true)

@init_prev_of_buffer_content+=
prev = lines

@init_pids_of_buffer_content+=
local bpid = pids[2][1] -- middlepos
local epid = pids[3][1] -- endpos

for i=1,#lines do
	local line = lines[i]
	if i > 1 then
		@generate_character_pid
		@insert_newline_character_pid
	end

	for j=1,string.len(line) do
		@generate_character_pid
		@insert_character_pid
	end

end

@generate_character_pid+=
local newpid = genPID(bpid, epid, agent, 1)
bpid = newpid

@insert_character_pid+=
table.insert(pids[i+1], newpid)

@insert_newline_character_pid+=
table.insert(pids, i+1, { newpid })
