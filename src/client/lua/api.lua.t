##../../instant_client
@script_variables+=
local api_attach = {}
local api_attach_id = 1

@api_functions+=
local function attach(callbacks)
	local o = {}
	for name, fn in pairs(callbacks) do
		@add_api_attach
		else 
			error("[instant.nvim] Unknown callback " .. name)
		end
	end
	api_attach[api_attach_id] = o
	api_attach_id = api_attach_id + 1
	return api_attach_id
end

@export_symbols+=
attach = attach,

@api_functions+=
local function detach(id)
	if not api_attach[id] then
		error("[instant.nvim] Could not detach (already detached?")
	end
	api_attach[id] = nil
end

@export_symbols+=
detach = detach,

@add_api_attach+=
if name == "on_connect" then
	o.on_connect = callbacks.on_connect

@call_connect_callbacks+=
for _, o in pairs(api_attach) do
	if o.on_connect then
		o.on_connect()
	end
end

@add_api_attach+=
elseif name == "on_disconnect" then
	o.on_disconnect = callbacks.on_disconnect

@call_disconnect_callbacks+=
for _, o in pairs(api_attach) do
	if o.on_disconnect then
		o.on_disconnect()
	end
end

@add_api_attach+=
elseif name == "on_change" then
	o.on_change = callbacks.on_change

@notify_change_callbacks+=
for _, o in pairs(api_attach) do
	if o.on_change then
		o.on_change(aut, buf, y-2)
	end
end

@add_api_attach+=
elseif name == "on_clientconnected" then
	o.on_clientconnected = callbacks.on_clientconnected

@call_client_connect_callbacks+=
for _, o in pairs(api_attach) do
	if o.on_clientconnected then
		o.on_clientconnected(new_aut)
	end
end

@add_api_attach+=
elseif name == "on_clientdisconnected" then
	o.on_clientdisconnected = callbacks.on_clientdisconnected

@call_client_disconnect_callbacks+=
for _, o in pairs(api_attach) do
	if o.on_clientdisconnected then
		o.on_clientdisconnected(aut)
	end
end

@api_functions+=
local function get_connected_list()
	local connected = {}
	for _, aut in pairs(id2author) do
		table.insert(connected, aut)
	end
	return connected
end

@export_symbols+=
get_connected_list = get_connected_list,

@add_api_attach+=
elseif name == "on_data" then
	o.on_data = callbacks.on_data

@message_types+=
DATA = 9,

@if_data_send_to_callbacks+=
if decoded[1] == MSG_TYPE.DATA then
	local _, data = unpack(decoded)
	@call_data_callbacks
end

@call_data_callbacks+=
for _, o in pairs(api_attach) do
	if o.on_data then
		o.on_data(data)
	end
end

@api_functions+=
local function send_data(data)
	local obj = {
		MSG_TYPE.DATA,
		data
	}

local encoded = vim.api.nvim_call_function("json_encode", { obj })
	@send_encoded
end

@export_symbols+=
send_data = send_data,

@api_functions+=
local function get_connected_buf_list()
	local bufs = {}
	for buf, _ in pairs(loc2rem) do
		table.insert(bufs, buf)
	end
	return bufs
end

@export_symbols+=
get_connected_buf_list = get_connected_buf_list,
