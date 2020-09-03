@*=
@requires
@script_variables
@fill_base64_table

@functions

@start_client
@stop_client

@attach_buffer_current_buffer
@detach_from_buffer

@script_variable+=
local client

@start_client+=
function StartClient(appuri)
	client = vim.loop.new_tcp()
	@get_ip_address
	client:connect(ipentry.addr, 80, vim.schedule_wrap(function(err) 
		client:read_start(vim.schedule_wrap(function(err, chunk)
			if reading then
				@read_response
			end
		end))
		@opening_handshake
	end))
end

@stop_client+=
function StopClient()
	@send_close_frame
	@close_client
end

@close_client+=
client:close()

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

@script_variables+=
local websocketkey

@opening_handshake+=
client:write("GET / HTTP/1.1\r\n")
client:write("Host: " .. appuri .. ":80\r\n")
client:write("Upgrade: websocket\r\n")
client:write("Connection: Upgrade\r\n")
websocketkey = ConvertToBase64(GenerateWebSocketKey())
client:write("Sec-WebSocket-Key: " .. websocketkey .. "\r\n")
client:write("Sec-WebSocket-Version: 13\r\n")
client:write("\r\n")

@client_connected+=
print("client connected!")

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

@read_response+=
if chunk then
	local opcode
	@read_opcode
	@do_opcode
end

@do_opcode+=
if opcode == 0x1 then -- TEXT
	@read_payload_length
	@read_payload
	@interpret_received_text
end

@script_variables+=
frames = {}

@read_opcode+=
local b1 = string.byte(string.sub(chunk,1,1))
table.insert(frames, "FIN " .. OpAnd(b1, 0x80))
table.insert(frames, "OPCODE " .. OpAnd(b1, 0xF))
local b2 = string.byte(string.sub(chunk,2,2))
table.insert(frames, "MASK " .. OpAnd(b2, 0x80))
opcode = OpAnd(b1, 0xF)

@read_payload_length+=
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

@read_payload+=
local text = string.sub(chunk, 2+paylenlen+1)

@script_variables+=
reading = false
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
if opcode == 0x9 then -- TEXT
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

@script_variable+=
local curbuf

@attach_buffer_current_buffer+=
function AttachToBuffer(bufnr)
	table.insert(events, "Attaching to buffer " .. bufnr)
	curbuf = bufnr
	@register_buf_change_callback
end

@register_buf_change_callback+=
vim.api.nvim_buf_attach(bufnr, false, {
	on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
		@return_true_if_detach
		@if_ignore_tick_return
		@retrieve_new_lines
		@encode_in_json
		@send_new_lines
	end
})

@script_variable+=
local detach = false

@return_true_if_detach
if detach then
	table.insert(events, "Detached from buffer")
	return true
end

@detach_from_buffer+=
function DetachToBuffer(bufnr)
	table.insert(events, "Detaching from buffer...")
	detach = true
end

@retrieve_new_lines+=
local lines = vim.api.nvim_buf_get_lines(bufnr, firstline, new_lastline, true)

@encode_in_json+=
local encoded = vim.fn.json_encode({
	["start"] = firstline,
	["end"]   = lastline,
	["text"] = table.concat(lines, '\n')
})

@send_new_lines+=
SendText(encoded)

@interpret_received_text+=
@decode_json
if decoded then
	@get_changedtick_and_add_to_ignore
	@set_lines
else
	table.insert(events, "Could not decode json " .. text)
end

@decode_json+=
local decoded = vim.fn.json_decode(text)

@script_variable+=
local ignores = {}

@get_changedtick_and_add_to_ignore+=
local tick = vim.api.nvim_buf_get_changedtick(curbuf)+1
ignores[tick] = true

@if_ignore_tick_return+=
if ignores[changedtick] then
	return
end

@set_lines+=
local lines = {}
for line in vim.gsplit(decoded["text"], '\n') do
	table.insert(lines, line)
end
vim.api.nvim_buf_set_lines(curbuf, decoded["start"], decoded["end"], true, lines)
