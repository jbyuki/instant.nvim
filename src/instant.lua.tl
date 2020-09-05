@*=
@requires
@script_variables
@fill_base64_table

@declare_functions
@functions

@start_client
@join_client
@stop_client
@refresh_client

@set_username

@attach_buffer
@detach_from_buffer
@write_queued_changes

@start_function
@stop_function

return {
@export_symbols
}

@script_variables+=
local client

@start_client+=
function StartClient(first, appuri, port)
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
		local opcode
		@read_opcode
		@do_opcode
	end
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
		@retrieve_new_lines
		@retrieve_filename_relative_to_instant_root
		@encode_in_json
		@send_encoded
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

@retrieve_new_lines+=
local lines = vim.api.nvim_buf_get_lines(buf, firstline, new_lastline, true)

@retrieve_filename_relative_to_instant_root+=
local filename
if not single_buffer then
	filename = string.sub(vim.api.nvim_buf_get_name(bufhandle), #InstantRoot+1)
end

@encode_in_json+=
local encoded = vim.fn.json_encode({
	["filename"] = filename,
	["type"] = "text",
	["start"] = firstline,
	["end"]   = lastline,
	["last"]   = new_lastline,
	["author"] = vim.g.instant_username,
	["text"] = table.concat(lines, '\n')
})

@send_encoded+=
SendText(encoded)

@interpret_received_text+=
@decode_json
if decoded then
	@if_text_add_new_lines_to_buffer
	@if_request_send_all_lines
	@if_initial_and_not_initialized_set_buffer_lines
	@if_available_check_if_its_ok
else
	table.insert(events, "Could not decode json " .. text)
end

@if_text_add_new_lines_to_buffer+=
if decoded["type"] == "text" then
	if single_buffer then
		local buf = vim.api.nvim_get_current_buf()
		@get_changedtick_and_add_to_ignore
		@set_lines
		@clear_virtual_for_username
		@set_virtual_text_for_usernames
	else 
		@check_if_text_edit_is_in_buffer
		@check_if_file_is_in_directory
		if in_buffer and in_directory then
			@get_buffer_number_of_filename
			@get_changedtick_and_add_to_ignore
			@set_lines
			@clear_virtual_for_username
			@set_virtual_text_for_usernames
		elseif in_directory then
			@if_file_does_not_exist_create_empty_file
			@queue_up_text_edit_for_later_use
		end
	end
end

@check_if_text_edit_is_in_buffer+=
local filename = vim.api.nvim_call_function("simplify", {InstantRoot .. decoded["filename"]})
local in_buffer = vim.api.nvim_call_function("bufnr", { filename .. "$" }) ~= -1

@check_if_file_is_in_directory+=
local in_directory = string.len(filename) > 0 and string.sub(filename, 1, #InstantRoot) == InstantRoot

@get_buffer_number_of_filename+=
local buf = vim.api.nvim_call_function("bufnr", { filename .. "$" })

@if_file_does_not_exist_create_empty_file+=
if string.len(vim.api.nvim_call_function("glob", { filename })) == 0 then
	local new_file = io.open(filename, "w")
	table.insert(events, "created new file " .. filename)
	new_file:close()
end

@script_variables+=
local queue

@init_client+=
queue = {}

@queue_up_text_edit_for_later_use+=
table.insert(events, "queue up edits for " .. filename)
table.insert(queue, decoded)

@decode_json+=
local decoded = vim.fn.json_decode(text)

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
	single_buffer = cur_buffer

	if not cur_buffer then
		@check_if_directory_exists_and_set_it
		@check_if_there_is_settings_or_empty_directory
		@if_not_settings_create_one
	end
	@start
	if not cur_buffer then
		@attach_to_running_buffers
	else 
		@attach_to_current_buffer
	end
end

@script_variables+=
local InstantRoot

@check_if_directory_exists_and_set_it+=
local directory = vim.api.nvim_call_function("getcwd", {})
if vim.api.nvim_call_function("isdirectory", { directory }) == 0 then
	error("The directory " .. directory .. " has not been found")
end
InstantRoot = vim.api.nvim_call_function("fnamemodify", {directory, ":p"})
table.insert(events, "The instant directory root is " .. InstantRoot)

@start+=
StartClient(first, host, port)

@stop_function+=
local function Stop()
	@stop
	print("Disconnected!")
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
	if single_buffer then
		@get_all_lines_in_current_buffer
		@encode_initial_content_single
		@send_encoded
	else 
		@glob_all_files_in_instant_root_directory
		local contents = {}
		for _,file in ipairs(files) do
			@check_if_file_is_open_in_buffer
			@if_it_is_retrieve_lines_from_buffer
			@otherwise_read_file
			@add_lines_to_contents
		end
		@encode_initial_content
		@send_encoded
	end
end

@glob_all_files_in_instant_root_directory+=
local filelist = vim.api.nvim_call_function("glob", { InstantRoot .. "**" })
local files = {}
if string.len(filelist) > 0 then
	for file in vim.gsplit(filelist, '\n') do
		table.insert(files, file)
	end
end
table.insert(events, "files found : " .. table.concat(files, " "))

@check_if_file_is_open_in_buffer+=
local in_buffer = vim.api.nvim_call_function("bufnr", { file .. "$" }) ~= -1

@if_it_is_retrieve_lines_from_buffer+=
local lines
if in_buffer then
	lines = vim.api.nvim_buf_get_lines(
		vim.api.nvim_call_function("bufnr", { file  .. "$" }), 
		0, -1, true)
@otherwise_read_file+=
else 
	lines = {}
	for line in io.lines(file) do
		table.insert(lines, line)
	end
end

@add_lines_to_contents+=
local content = {
	filename = string.sub(file, string.len(InstantRoot)+1),
	text = table.concat(lines, '\n')
}
table.insert(contents, content)

@encode_initial_content+=
local encoded = vim.fn.json_encode({
	["type"] = "initial",
	["contents"] = contents
})

@handshake_finished+=
local encoded = vim.fn.json_encode({
	["type"] = "available"
})
@send_encoded

@script_variables+=
local initialized

@init_client+=
initialized = false

@if_initial_and_not_initialized_set_buffer_lines+=
if decoded["type"] == "initial" and not initialized then
	if single_buffer then
		table.insert(events, "setting initial content for single buffer")
		@check_if_not_sent_for_multiple
		@get_lines_of_initial_single
		local buf = vim.api.nvim_get_current_buf()
		@get_changedtick_and_add_to_ignore
		@set_lines_in_current_buffer
	else 
		@check_if_not_sent_for_single
		for _,content in ipairs(decoded["contents"]) do 
			@check_if_filename_is_already_in_buffer
			@get_lines_array
			if in_buffer then
				@get_buffer_number_of_filename
				@get_changedtick_and_add_to_ignore
				@set_lines_in_buffer
			else 
				@write_file_with_lines
			end
		end
	end
	print("Connected!")
	initialized = true
end

@check_if_filename_is_already_in_buffer+=
local filename = InstantRoot .. content["filename"]
local in_buffer = vim.api.nvim_call_function("bufnr", { filename .. "$" }) ~= -1

@get_lines_array+=
local lines = {}
for line in vim.gsplit(content["text"], '\n') do
	table.insert(lines, line)
end

@set_lines_in_buffer+=
vim.api.nvim_buf_set_lines(
	vim.api.nvim_call_function("bufnr", { filename .. "$" }),
	0, 
	-1, 
	false, 
	lines)

@write_file_with_lines+=
local syncfile = io.open(filename, "w")
for _,line in ipairs(lines) do
	syncfile:write(line .. '\n')
end
syncfile:close()

@if_available_check_if_its_ok+=
if decoded["type"] == "response" then
	if decoded["is_first"] and first then
		print("Connected!")
		initialized = true
	elseif not decoded["is_first"] and not first then
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
local encoded = vim.fn.json_encode({
	["type"] = "request",
})
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
if not vim.g.instant_username or string.len(vim.g.instant_username) == 0 then
	error("Please specify a username in vim.g.instant_username")
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
		math.max(decoded["last"]-1, 0), 
		{{ " | " .. decoded["author"], "Special" }}, 
		{})

@check_for_connection_errors_when_connected+=
if err then
	table.insert(events, "connection err " .. vim.inspect(err))
	error("There was an error during connection: " .. err)

	@stop
	return
end

@attach_to_running_buffers+=
for _,bufhandle in ipairs(vim.api.nvim_list_bufs()) do
	if vim.api.nvim_buf_is_loaded(bufhandle) then
		@check_if_buffer_is_in_ntrangle_root
		@if_it_is_attach_callback
	end
end

@check_if_buffer_is_in_ntrangle_root+=
local buf_filename = vim.api.nvim_buf_get_name(bufhandle)
local is_in_root = string.len(buf_filename) > 0 and string.sub(buf_filename, 1, #InstantRoot) == InstantRoot

@if_it_is_attach_callback+=
if is_in_root then
	table.insert(events, "Attaching to buffer " .. bufhandle)
	@init_buffer_attach
	@register_buf_change_callback
end

@attach_buffer+=
local function AttachToBuffer()
	@check_if_client_is_initialized
	@check_if_in_directory_sharing
	local bufhandle = vim.api.nvim_get_current_buf()
	@check_if_buffer_is_not_attached_already
	@check_if_buffer_is_in_ntrangle_root
	@ignore_if_settings_file
	if is_in_root then
		table.insert(events, "Attaching callback to " .. bufhandle)
		@init_buffer_attach
		@apply_queued_edits_if_they_are
		@send_whole_buffer
		@register_buf_change_callback
		table.insert(events, "Attach was " .. vim.inspect(attach_success))
	end
end

@check_if_client_is_initialized+=
if not initialized then
	return
end

@export_symbols+=
AttachToBuffer = AttachToBuffer,

@apply_queued_edits_if_they_are+=
local i = 1
while i <= #queue do
	local decoded = queue[i]
	local filename = vim.api.nvim_call_function("simplify", {InstantRoot .. decoded["filename"]})
	@get_buffer_number_of_filename
	if bufhandle == buf then
		@get_changedtick_and_add_to_ignore
		@set_lines
		table.remove(queue, i)
	else
		i = i + 1
	end
end

@check_if_there_is_settings_or_empty_directory+=
if string.len(vim.api.nvim_call_function("glob", { InstantRoot .. "*" })) ~= 0 and string.len(vim.api.nvim_call_function("glob", { InstantRoot .. "instant.json" })) == 0 then
	error("The current directory is not empty nor does it contain a instant.json settings file")
	return
end


@if_not_settings_create_one+=
if string.len(vim.api.nvim_call_function("glob", { "**" })) == 0 then
	local settings = {}
	@init_settings
	local settingsFile = io.open("instant.json", "w")
	settingsFile:write(vim.fn.json_encode(settings))
	settingsFile:close()
end

@init_settings+=
settings["createddate"] = os.date("!%c") .. " UTC"
settings["author"] = vim.g.instant_username

@ignore_if_settings_file+=
if string.match(buf_filename, "instant.json$") then
	return
end

@declare_functions+=
local writeChanges

@write_queued_changes+=
function writeChanges()
	@collect_filename_list_of_queued
	for file,_ in pairs(files) do
		@get_absolute_filename
		@read_lines_from_file
		i = 1
		while i <= #queue do 
			local decoded = queue[i]
			if decoded["filename"] == file then
				@apply_edits_to_list_of_lines
				table.remove(queue, i)
			else 
				i = i + 1
			end
		end
		@write_lines_to_file
	end
end

@collect_filename_list_of_queued+=
local files = {}
for _,decoded in ipairs(queue) do
	files[decoded["filename"]] = true
end

@get_absolute_filename+=
local filename = vim.api.nvim_call_function("simplify", {InstantRoot .. file})

@read_lines_from_file+=
local filelines = {}
for line in io.lines(filename) do
	table.insert(filelines, line)
end

@write_lines_to_file+=
local outfile = io.open(filename, "w")
for _,line in ipairs(filelines) do
	outfile:write(line .. "\n")
end
outfile:close()

@apply_edits_to_list_of_lines+=
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

@remove_lines_in_range_in_lines
@insert_new_lines_in_lines

@remove_lines_in_range_in_lines+=
for i=decoded["start"], decoded["end"]-1 do
	table.remove(filelines, i+1)
end

@insert_new_lines_in_lines+=
for i,line in ipairs(lines) do
	table.insert(filelines, decoded["start"]+i, line)
end

@stop+=
writeChanges()

@send_whole_buffer+=
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
@send_encoded

@attach_to_current_buffer+=
local bufhandle = vim.api.nvim_get_current_buf()
@init_buffer_attach
@register_buf_change_callback

@get_all_lines_in_current_buffer+=
local lines = vim.api.nvim_buf_get_lines(
	bufhandle,
	0, -1, true)

@encode_initial_content_single+=
local encoded = vim.fn.json_encode({
	["type"] = "initial",
	["content"] = table.concat(lines, '\n')
})

@check_if_not_sent_for_multiple+=
if decoded["contents"] then 
	table.insert(events, "ERROR: Initial content for directory sharing but in single buffer sharing")
	error("Initial content for directory sharing but in single buffer sharing")
end

@check_if_not_sent_for_single+=
if decoded["content"] then 
	table.insert(events, "ERROR: Initial content for single buffer sharing but in directory sharing")
	error("ERROR: Initial content for single buffer sharing but in directory sharing")
end

@get_lines_of_initial_single+=
local lines = {}
for line in vim.gsplit(decoded["content"], "\n") do
	table.insert(lines, line)
end

@set_lines_in_current_buffer+=
vim.api.nvim_buf_set_lines(
	vim.api.nvim_get_current_buf(),
	0, -1, false, lines)

@check_if_in_directory_sharing+=
if single_buffer then
	return
end
