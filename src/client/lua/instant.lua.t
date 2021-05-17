##../../instant_client
@../lua/instant.lua=
@requires
@declare_functions
@script_variables
local MSG_TYPE = {
@message_types
}
local OP_TYPE = {
@operation_types
}

@functions

@start_client

@detach_from_buffer

@start_function
@stop_function

@start_session_function

@status_function
@follow_function
@special_save_function
@special_open_function

@undo_redo_functions

@api_functions

return {
@export_symbols
}

@script_variables+=
local ws_client

@requires+=
local websocket_client = require("instant.websocket_client")

@start_client+=
local function StartClient(first, appuri, port)
	@check_if_has_username
	@init_client
	ws_client = websocket_client { uri = appuri, port = port }
	ws_client:connect {
		on_connect = function()
			@handshake_finished
			@call_connect_callbacks
      vim.schedule(function() print("Connected!") end)
		end,
		on_text = function(wsdata)
			@interpret_received_text
		end,
		on_disconnect = function()
			@stop
			@call_disconnect_callbacks
			vim.schedule(function() print("Disconnected.") end)
		end
	}
end

@stop_client+=
ws_client:disconnect()
ws_client = nil

@script_variables+=
local singlebuf

@start_function+=
local function Start(host, port)
	@check_if_client_is_not_connected
  @register_autocommands_if_not_not_done

  local buf = vim.api.nvim_get_current_buf()
	singlebuf = buf
	local first = true
	sessionshare = false
	@start

end

@create_new_buffer_for_single+=
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_win_set_buf(0, buf)

@start_function+=
local function Join(host, port)
	@check_if_client_is_not_connected
  @register_autocommands_if_not_not_done

  @create_new_buffer_for_single
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
	@stop_client
end

@stop+=
for bufhandle,_ in pairs(allprev) do
	if vim.api.nvim_buf_is_loaded(bufhandle) then
		DetachFromBuffer(bufhandle)
	end
end

@script_variables+=
local sessionshare = false

@start_session_function+=
local function StartSession(host, port)
	@check_if_client_is_not_connected
  @register_autocommands_if_not_not_done

	local first = true
	sessionshare = true
	@start
end

@start_session_function+=
local function JoinSession(host, port)
	@check_if_client_is_not_connected
  @register_autocommands_if_not_not_done

	local first = false
	sessionshare = true
	@start
end

@export_symbols+=
StartSession = StartSession,
JoinSession = JoinSession,

@stop+=
agent = 0
