##../../instant_client
@status_function+=
local function Status()
	if ws_client and ws_client:is_active() then
		@get_all_user_infos
		@print_connection_status
	else
		print("Disconnected.")
	end
end

@export_symbols+=
Status = Status,

@print_connection_status+=
local info_str = {}
for _,pos in ipairs(positions) do
	table.insert(info_str, table.concat(pos, " "))
end
print("Connected. " .. #info_str .. " other client(s)\n\n" .. table.concat(info_str, "\n"))

@get_all_user_infos+=
local positions = {}
for _, aut in pairs(id2author) do 
	local c = cursors[aut]
	if c then
		local buf = c.buf
		@get_buf_name_relative_to_cwd_or_just_tail
		@get_cursor_position_of_user
		table.insert(positions , {aut, bufname, line+1})
	else
		table.insert(positions , {aut, "", ""})
	end
end

@get_cursor_position_of_user+=
local line
if c.ext_id then
	line,_ = unpack(vim.api.nvim_buf_get_extmark_by_id(
			buf, c.id, c.ext_id, {}))
else
	line= c.y
end

@message_types+=
CONNECT = 7,

@if_connect_save_client_id_and_username+=
if decoded[1] == MSG_TYPE.CONNECT then
	local _, new_id, new_aut = unpack(decoded)
	author2id[new_aut] = new_id
	id2author[new_id] = new_aut
	@init_client_highlight_group
	@call_client_connect_callbacks
end

@message_types+=
DISCONNECT = 8,

@if_disconnect_remove_client_id_and_username+=
if decoded[1] == MSG_TYPE.DISCONNECT then
	local _, remove_id = unpack(decoded)
	local aut = id2author[remove_id]
	if aut then
		author2id[aut] = nil
		id2author[remove_id] = nil
		@remove_client_hl_group
		@call_client_disconnect_callbacks
	end
end
