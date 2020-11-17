@*=
@requires
@declare_functions
@script_variables
@fill_base64_table
@init_typeset

@functions

@type_random_function

@start_client
@stop_client

@detach_from_buffer
@write_queued_changes

@start_function
@stop_function

@start_session_function
@stop_session_function

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

@declare_functions+=
local StopClient

@stop_client+=
function StopClient()
	@send_close_frame
	@close_client
end

@close_client+=
client:close()
client = nil

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
local ConvertToBase64

@functions+=
function ConvertToBase64(array)
	local i
	local str = ""
	for i=0,#array-3,3 do
		local b1 = array[i+0+1]
		local b2 = array[i+1+1]
		local b3 = array[i+2+1]

		local c1 = bit.rshift(b1, 2)
		local c2 = bit.lshift(bit.band(b1, 0x3), 4)+bit.rshift(b2, 4)
		local c3 = bit.lshift(bit.band(b2, 0xF), 2)+bit.rshift(b3, 6)
		local c4 = bit.band(b3, 0x3F)

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

	local c1 = bit.rshift(b1, 2)
	local c2 = bit.lshift(bit.band(b1, 0x3), 4)

	str = str .. base64[c1]
	str = str .. base64[c2]
	str = str .. "="
	str = str .. "="

elseif rest == 16 then
	local b1 = array[#array-1]
	local b2 = array[#array]

	local c1 = bit.rshift(b1, 2)
	local c2 = bit.lshift(bit.band(b1, 0x3), 4)+bit.rshift(b2, 4)
	local c3 = bit.lshift(bit.band(b2, 0xF), 2)

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
-- table.insert(events, "err: " .. vim.inspect(err) .. " chunk: " .. vim.inspect(chunk))

@declare_functions+=
local SendText

@script_variables+=
masktexttime = 0
convertframetostringtime = 0
sendframetime = 0

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

@requires+=
local bit = require("bit")

@mask_text+=
local masked = {}
for i=0,#str-1 do
	local j = i%4
	local trans = bit.bxor(string.byte(string.sub(str, i+1, i+1)), mask[j+1])
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
local iptable = {}

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
		-- if multiple tcp packets are 
		-- sent at once
		while string.len(chunk) > 0 do
			-- if tcp packets are sent
			-- fragmented
			if remaining == 0 then
				first_chunk = chunk
			end
			@read_opcode
			@do_opcode
		end
	end
end

@do_opcode+=
if opcode == 0x1 then -- TEXT
	@read_payload_length
	if remaining == 0 then
		@read_payload
		chunk = string.sub(chunk, 2+paylenlen+1+paylen)
		fragmented = text
		remaining = paylen - string.len(text)
	else
		fragmented = fragmented .. chunk
		remaining = remaining - string.len(chunk)
		chunk = ""
	end

	if remaining == 0 then
		@interpret_received_text
	end
end

@script_variables+=
local frames = {}
local first_chunk
local fragmented = ""
local remaining = 0

@read_opcode+=
local b1 = string.byte(string.sub(first_chunk,1,1))
-- table.insert(frames, "FIN " .. bit.band(b1, 0x80))
-- table.insert(frames, "OPCODE " .. bit.band(b1, 0xF))
local b2 = string.byte(string.sub(first_chunk,2,2))
-- table.insert(frames, "MASK " .. bit.band(b2, 0x80))
opcode = bit.band(b1, 0xF)
fin = bit.rshift(b1, 7)

@read_payload_length+=
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
-- table.insert(frames, "PAYLOAD LENGTH " .. paylen)

@read_payload+=
local text = string.sub(chunk, 2+paylenlen+1, 2+paylenlen+1+(paylen-1))

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
--table.insert(frames, "SENT PONG")
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
	local b1 = bit.rshift(#masked, 8)
	local b2 = bit.band(#masked, 0xFF)
	table.insert(frame, b1)
	table.insert(frame, b2)
else
	frame[2] = frame[2] + 127
	for i=0,7 do
		local b = bit.band(bit.rshift(#masked, (7-i)*8), 0xFF)
		table.insert(frame, b)
	end
end

@declare_functions+=
local StartTimer, StopTimer

@functions+=
function StartTimer()
	return vim.api.nvim_call_function("reltime", {})
end

function StopTimer(start)
	local dt =  vim.api.nvim_call_function("reltime", { start })
	return tonumber(vim.api.nvim_call_function("reltimestr", {dt}))
end


@script_variables+=
local attached = {}

@register_buf_change_callback+=
if not attached[buf] then
	local attach_success = vim.api.nvim_buf_attach(buf, false, {
		on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
			@return_true_if_detach
			@if_ignore_tick_return

			local t2 = StartTimer()
			@get_context_for_current_buffer
			@get_both_ranges
			@get_xor_range
			-- @display_xor_ranges
			@if_there_is_text_to_delete_delete_it
			@if_there_is_text_to_insert_insert_it
			@set_context_for_current_buffer
			table.insert(events, "total time " .. StopTimer(t2))
		end,
		on_detach = function(_, buf)
			table.insert(events, "detached " .. buf)
			attached[buf] = nil
		end
	})

	if attach_success then
		table.insert(events, "has_attached[" .. buf .. "] = true")
		attached[buf] = true
	end
else
	detach[buf] = nil
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

@init_buffer_attach+=
detach[buf] = nil

@declare_functions+=
local DetachFromBuffer

@detach_from_buffer+=
function DetachFromBuffer(bufnr)
	table.insert(events, "Detaching from buffer... " .. bufnr)
	detach[bufnr] = true
end

@get_both_ranges+=
local cur_lines = vim.api.nvim_buf_get_lines(buf, firstline, new_lastline, true)

local add_range = {
	sx = -1,
	sy = firstline,			
	ex = -1, -- at position there is \n
	ey = new_lastline
}

@script_variables+=
allprev = {}
local prev = { "" }

@get_both_ranges+=
local del_range = {
	sx = -1,
	sy = firstline,
	ex = -1,
	ey = lastline,
}

@get_xor_range+=
@go_from_ending_and_elimate_same
@go_from_begining_and_elimate_same

@go_from_begining_and_elimate_same+=
while (add_range.sy < add_range.ey or (add_range.sy == add_range.ey and add_range.sx <= add_range.ex)) and 
	  (del_range.sy < del_range.ey or (del_range.sy == del_range.ey and del_range.sx <= del_range.ex)) do

	local c1, c2
	if add_range.sx == -1 then c1 = "\n"
	else c1 = utf8char(cur_lines[add_range.sy-firstline+1] or "", add_range.sx) end

	if del_range.sx == -1 then c2 = "\n"
	else c2 = utf8char(prev[del_range.sy+1] or "", del_range.sx) end

	if c1 ~= c2 then
		break
	end
	@advance_one_character_both_ranges
end

@advance_one_character_both_ranges+=
add_range.sx = add_range.sx+1
del_range.sx = del_range.sx+1

if add_range.sx == utf8len(cur_lines[add_range.sy-firstline+1] or "") then
	add_range.sx = -1
	add_range.sy = add_range.sy + 1
end

if del_range.sx == utf8len(prev[del_range.sy+1] or "") then
	del_range.sx = -1
	del_range.sy = del_range.sy + 1
end

@go_from_ending_and_elimate_same+=
while (add_range.ey > add_range.sy or (add_range.ey == add_range.sy and add_range.ex >= add_range.sx)) and 
	  (del_range.ey > del_range.sy or (del_range.ey == del_range.sy and del_range.ex >= del_range.sx)) do

	local c1, c2
	if add_range.ex == -1 then c1 = "\n"
	else c1 = utf8char(cur_lines[add_range.ey-firstline+1] or "", add_range.ex) end

	if del_range.ex == -1 then c2 = "\n"
	else c2 = utf8char(prev[del_range.ey+1] or "", del_range.ex) end

	if c1 ~= c2 then
		break
	end

	local add_prev, del_prev
	@step_back_one_character_both_ranges
	@shrink_range_at_end
end

@step_back_one_character_both_ranges+=
if add_range.ex == -1 then
	add_prev = { ey = add_range.ey-1, ex = utf8len(cur_lines[add_range.ey-firstline] or "")-1 }
else
	add_prev = { ex = add_range.ex-1, ey = add_range.ey }
end

if del_range.ex == -1 then
	del_prev = { ey = del_range.ey-1, ex = utf8len(prev[del_range.ey] or "")-1 }
else
	del_prev = { ex = del_range.ex-1, ey = del_range.ey }
end

@shrink_range_at_end+=
add_range.ex, add_range.ey = add_prev.ex, add_prev.ey
del_range.ex, del_range.ey = del_prev.ex, del_prev.ey

@if_there_is_text_to_delete_delete_it+=
local endx = del_range.ex
for y=del_range.ey, del_range.sy,-1 do
	@get_current_line_length_to_delete
	for x=endx,startx,-1 do
		if x == -1 then
			if #prev > 1 then
				@delete_line_by_merging_with_previous
				@delete_pid_of_newline
				@send_delete_operation_for_newline
			end
		else
			@delete_character_in_del_range
			@delete_pid_of_char
			@send_delete_operation_for_character
		end
	end
	endx = utf8len(prev[y] or "")-1
end

@get_current_line_length_to_delete+=
local startx=-1
if y == del_range.sy then
	startx = del_range.sx
end

@delete_character_in_del_range+=
prev[y+1] = utf8remove(prev[y+1], x)

@delete_pid_of_char+=
local del_pid = pids[y+2][x+2]
table.remove(pids[y+2], x+2)

@delete_line_by_merging_with_previous+=
if y > 0 then
	prev[y] = prev[y] .. (prev[y+1] or "")
end
table.remove(prev, y+1)

@delete_pid_of_newline+=
local del_pid = pids[y+2][1]
for i,pid in ipairs(pids[y+2]) do
	if i > 1 then
		table.insert(pids[y+1], pid)
	end
end
table.remove(pids, y+2)

@send_delete_operation_for_newline+=
SendOp(buf, { "del", del_pid })

@send_delete_operation_for_character+=
SendOp(buf, { "del", del_pid })

@if_there_is_text_to_insert_insert_it+=
local startx = add_range.sx
for y=add_range.sy, add_range.ey do
	@get_current_line_length_to_insert
	for x=startx,endx do
		if x == -1 then
			@insert_newline_by_splitting_text
			@insert_pid_of_newline
			@send_insert_operation_for_newline
		else
			@insert_character_in_add_range
			@insert_pid_of_char
			@send_insert_operation_for_character
		end
	end
	startx = -1
end

@get_current_line_length_to_insert+=
local endx
if y == add_range.ey then
	endx = add_range.ex
else
	endx = utf8len(cur_lines[y-firstline+1])-1
end

@insert_character_in_add_range+=
local c = utf8char(cur_lines[y-firstline+1], x)
prev[y+1] = utf8insert(prev[y+1], x, c)

@insert_pid_of_char+=
local before_pid = pids[y+2][x+1]
local after_pid = afterPID(x+1, y+2)
local new_pid = genPID(before_pid, after_pid, agent, 1)

table.insert(pids[y+2], x+2, new_pid)

@send_insert_operation_for_character+=
SendOp(buf, { "ins", c, before_pid, new_pid })

@insert_newline_by_splitting_text+=
if cur_lines[y-firstline] then
	local l, r = utf8split(prev[y], utf8len(cur_lines[y-firstline]))
	prev[y] = l
	table.insert(prev, y+1, r)
else
	table.insert(prev, y+1, "")
end

@insert_pid_of_newline+=
local pidx
if cur_lines[y-firstline] then
	pidx = utf8len(cur_lines[y-firstline])+1
else
	pidx = #pids[y+1]
end

local before_pid = pids[y+1][pidx]
local after_pid = afterPID(pidx, y+1)
local new_pid = genPID(before_pid, after_pid, agent, 1)

local l, r = splitArray(pids[y+1], pidx+1)
pids[y+1] = l
table.insert(r, 1, new_pid)
table.insert(pids, y+2, r)

@send_insert_operation_for_newline+=
SendOp(buf, { "ins", "\n", before_pid, new_pid })

@declare_functions+=
local utf8len, utf8char

@functions+=
function utf8len(str)
	return vim.str_utfindex(str)
end

function utf8char(str, i)
	if i >= utf8len(str) or i < 0 then return nil end
	local s1 = vim.str_byteindex(str, i)
	local s2 = vim.str_byteindex(str, i+1)
	return string.sub(str, s1+1, s2)
end

@declare_functions+=
local utf8insert

@functions+=
function utf8insert(str, i, c)
	if i == utf8len(str) then
		return str .. c
	end
	local s1 = vim.str_byteindex(str, i)
	return string.sub(str, 1, s1) .. c .. string.sub(str, s1+1)
end

@declare_functions+=
local utf8remove

@functions+=
function utf8remove(str, i)
	local s1 = vim.str_byteindex(str, i)
	local s2 = vim.str_byteindex(str, i+1)

	return string.sub(str, 1, s1) .. string.sub(str, s2+1)
end

@script_variables+=
-- pos = [(num, site)]
local MAXINT = 2^15 -- can be adjusted
local startpos, endpos = {{0, 0}}, {{MAXINT, 0}}
-- line = [pos]
-- pids = [line]
local allpids = {}
local pids = {}

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
function SendOp(buf, op)
	@convert_local_to_remote_buffer
	@encode_operation_in_json_object
	@send_encoded
end

@script_variables+=
local author = vim.api.nvim_get_var("instant_username")

@encode_operation_in_json_object+=
local obj = {
	["type"] = "text",
	["ops"] = { op },
	["buf"] = rem,
	["author"] = author,
}
local encoded = vim.api.nvim_call_function("json_encode", { obj })

@if_text_was_replaced_add_and_remove_text+=
else
	@get_xor_range_replaced
	if toreplace then
		@replace_in_prev
	end
end

@insert_newline_character+=
local before_pid, new_pid
if py > 0 then
	before_pid = pids[py+1][px+1]

	local after_pid = afterPID(px+1, py+1)
	new_pid = genPID(before_pid, after_pid, agent, 1)
	local l, r = splitArray(pids[py+1], px+2)
	pids[py+1] = l
	table.insert(r, 1, new_pid)
	table.insert(pids, py+2, r)
else
	before_pid = pids[py+1][px+1]
	local after_pid = afterPID(px+1, py+1)
	new_pid = genPID(before_pid, after_pid, agent, 1)
	table.insert(pids, py+2, { new_pid })
end

SendOp(buf, { "ins", "\n", before_pid, new_pid })

@insert_normal_character+=
local before_pid = pids[py+1][px+1]
local after_pid = afterPID(px+1, py+1)
local new_pid = genPID(before_pid, after_pid, agent, 1)
table.insert(pids[py+1], px+2, new_pid)
SendOp(buf, { "ins", c, before_pid, new_pid })

@delete_newline_character+=
SendOp(buf, { "del", pids[py+2][1] })
for i,pid in ipairs(pids[py+2]) do
	if i > 1 then
		table.insert(pids[py+1], pid)
	end
end
table.remove(pids, py+2)

@delete_regular_character+=
SendOp(buf, { "del", pids[py+2][px+2] })
table.remove(pids[py+2], px+2)

@interpret_received_text+=
@decode_json
if decoded then
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
	@play_operations
end

@decode_json+=
local decoded = vim.api.nvim_call_function("json_decode", {fragmented})

@script_variables+=
local ignores = {}

@init_buffer_attach+=
ignores[buf] = {}

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
local opcol = 0
local lastPID
for _,op in ipairs(ops) do
	-- table.insert(events, "receive op " .. vim.inspect(op))
	-- @display_states
	@get_buffer_number_to_apply_modifications
	@get_context_for_current_buffer
	@get_changedtick_and_add_to_ignore
	if op[1] == "ins" then
		@save_last_inserted_pid
		@apply_insert_operation
	elseif op[1] == "del" then
		@save_last_deleted_pid
		@apply_delete_operation
	end
	@set_context_for_current_buffer
	local aut = decoded["author"]
	@update_cursor_highlight
	@notify_status_callbacks
	-- @check_if_pid_match_with_prev
end

@set_op_line_insert+=
if op[2] == "\n" then
	opline = y-1
else
	opline = y-2
end
opcol = x

@set_op_line_delete+=
if sx == 1 then
	opline = sy-1
else
	opline = sy-2
end
opcol = sx-2

@apply_insert_operation+=
@find_pid_of_element_just_before
@set_op_line_insert
@insert_pid
@insert_character_with_pid_position
@insert_character_in_prev

@functions+=
local function findCharPositionBefore(opid, ipid)
	@compute_line_with_sorted_binary_search
	local px, py = 1, 1
	for y=y1,#pids do
		for x,pid in ipairs(pids[y]) do
			if not isLower(pid, opid) and not isLower(pid, ipid) then 
				return px, py
			end
			px, py = x, y
		end
	end
end

@find_pid_of_element_just_before+=
local x, y = findCharPositionBefore(op[3], op[4])

@declare_functions+=
local splitArray

@functions+=
function splitArray(a, p)
	local left, right = {}, {}
	for i=1,#a do
		if i < p then left[#left+1] = a[i]
		else right[#right+1] = a[i] end
	end
	return left, right
end

@insert_pid+=
if op[2] == "\n" then 
	local py, py1 = splitArray(pids[y], x+1)
	pids[y] = py
	table.insert(py1, 1, op[4])
	table.insert(pids, y+1, py1)
else table.insert(pids[y], x+1, op[4] ) end

@declare_functions+=
local utf8split

@functions+=
function utf8split(str, i)
	local s1 = vim.str_byteindex(str, i)
	return string.sub(str, 1, s1), string.sub(str, s1+1)
end

@insert_character_with_pid_position+=
if op[2] == "\n" then 
	if y-2 >= 0 then
		local curline = vim.api.nvim_buf_get_lines(buf, y-2, y-1, true)[1]
		local l, r = utf8split(curline, x-1)
		vim.api.nvim_buf_set_lines(buf, y-2, y-1, true, { l, r })
	else
		vim.api.nvim_buf_set_lines(buf, 0, 0, true, { "" })
	end
else 
	local curline = vim.api.nvim_buf_get_lines(buf, y-2, y-1, true)[1]
	curline = utf8insert(curline, x-1, op[2])
	vim.api.nvim_buf_set_lines(buf, y-2, y-1, true, { curline })
end

@apply_delete_operation+=
@find_pid_of_element_to_delete
if sx then
	@set_op_line_delete
	@delete_character_with_pid_position
	@delete_character_in_prev
	@delete_pid
end

@declare_functions+=
local isPIDEqual

@functions+=
function isPIDEqual(a, b)
	if #a ~= #b then return false end
	for i=1,#a do
		if a[i][1] ~= b[i][1] then return false end
		if a[i][2] ~= b[i][2] then return false end
	end
	return true
end

@functions+=
local function findCharPositionExact(opid)
	@compute_line_with_sorted_binary_search
	@compute_col_with_linear_search
end

@compute_line_with_sorted_binary_search+=
local y1, y2 = 1, #pids
while true do
	local ym = math.floor((y2 + y1)/2)
	if ym == y1 then break end
	if isLower(pids[ym][1], opid) then
		y1 = ym
	else
		y2 = ym
	end
end

@compute_col_with_linear_search+=
local y = y1
for x,pid in ipairs(pids[y]) do
	if isPIDEqual(pid, opid) then 
		return x, y
	end

	if not isLower(pid, opid) then
		return nil
	end
end


@find_pid_of_element_to_delete+=
local sx, sy = findCharPositionExact(op[2])

@delete_pid+=
if sx == 1 then
	for i,pid in ipairs(pids[sy]) do
		if i > 1 then
			table.insert(pids[sy-1], pid)
		end
	end
	table.remove(pids, sy)
else
	table.remove(pids[sy], sx)
end

@delete_character_with_pid_position+=
if sx == 1 then
	if sy-3 >= 0 then
		local prevline = vim.api.nvim_buf_get_lines(buf, sy-3, sy-2, true)[1]
		local curline = vim.api.nvim_buf_get_lines(buf, sy-2, sy-1, true)[1]
		vim.api.nvim_buf_set_lines(buf, sy-3, sy-1, true, { prevline .. curline })
	else
		vim.api.nvim_buf_set_lines(buf, sy-2, sy-1, true, {})
	end
else
	if sy > 1 then
		local curline = vim.api.nvim_buf_get_lines(buf, sy-2, sy-1, true)[1]
		curline = utf8remove(curline, sx-2)
		vim.api.nvim_buf_set_lines(buf, sy-2, sy-1, true, { curline })
	end
end

@insert_character_in_prev+=
if op[2] == "\n" then 
	if y-1 >= 1 then
		local l, r = utf8split(prev[y-1], x-1)
		prev[y-1] = l
		table.insert(prev, y, r)
	else
		table.insert(prev, y, "")
	end
else 
	prev[y-1] = utf8insert(prev[y-1], x-1, op[2])
end

@delete_character_in_prev+=
if sx == 1 then
	if sy-2 >= 1 then
		prev[sy-2] = prev[sy-2] .. string.sub(prev[sy-1], 1)
	end
	table.remove(prev, sy-1)
else
	if sy > 1 then
		local curline = prev[sy-1]
		curline = utf8remove(curline, sx-2)
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

@set_port_as_80_if_not_provided+=
port = port or 80

@script_variables+=
local singlebuf

@start_function+=
local function Start(host, port)
	@check_if_client_is_not_connected

	local buf = vim.api.nvim_get_current_buf()
	singlebuf = buf
	local first = true
	sessionshare = false
	@start

end

@start_function+=
local function Join(host, port)
	@check_if_client_is_not_connected

	local buf = vim.api.nvim_get_current_buf()
	singlebuf = buf
	local first = false
	sessionshare = false
	@start
end

@export_symbols+=
Start = Start,
Join = Join,
Stop = Stop,

@start+=
StartClient(first, host, port)

@stop_function+=
local function Stop()
	@stop
	print("Disconnected!")
end

@stop+=
for bufhandle,_ in pairs(allprev) do
	if vim.api.nvim_buf_is_loaded(bufhandle) then
		DetachFromBuffer(bufhandle)
	end
end
StopClient()


@if_request_send_all_lines+=
if decoded["type"] == "request" then
	local encoded
	if not sessionshare then
		local buf = singlebuf
		local rem = { agent, buf }
		@get_buf_name_relative_to_cwd_or_just_tail
		@encode_initial_content_single
		@send_encoded
	else
		@get_all_text_edit_buffers
		for _,buf in ipairs(bufs) do
			local rem = { agent, buf }
			@get_buf_name_relative_to_cwd_or_just_tail
			@encode_initial_content_single
			@send_encoded
		end
	end
end

@handshake_finished+=
local obj = {
	["type"] = "available"
}
local encoded = vim.api.nvim_call_function("json_encode", { obj })
@send_encoded

@send_encoded+=
SendText(encoded)
-- table.insert(events, "sent " .. encoded)

@if_initial_and_not_initialized_set_buffer_lines+=
if decoded["type"] == "initial" then
	local ag, bufid = unpack(decoded["bufid"])
	if not rem2loc[ag] or not rem2loc[ag][bufid] then
		local buf
		if not sessionshare then
			buf = singlebuf
			@rename_buffer_to_initial
		else
			@create_new_buffer
			@attach_to_current_buffer
			@rename_buffer_to_initial
			@detect_file_type
			@remove_buf_type_of_scratch_buffer
		end

		@map_received_buffer_id

		@set_lines_for_initial_prev
		@set_pids_for_initial

		@get_changedtick_and_add_to_ignore
		@set_lines_in_current_buffer
		@set_context_for_current_buffer
	else
		local buf = rem2loc[ag][bufid]

		@set_lines_for_initial_prev
		@set_pids_for_initial

		@get_changedtick_and_add_to_ignore
		@set_lines_in_current_buffer
		@set_context_for_current_buffer

		@rename_buffer_to_initial
		@detect_file_type
	end
end

@if_available_check_if_its_ok+=
if decoded["type"] == "response" then
	if decoded["is_first"] and first then
		@init_client_id
		@send_client_informations
		print("Connected!")

		if sessionshare then
			@get_all_text_edit_buffers
			@attach_to_all_opened_buffers
			@init_content_for_all_opened_buffers
		else
			local buf = singlebuf

			@attach_to_current_buffer

			@get_buffer_lines
			@init_pids_of_buffer_content
			@init_prev_of_buffer_content
			@set_context_for_current_buffer

		end

		@register_autocommands_for_buffer_open_and_create
	elseif not decoded["is_first"] and not first then
		if decoded["sessionshare"] ~= sessionshare then
			print("ERROR: Share mode client server mismatch (session mode, single buffer mode)")
			@stop
		else
			@init_client_id
			@send_client_informations

			if not sessionshare then
				local buf = singlebuf

				@attach_to_current_buffer
			end
			@send_request_for_initial_content
			print("Connected!")
		end
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
local obj = {
	["type"] = "request",
}
local encoded = vim.api.nvim_call_function("json_encode", { obj })
@send_encoded

@check_for_connection_errors+=
if err then
	table.insert(events, "connection err " .. vim.inspect(err))
	@stop
	error("There was an error during connection: " .. err)
	return
end

@functions+=
local function Refresh()
	@send_request_for_initial_content
end

@export_symbols+=
Refresh = Refresh,

@check_if_has_username+=
local v, username = pcall(function() return vim.api.nvim_get_var("instant_username") end)
if not v then
	error("Please specify a username in g:instant_username")
end


@check_for_connection_errors_when_connected+=
if err then
	table.insert(events, "connection err " .. vim.inspect(err))
	@stop
	error("There was an error during connection: " .. err)
	return
end

@attach_to_current_buffer+=
@init_buffer_attach
@register_buf_change_callback

@get_all_lines_in_current_buffer+=
local lines = vim.api.nvim_buf_get_lines(
	singlebuf,
	0, -1, true)

@encode_initial_content_single+=
local obj = {
	["type"] = "initial",
	["name"] = bufname,
	["bufid"] = rem,
	["pids"] = allpids[buf],
	["content"] = allprev[buf]
}
encoded = vim.api.nvim_call_function("json_encode", { obj })

@set_lines_for_initial_prev+=
prev = decoded["content"]

@set_pids_for_initial+=
pids = decoded["pids"]

@set_lines_in_current_buffer+=
vim.api.nvim_buf_set_lines(
	buf,
	0, -1, false, decoded["content"])

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
	print("Connected: " .. tostring(decoded["num_clients"]) .. " client(s). ")
end

@check_if_client_is_not_connected+=
if client and client:is_active() then
	error("Client is already connected. Use InstantStop first to disconnect.")
end

@get_buffer_lines+=
local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)

@init_prev_of_buffer_content+=
prev = lines

@init_pids_of_buffer_content+=
local middlepos = genPID(startpos, endpos, agent, 1)
pids = {
	{ startpos },
	{ middlepos },
	{ endpos },
}

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

-- For testing purposes
-- @script_variables+=
-- local typeset = {}
-- 
-- @init_typeset+=
-- for i=string.byte('a'),string.byte('z') do
-- 	table.insert(typeset, string.char(i))
-- end
-- 
-- for i=string.byte('A'),string.byte('Z') do
-- 	table.insert(typeset, string.char(i))
-- end
-- 
-- for i=string.byte('0'),string.byte('9') do
-- 	table.insert(typeset, string.char(i))
-- end
-- 
-- @type_random_function+=
-- function TypeRandom(limit, ms)
-- 	ms = ms or 50
-- 	local timer = vim.loop.new_timer()
-- 	local i = 0
-- 	timer:start(300, ms, function()
-- 		vim.schedule(function()
-- 			if math.random() < 0.7 or vim.api.nvim_buf_line_count(0) < 2 then
-- 				if math.random() < 0.1 then
-- 					@pick_random_line
-- 					@insert_new_line
-- 				elseif math.random() < 0.1 then
-- 					@pick_random_line
-- 					@split_line_into_two_lines
-- 				else
-- 					@pick_random_line
-- 					@pick_random_position_in_line
-- 					@pick_random_character
-- 					@insert_character
-- 				end
-- 			elseif math.random() < 0.9 then
-- 				if math.random() < 0.1 then
-- 					@pick_random_line
-- 					@delete_line
-- 				elseif math.random() < 0.1 then
-- 					@pick_random_line
-- 					@concat_line
-- 				else
-- 					@pick_random_line
-- 					@pick_random_position_in_line
-- 					@delete_character
-- 				end
-- 			else
-- 				@pick_random_line
-- 				@replace_with_random_line
-- 			end
-- 		end)
-- 		if i > limit then timer:close() end
-- 		i = i + 1
-- 	end)
-- end
-- 
-- @pick_random_line+=
-- local lcount = vim.api.nvim_buf_line_count(0)
-- local lnum = math.random(0, lcount-1) -- # zero indexed
-- 
-- @insert_new_line+=
-- vim.api.nvim_buf_set_lines(0, lnum, lnum, true, { "" }) 
-- 
-- @pick_random_position_in_line+=
-- local curline = vim.api.nvim_buf_get_lines(0, lnum, lnum+1, true)[1]
-- local cnum = math.random(1, string.len(curline))
-- 
-- @pick_random_character+=
-- local c = typeset[math.floor(math.random()*(#typeset-1)+0.5)+1]
-- 
-- @insert_character+=
-- curline = string.sub(curline, 1, cnum-1) .. c .. string.sub(curline, cnum)
-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, { curline }) 
-- 
-- @delete_line+=
-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, {})
-- 
-- @delete_character+=
-- curline = string.sub(curline, 1, cnum-1) .. string.sub(curline, cnum+1)
-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, { curline }) 
-- 
-- @split_line_into_two_lines+=
-- local curline = vim.api.nvim_buf_get_lines(0, lnum, lnum+1, true)[1]
-- local cnum = math.random(0, string.len(curline)-1) 
-- local r, l = utf8split(curline, cnum)
-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, { r, l }) 
-- 
-- @concat_line+=
-- if lnum < lcount-1 then 
-- 	local c = vim.api.nvim_buf_get_lines(0, lnum, lnum+2, true)
-- 	vim.api.nvim_buf_set_lines(0, lnum, lnum+2, true, { c[1] .. c[2] })
-- end
-- 
-- @replace_with_random_line+=
-- local lnewcount = math.random(1,20)
-- local newline = ""
-- for i=1,lnewcount do
-- 	@pick_random_character
-- 	newline = newline .. c
-- end
-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, { newline })
-- 
-- @display_xor_ranges+=
-- table.insert(events, "add range " .. vim.inspect(add_range))
-- table.insert(events, "del range " .. vim.inspect(del_range))
-- 
-- @check_if_pid_match_with_prev+=
-- for i=1,#pids do
-- 	local exp
-- 	if i == 1 or i == #pids then
-- 		exp = 1
-- 	else
-- 		exp = #prev[i-1] + 1
-- 	end
-- 	local res = #pids[i]
-- 	if exp ~= res then
-- 		table.insert(events, exp .. " " .. res .. " NG\n")
-- 	end
-- end
-- 
-- @display_states+=
-- for i,lpid in ipairs(pids) do
-- 	table.insert(events, i .. ": " .. vim.inspect(lpid))
-- end
-- for i,line in ipairs(prev) do
-- 	table.insert(events, i .. ": " .. vim.inspect(line))
-- end
-- local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
-- for i,line in ipairs(all_lines) do
-- 	if prev[i] ~= line then
-- 		table.insert(events, "DISC")
-- 	end
-- 	table.insert(events, i .. "> " .. vim.inspect(line))
-- end

@save_last_inserted_pid+=
lastPID = op[4]

@functions+=
local function findPIDBefore(opid)
	local x, y = findCharPositionBefore(opid, opid)
	if x == 1 then
		return pids[y-1][#pids[y-1]]
	elseif x then
		return pids[y][x-1]
	end
end

@save_last_deleted_pid+=
lastPID = findPIDBefore(op[2])

@declare_functions+=
local getConfig

@functions+=
function getConfig(varname, default)
	local v, value = pcall(function() return vim.api.nvim_get_var("instant_name_hl_group") end)
	if not v then value = default end
	return value
end

@script_variables+=
local vtextGroup

@init_client+=
vtextGroup = getConfig("instant_name_hl_group", "CursorLineNr")

@update_cursor_highlight+=
if lastPID then
	@find_pid_of_cursor
	@clear_virtual_text_if_present
	@clear_match_if_present
	if x then
		if x == 1 then x = 2 end
		@set_virtual_text_of_user
		@set_match_of_user
	end
end

@find_pid_of_cursor+=
local x, y = findCharPositionExact(lastPID)

@script_variables+=
local old_namespace

@init_client+=
old_namespace = {}

@clear_virtual_text_if_present+=
if old_namespace[aut] then
	vim.api.nvim_buf_clear_namespace(
		old_namespace[aut].buf, old_namespace[aut].id,
		0, -1)
	old_namespace[aut] = nil
end

@set_virtual_text_of_user+=
old_namespace[aut] = {
	id = vim.api.nvim_buf_set_virtual_text(
		buf, 0, 
		math.max(y-2, 0), 
		{{ aut, vtextGroup }}, 
		{}),
	buf = buf
}

@script_variables+=
local cursors = {}
local cursorGroup

@init_client+=
cursorGroup = getConfig("instant_cursor_hl_group", "Cursor")
cursors = {}

@clear_match_if_present+=
if cursors[aut] then
	vim.api.nvim_buf_clear_namespace(
		cursors[aut].buf, cursors[aut].id,
		0, -1)
	cursors[aut] = nil
end

@set_match_of_user+=
if prev[y-1] and x-2 >= 0 and x-2 <= utf8len(prev[y-1]) then
	local bx = vim.str_byteindex(prev[y-1], x-2)
	table.insert(events, "cursorGroup " .. cursorGroup)
	cursors[aut] = {
		id = vim.api.nvim_buf_add_highlight(buf,
			0, cursorGroup, y-2, bx, bx+1),
		buf = buf,
		line = y-2,
	}
	@set_cursor_extended_mark
end

@stop+=
for aut,_ in pairs(cursors) do
	@clear_match_if_present
	@clear_virtual_text_if_present
end
cursors = {}

@get_context_for_current_buffer+=
prev = allprev[buf]
pids = allpids[buf]

@init_context_for_current_buffer+=
allprev[buf] = {}
allpids[buf] = {}

@set_context_for_current_buffer+=
allprev[buf] = prev
allpids[buf] = pids

@script_variables+=
local sessionshare = false

@start_session_function+=
local function StartSession(host, port)
	@check_if_client_is_not_connected

	local first = true
	sessionshare = true
	@start
end

@start_session_function+=
local function JoinSession(host, port)
	@check_if_client_is_not_connected

	local first = false
	sessionshare = true
	@start
end

@export_symbols+=
StartSession = StartSession,
JoinSession = JoinSession,

@attach_to_all_opened_buffers+=
for _, buf in ipairs(bufs) do
	@attach_to_current_buffer
end

@init_content_for_all_opened_buffers+=
for _, buf in ipairs(bufs) do
	@get_buffer_lines
	@init_pids_of_buffer_content
	@init_prev_of_buffer_content
	@set_context_for_current_buffer
	@set_buf_table_for_opened_buffers
end

@get_buffer_number_to_apply_modifications+=
local buf
if sessionshare then
	@get_local_buf_from_remote
else
	buf = singlebuf
end

@send_client_informations+=
local obj = {
	["type"] = "info",
	["sessionshare"] = sessionshare,
	["author"] = author,
}
local encoded = vim.api.nvim_call_function("json_encode", { obj })
@send_encoded

@create_new_buffer+=
buf = vim.api.nvim_create_buf(true, true)

@script_variables+=
local loc2rem = {}
local rem2loc = {}

@init_client+=
loc2rem = {}
rem2loc = {}

@map_received_buffer_id+=
local ag, bufid = unpack(decoded["bufid"])
if not rem2loc[ag] then
	rem2loc[ag] = {}
end

rem2loc[ag][bufid] = buf
loc2rem[buf] = { ag, bufid }

@convert_local_to_remote_buffer+=
local rem = loc2rem[buf]

@get_local_buf_from_remote+=
local ag, bufid = unpack(decoded["buf"])
buf = rem2loc[ag][bufid]

@set_buf_table_for_opened_buffers+=
if not rem2loc[agent] then
	rem2loc[agent] = {}
end

rem2loc[agent][buf] = buf
loc2rem[buf] = { agent, buf }

@get_buf_name_relative_to_cwd_or_just_tail+=
local fullname = vim.api.nvim_buf_get_name(buf)
local cwdname = vim.api.nvim_call_function("fnamemodify",
	{ fullname, ":." })
local bufname = cwdname
if bufname == fullname then
	bufname = vim.api.nvim_call_function("fnamemodify",
	{ fullname, ":t" })
end

@rename_buffer_to_initial+=
if decoded["name"] and string.len(decoded["name"]) > 0 then
	vim.api.nvim_buf_set_name(buf, decoded["name"])
end

@get_all_text_edit_buffers+=
local allbufs = vim.api.nvim_list_bufs()
local bufs = {}
-- skip terminal, help, ... buffers
for _,buf in ipairs(allbufs) do
	local buftype = vim.api.nvim_buf_get_option(buf, "buftype")
	if buftype == "" then
		table.insert(bufs, buf)
	end
end

@script_variables+=
local vimcmd = vim.api.nvim_command

@register_autocommands_for_buffer_open_and_create+=
vimcmd("augroup instantSession")
vimcmd("autocmd!")
-- this is kind of messy
-- a better way to write this
-- would be great
vimcmd("autocmd BufNewFile,BufRead * call execute('lua instantOpenOrCreateBuffer(' . expand('<abuf>') . ')', '')")
vimcmd("augroup end")

@stop+=
@unregister_autocommands

@unregister_autocommands+=
vimcmd("augroup instantSession")
vimcmd("autocmd!")
vimcmd("augroup end")

@functions+=
function instantOpenOrCreateBuffer(buf)
	if sessionshare or buf == singlebuf then
		@get_buffer_lines
		@init_pids_of_buffer_content
		@init_prev_of_buffer_content
		@set_context_for_current_buffer

		@get_buf_name_relative_to_cwd_or_just_tail
		@map_new_buffer_id
		@encode_initial_content_single
		@send_encoded

		@attach_to_current_buffer
	end

end

@map_new_buffer_id+=
if not rem2loc[agent] then
	rem2loc[agent] = {}
end

rem2loc[agent][buf] = buf
loc2rem[buf] = { agent, buf }

local rem = loc2rem[buf]

@detect_file_type+=
if vim.api.nvim_buf_call then
	vim.api.nvim_buf_call(buf, function()
		vim.api.nvim_command("filetype detect")
	end)
end

@remove_buf_type_of_scratch_buffer+=
vim.api.nvim_buf_set_option(buf, "buftype", "")

@set_cursor_extended_mark+=
if vim.api.nvim_buf_set_extmark then
	cursors[aut].ext_id = 
		vim.api.nvim_buf_set_extmark(
			buf, cursors[aut].id, y-2, bx, {})
end

@script_variables+=
local status_cb = {}

@functions+=
local function attach_status_update(cb)
	table.insert(status_cb, cb)
	@get_all_user_infos
	return positions
end

@export_symbols+=
attach_status_update = attach_status_update,

@notify_status_callbacks+=
if #status_cb > 0 then
	@get_all_user_infos
	for _,cb in ipairs(status_cb) do
		cb(positions)
	end
end

@get_all_user_infos+=
local positions = {}
for aut, c in pairs(cursors) do 
	local buf = c.buf
	@get_buf_name_relative_to_cwd_or_just_tail
	@get_cursor_position_of_user
	table.insert(positions , {aut, bufname, line})
end

@get_cursor_position_of_user+=
local line
if c.ext_id then
	line,_ = unpack(vim.api.nvim_buf_get_extmark_by_id(
			buf, c.id, c.ext_id, {}))
else
	line= c.y
end
