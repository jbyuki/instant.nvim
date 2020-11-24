@../lua/instant/websocket.lua=
@requires
@script_variables
@fill_base64_table
@declare_functions
@functions

local function WebSocket(opt)
	@get_ip_address
	@set_port_as_80_if_not_provided
	@create_new_tcp_connection

	@internal_variables
	local ws = {}
	@methods

	return setmetatable({}, { __index = ws})
end

return WebSocket

@script_variables+=
events = {}

@get_ip_address+=
local iptable = vim.loop.getaddrinfo(opt.uri)
if #iptable == 0 then
	print("Could not resolve address")
	return
end
local ipentry = iptable[1]

@set_port_as_80_if_not_provided+=
local port = opt.port or 80

@create_new_tcp_connection+=
local client = vim.loop.new_tcp()

@methods+=
function ws:connect(callbacks)
	client:connect(ipentry.addr, port, vim.schedule_wrap(function(err) 
		@save_on_disconnect_callback
		@check_for_connection_errors
		client:read_start(vim.schedule_wrap(function(err, chunk)
			@check_for_connection_errors_when_connected
			@read_response
		end))
		@opening_handshake
	end))
end

@check_for_connection_errors+=
if err then
	@stop
	error("There was an error during connection: " .. err)
	return
end

@check_for_connection_errors_when_connected+=
if err then
	@stop
	error("There was an error during connection: " .. err)
	return
end

@declare_functions+=
local GenerateWebSocketKey -- we must forward declare local functions because otherwise it picks the global one

@functions+=
function GenerateWebSocketKey()
	@generate_16_bytes_array
	return key
end

@generate_16_bytes_array+=
key = {}
math.randomseed(os.time())
for i =0,15 do
	table.insert(key, math.random(0, 255))
end

@requires+=
local base64 = require("instant.base64")

@internal_variables+=
local websocketkey

@opening_handshake+=
client:write("GET / HTTP/1.1\r\n")
client:write("Host: " .. opt.uri .. ":" .. port .. "\r\n")
client:write("Upgrade: websocket\r\n")
client:write("Connection: Upgrade\r\n")
websocketkey = base64.encode(GenerateWebSocketKey())
client:write("Sec-WebSocket-Key: " .. websocketkey .. "\r\n")
client:write("Sec-WebSocket-Version: 13\r\n")
client:write("\r\n")

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

@internal_variables+=
local frames = {}
local fragmented = ""
local remaining = 0
local first_chunk

@read_response+=
if chunk then
	if string.match(chunk, nocase("^HTTP")) then
		-- can be Sec-WebSocket-Accept or Sec-Websocket-Accept
		if string.match(chunk, nocase("Sec%-WebSocket%-Accept")) then
			@handshake_finished
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
			@read_opcode
			@do_opcode
		end
	end
end

@handshake_finished+=
if callbacks.on_connect then
	callbacks.on_connect()
end

@internal_variables+=
local wsdata = ""
local opcode

@read_opcode+=
local b1 = string.byte(string.sub(first_chunk,1,1))
local b2 = string.byte(string.sub(first_chunk,2,2))
if string.len(wsdata) == 0 then
	opcode = bit.band(b1, 0xF)
end
fin = bit.rshift(b1, 7)

@internal_variables+=
local on_disconnect

@save_on_disconnect_callback+=
on_disconnect = callbacks.on_disconnect

@methods+=
function ws:disconnect()
	@send_close_frame
	@close_client
	@stop
end

@stop+=
if on_disconnect then
	on_disconnect()
end

@close_client+=
client:close()
client = nil

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
if opcode == 0x1 then -- TEXT
	@read_payload_length
	if remaining == 0 then
		@read_payload
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
			@interpret_received_text
			wsdata = ""
		end
	end
end

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

@read_payload+=
local text = string.sub(chunk, 2+paylenlen+1, 2+paylenlen+1+(paylen-1))

@interpret_received_text+=
if callbacks.on_text then
	callbacks.on_text(wsdata)
end

@do_opcode+=
if opcode == 0x9 then -- PING
	@read_payload_length
	@send_pong
	chunk = ""
end

@send_pong+=
@generate_mask
local frame = {
	0x8A, 0x80,
}
for i=1,4 do 
	table.insert(frame, mask[i])
end
@convert_frame_to_string
@send_frame

@declare_functions+=
local send_text

@internal_variables+=
local max_before_frag = opt.max_before_frag or 8192

@methods+=
function ws:send_text(str)
	@generate_mask
	@mask_text

	local remain = #masked
	local sent = 0
	while remain > 0 do
		local send = math.min(max_before_frag, remain) -- max size before fragment
		remain = remain - send
		@create_base_frame
		@convert_frame_to_string
		@send_frame
		sent = sent + send
	end
end


@generate_mask+=
local mask = {}
for i=1,4 do
	table.insert(mask, math.random(0, 255))
end

@requires+=
local bit = require("bit")

@declare_functions+=
local maskText

@functions+=
function maskText(str, mask)
	local masked = {}
	for i=0,#str-1 do
		local j = bit.band(i, 0x3)
		local trans = bit.bxor(string.byte(string.sub(str, i+1, i+1)), mask[j+1])
		table.insert(masked, trans)
	end
	return masked
end

@mask_text+=
local masked = maskText(str, mask)

@create_base_frame+=
local fin
if remain == 0 then fin = 0x80
else fin = 0 end

local opcode
if sent == 0 then opcode = 1
else opcode = 0 end


local frame = {
	fin+opcode, 0x80
}

@write_payload_length

for i=1,4 do
	table.insert(frame, mask[i])
end

for i=sent+1,sent+1+(send-1) do
	table.insert(frame, masked[i])
end

@write_payload_length+=
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

@declare_functions+=
local convert_bytes_to_string

@functions+=
function convert_bytes_to_string(tab)
	local s = ""
	for _,el in ipairs(tab) do
		s = s .. string.char(el)
	end
	return s
end

@convert_frame_to_string+=
local s = convert_bytes_to_string(frame)

@send_frame+=
client:write(s)
