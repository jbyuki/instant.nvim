##../../instant_client
@save_last_inserted_pid+=
lastPID = op[3]

@functions+=
local function findPIDBefore(opid)
	local x, y = findCharPositionBefore(opid)
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
	local v, value = pcall(function() return vim.api.nvim_get_var(varname) end)
	if not v then value = default end
	return value
end

@script_variables+=
local vtextGroup

@init_client+=
vtextGroup = {
	getConfig("instant_name_hl_group_user1", "CursorLineNr"),
	getConfig("instant_name_hl_group_user2", "CursorLineNr"),
	getConfig("instant_name_hl_group_user3", "CursorLineNr"),
	getConfig("instant_name_hl_group_user4", "CursorLineNr"),
	getConfig("instant_name_hl_group_default", "CursorLineNr")
}

@update_cursor_highlight+=
@clear_virtual_text_if_present
@clear_match_if_present
if x then
	if x == 1 then x = 2 end
	@set_virtual_text_of_user
	@set_match_of_user
end
@if_follow_this_author_center_view

@find_pid_of_cursor+=
local x, y = findCharPositionExact(lastPID)

@script_variables+=
local old_namespace

@init_client+=
old_namespace = {}

@clear_virtual_text_if_present+=
if old_namespace[aut] then
	if attached[old_namespace[aut].buf] then
		vim.api.nvim_buf_clear_namespace(
			old_namespace[aut].buf, old_namespace[aut].id,
			0, -1)
	end
	old_namespace[aut] = nil
end

@set_virtual_text_of_user+=
old_namespace[aut] = {
  id = vim.api.nvim_create_namespace(aut),
  buf = buf,
}

vim.api.nvim_buf_set_extmark(
  buf,
  marks[other_agent].ns_id,
  sy - 2,
  0,
  {
    virt_text = {{  aut, vtextGroup[client_hl_group[other_agent]] } },
    virt_text_pos = "right_align"
})

@script_variables+=
local cursors = {}
local cursorGroup

@init_client+=
cursorGroup = {
	getConfig("instant_cursor_hl_group_user1", "Cursor"),
	getConfig("instant_cursor_hl_group_user2", "Cursor"),
	getConfig("instant_cursor_hl_group_user3", "Cursor"),
	getConfig("instant_cursor_hl_group_user4", "Cursor"),
	getConfig("instant_cursor_hl_group_default", "Cursor")
}

cursors = {}

@clear_match_if_present+=
if cursors[aut] then
	if attached[cursors[aut].buf] then
		vim.api.nvim_buf_clear_namespace(
			cursors[aut].buf, cursors[aut].id,
			0, -1)
	end
	cursors[aut] = nil
end

@set_match_of_user+=
if prev[y-1] and x-2 >= 0 and x-2 <= utf8len(prev[y-1]) then
	local bx = vim.str_byteindex(prev[y-1], x-2)
	cursors[aut] = {
		id = vim.api.nvim_buf_add_highlight(buf,
			0, cursorGroup[client_hl_group[other_agent]], y-2, bx, bx+1),
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
