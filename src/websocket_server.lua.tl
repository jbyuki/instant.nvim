@../lua/instant/websocket_server.lua=
@requires
@script_variables

@declare_functions
@functions

local conn_proto = {}
@client_connection_methods

local function WebSocketServer(opt)
	@set_ip_address_as_localhost_if_not_provided
	@set_port_as_8080_if_not_provided
	@create_new_tcp_server

	@internal_variables
	local ws = {}
	@member_variables
	@methods

	return setmetatable({}, { __index = ws})
end

return WebSocketServer

@set_ip_address_as_localhost_if_not_provided+=
local host = opt.host or "127.0.0.1"

@set_port_as_8080_if_not_provided+=
local port = opt.port or 8080

@create_new_tcp_server+=
local server = vim.loop.new_tcp()
server:bind(host, port)

@methods+=
function ws:listen(callbacks)
	local ret, err = server:listen(128, function(err)
		assert(not err, err)
		local sock = vim.loop.new_tcp()
		server:accept(sock)
		local conn
		@client_internal_variables
		@call_callbacks_connected
		@register_socket_read_callback
	end)

	if not ret then
		error(err)
	end
end

@register_socket_read_callback+=
sock:read_start(function(err, chunk)
	assert(not err, err)
	if chunk then
		@read_message_tcp
	else
		@close_client_callbacks
		@remove_client
		sock:shutdown()
		sock:close()
	end
end)

@client_internal_variables+=
local upgraded = false
local http_data = ""

local remaining = 0
local first_chunk

@read_message_tcp+=
if not upgraded then
	http_data = http_data .. chunk
	if string.match(http_data, "\r\n\r\n$") then
		@read_http_data
		http_data = ""
	end
else
	local fin
	while string.len(chunk) > 0 do
		if remaining == 0 then
			first_chunk = chunk
		end
		@read_opcode
		@do_opcode
		else 
			chunk = ""
			remaining = 0
		end
	end
end

@read_http_data+=
local has_upgrade = false
local websocketkey
for line in vim.gsplit(http_data, "\r\n") do
	if string.match(line, "Upgrade: websocket") then
		has_upgrade = true
	elseif string.match(line, "Sec%-WebSocket%-Key") then
		@read_websocket_key
	end
end

if has_upgrade then
	@compute_key_sha1
	@send_websocket_accept_upgrade
	upgraded = true
end

@member_variables+=
ws.conns = conns

@script_variables+=
local conns = {}
local conn_id = 100

@call_callbacks_connected+=
if callbacks.on_connect then
	conn = setmetatable(
		{ id = conn_id, sock = sock }, 
		{ __index = conn_proto })
	conns[conn_id] = conn
	conn_id = conn_id + 1

	callbacks.on_connect(conn)
end

@read_websocket_key+=
websocketkey = string.match(line, "Sec%-WebSocket%-Key: ([=/+%w]+)")

@requires+=
local base64 = require("instant.base64")
local sha1 = require("instant.sha1")

@compute_key_sha1+=
local decoded = base64.decode(websocketkey)
local hashed = base64.encode(sha1(decoded))

@send_websocket_accept_upgrade+=
sock:write("HTTP/1.1 101 Switching Protocols\r\n")
sock:write("Upgrade: websocket\r\n")
sock:write("Connection: Upgrade\r\n")
sock:write("Sec-WebSocket-Accept: " .. hashed .. "\r\n")
sock:write("Sec-WebSocket-Protocol: chat\r\n")
sock:write("\r\n")

@client_connection_methods+=
function conn_proto:attach(callbacks)
	self.callbacks = callbacks
end

@client_internal_variables+=
local opcode
local wsdata = ""
local fragmented = ""

@read_opcode+=
local b1 = string.byte(string.sub(first_chunk,1,1))
local b2 = string.byte(string.sub(first_chunk,2,2))
if string.len(wsdata) == 0 then
	opcode = bit.band(b1, 0xF)
end
fin = bit.rshift(b1, 7)

@do_opcode+=
if opcode == 0x1 then -- TEXT
	@read_payload_length
	@read_mask
	if remaining == 0 then
		@read_payload
		@unmask_data
		chunk = string.sub(chunk, 2+paylenlen+1+paylen+4)
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
local text = string.sub(chunk, 2+paylenlen+1+4, 2+paylenlen+1+4+(paylen-1))

@interpret_received_text+=
if conn and conn.callbacks.on_text then
	conn.callbacks.on_text(wsdata)
end

@close_client_callbacks+=
if conn and conn.callbacks.on_disconnect then
	conn.callbacks.on_disconnect()
end

@remove_client+=
conns[conn.id] = nil

@read_mask+=
local mask = {}
for i=2+paylenlen+1, 2+paylenlen+4 do
	table.insert(mask, string.byte(string.sub(first_chunk, i, i)))
end

@declare_functions+=
local unmask_text

@functions+=
function unmask_text(str, mask)
	local unmasked = {}
	for i=0,#str-1 do
		local j = bit.band(i, 0x3)
		local trans = bit.bxor(string.byte(string.sub(str, i+1, i+1)), mask[j+1])
		table.insert(unmasked, trans)
	end
	return unmasked
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

@unmask_data+=
local unmasked = unmask_text(text, mask)
text = convert_bytes_to_string(unmasked)

@script_variables+=
local max_before_frag = 8192

@client_connection_methods+=
function conn_proto:send_text(str)
	table.insert(events, "send text " .. self.id)
	local remain = #str
	local sent = 0
	while remain > 0 do
		local send = math.min(max_before_frag, remain) -- max size before fragment
		remain = remain - send
		@create_base_frame
		@create_str_to_send
		@send_frame
		sent = sent + send
	end
end

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

@create_str_to_send+=
local control = convert_bytes_to_string(frame)
local tosend = control .. str

@send_frame+=
table.insert(events, "send text " .. self.id)
conns[self.id].sock:write(tosend)

@client_connection_methods+=
function conn_proto:send_json(obj)
	local encoded = vim.api.nvim_call_function("json_encode", {obj})
	self:send_text(encoded)
end
