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
			print("Connected!")
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
local attached = {}

@register_buf_change_callback+=
if not attached[buf] then
	local attach_success = vim.api.nvim_buf_attach(buf, false, {
		on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
			@return_true_if_detach
			@if_ignore_tick_return

			@get_context_for_current_buffer
			@get_both_ranges
			@get_xor_range
			@if_there_is_text_to_delete_delete_it
			@if_there_is_text_to_insert_insert_it
			@set_context_for_current_buffer
			@push_on_undo_stack

		end,
		on_detach = function(_, buf)
			attached[buf] = nil
		end
	})

	@register_undo_redo_commands

	if attach_success then
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
	detach[buf] = nil
	return true
end

@init_buffer_attach+=
detach[buf] = nil

@declare_functions+=
local DetachFromBuffer

@detach_from_buffer+=
function DetachFromBuffer(bufnr)
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
			@get_character_to_delete
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

@get_character_to_delete+=
local c = utf8char(prev[y+1], x)

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

@operation_types+=
DEL = 1,

@send_delete_operation_for_newline+=
SendOp(buf, { OP_TYPE.DEL, del_pid, "\n" })

@send_delete_operation_for_character+=
SendOp(buf, { OP_TYPE.DEL, del_pid, c })

@if_there_is_text_to_insert_insert_it+=
@get_length_of_text_to_insert
@generate_pids_seq_to_insert
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

@generate_pids_seq_to_insert+=
local before_pid, after_pid
if add_range.sx == -1 then
	@get_before_after_PID_newline
else
	@get_before_after_PID_normal_char
end

local newpidindex = 1
local newpids = genPIDSeq(before_pid, after_pid, agent, 1, len_insert)

@get_before_after_PID_newline+=
local pidx
local x, y = add_range.sx, add_range.sy
if cur_lines[y-firstline] then
	pidx = utf8len(cur_lines[y-firstline])+1
else
	pidx = #pids[y+1]
end
before_pid = pids[y+1][pidx]
after_pid = afterPID(pidx, y+1)

@get_before_after_PID_normal_char+=
local x, y = add_range.sx, add_range.sy
before_pid = pids[y+2][x+1]
after_pid = afterPID(x+1, y+2)

@get_length_of_text_to_insert+=
local len_insert = 0
local startx = add_range.sx
for y=add_range.sy, add_range.ey do
	@get_current_line_length_to_insert
	for x=startx,endx do
		len_insert = len_insert + 1 
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
local new_pid = newpids[newpidindex]
newpidindex = newpidindex + 1

table.insert(pids[y+2], x+2, new_pid)

@operation_types+=
INS = 2,

@send_insert_operation_for_character+=
SendOp(buf, { OP_TYPE.INS, c, new_pid })

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

local new_pid = newpids[newpidindex]
newpidindex = newpidindex + 1

local l, r = splitArray(pids[y+1], pidx+1)
pids[y+1] = l
table.insert(r, 1, new_pid)
table.insert(pids, y+2, r)

@send_insert_operation_for_newline+=
SendOp(buf, { OP_TYPE.INS, "\n", new_pid })

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
local MAXINT = 2^20 -- can be adjusted
local startpos, endpos = {{0, 0}}, {{MAXINT, 0}}
-- line = [pos]
-- pids = [line]
allpids = {}
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
agent = client_id

@declare_functions+=
local SendOp

@functions+=
function SendOp(buf, op)
	@save_operation_in_undo_stack
	@convert_local_to_remote_buffer
	@encode_operation_in_json_object
	@send_encoded
end

@script_variables+=
local author = vim.api.nvim_get_var("instant_username")

@message_types+=
TEXT = 1,

@encode_operation_in_json_object+=
local obj = {
	MSG_TYPE.TEXT,
	op,
	rem,
	agent,
}

local encoded = vim.api.nvim_call_function("json_encode", { obj })

@interpret_received_text+=
@decode_json
if decoded then
	@if_text_do_actions
	@if_request_send_all_lines
	@if_initial_and_not_initialized_set_buffer_lines
	@if_available_check_if_its_ok
	@if_connect_save_client_id_and_username
	@if_disconnect_remove_client_id_and_username
	@if_data_send_to_callbacks
else
	error("Could not decode json " .. wsdata)
end

@if_text_do_actions+=
if decoded[1] == MSG_TYPE.TEXT then
	local _, op, other_rem, other_agent = unpack(decoded)
	local lastPID
	@play_operation
end

@decode_json+=
local decoded = vim.api.nvim_call_function("json_decode", {  wsdata })

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

@play_operation+=
local opline = 0
local opcol = 0

@get_local_buf_from_remote
@get_context_for_current_buffer
@get_changedtick_and_add_to_ignore
if op[1] == OP_TYPE.INS then
	@save_last_inserted_pid
	@apply_insert_operation
elseif op[1] == OP_TYPE.DEL then
	@save_last_deleted_pid
	@apply_delete_operation
end
@set_context_for_current_buffer
@get_author_from_other_agent_id
if lastPID and other_agent ~= agent then
	@find_pid_of_cursor
	@update_cursor_highlight
	@notify_change_callbacks
end
-- @check_if_pid_match_with_prev

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
local function findCharPositionBefore(opid)
	@compute_line_with_sorted_binary_search
	local px, py = 1, 1
	for y=y1,#pids do
		for x,pid in ipairs(pids[y]) do
			if not isLowerOrEqual(pid, opid) then
				return px, py
			end
			px, py = x, y
		end
	end
end

@find_pid_of_element_just_before+=
local x, y = findCharPositionBefore(op[3])

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
	table.insert(py1, 1, op[3])
	table.insert(pids, y+1, py1)
else table.insert(pids[y], x+1, op[3] ) end

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
	if isLowerOrEqual(pids[ym][1], opid) then
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

	if not isLowerOrEqual(pid, opid) then
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
local isLowerOrEqual

@functions+=
function isLowerOrEqual(a, b)
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
	@stop_client
end

@stop+=
for bufhandle,_ in pairs(allprev) do
	if vim.api.nvim_buf_is_loaded(bufhandle) then
		DetachFromBuffer(bufhandle)
	end
end


@if_request_send_all_lines+=
if decoded[1] == MSG_TYPE.REQUEST then
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
	MSG_TYPE.INFO,
	sessionshare,
	author,
	agent,
}
local encoded = vim.api.nvim_call_function("json_encode", { obj })
@send_encoded

@send_encoded+=
ws_client:send_text(encoded)

@if_initial_and_not_initialized_set_buffer_lines+=
if decoded[1] == MSG_TYPE.INITIAL then
	local _, bufname, bufid, pidslist, content = unpack(decoded)

	local ag, bufid = unpack(bufid)
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

@message_types+=
AVAILABLE = 2,

@if_available_check_if_its_ok+=
if decoded[1] == MSG_TYPE.AVAILABLE then
	local _, is_first, client_id, is_sessionshare  = unpack(decoded)
	if is_first and first then
		@init_client_id

		if sessionshare then
			@get_all_text_edit_buffers
			@attach_to_all_opened_buffers
			@init_content_for_all_opened_buffers
		else
			local buf = singlebuf

			@attach_to_current_buffer
			@map_new_buffer_id

			@get_buffer_lines
			@init_pids_of_buffer_content
			@init_prev_of_buffer_content
			@set_context_for_current_buffer

		end

		@register_autocommands_for_buffer_open_and_create
	elseif not is_first and not first then
		if is_sessionshare ~= sessionshare then
			print("ERROR: Share mode client server mismatch (session mode, single buffer mode)")
			@stop
		else
			@init_client_id

			if not sessionshare then
				local buf = singlebuf

				@attach_to_current_buffer
			end
			@send_request_for_initial_content
			@register_autocommands_for_buffer_open_and_create
		end
	elseif is_first and not first then
		print("ERROR: Tried to join an empty server")
		@stop
	elseif not is_first and first then
		print("ERROR: Tried to start a server which is already busy")
		@stop
	end
end

@message_types+=
REQUEST = 3,

@send_request_for_initial_content+=
local obj = {
	MSG_TYPE.REQUEST,
}
local encoded = vim.api.nvim_call_function("json_encode", {  obj  })
@send_encoded

@check_if_has_username+=
local v, username = pcall(function() return vim.api.nvim_get_var("instant_username") end)
if not v then
	error("Please specify a username in g:instant_username")
end

@attach_to_current_buffer+=
@init_buffer_attach
@register_buf_change_callback

@message_types+=
INITIAL = 6,

@encode_initial_content_single+=
local pidslist = {}
for _,lpid in ipairs(allpids[buf]) do
	for _,pid in ipairs(lpid) do
		table.insert(pidslist, pid[1][1])
	end
end

local obj = {
	MSG_TYPE.INITIAL,
	bufname,
	rem,
	pidslist,
	allprev[buf]
}

encoded = vim.api.nvim_call_function("json_encode", {  obj  })

@set_lines_for_initial_prev+=
prev = content

@set_pids_for_initial+=
local pidindex = 1
pids = {}

table.insert(pids, { { { pidslist[pidindex], 0 } } })
pidindex = pidindex + 1

for _, line in ipairs(content) do
	local lpid = {}
	for i=0,utf8len(line) do
		table.insert(lpid, { { pidslist[pidindex], ag } })
		pidindex = pidindex + 1
	end
	table.insert(pids, lpid)
end

table.insert(pids, { { { pidslist[pidindex], 0 } } })

@set_lines_in_current_buffer+=
vim.api.nvim_buf_set_lines(
	buf,
	0, -1, false, prev)

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

@check_if_client_is_not_connected+=
if ws_client and ws_client:is_active() then
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

local numgen = 0
for i=1,#lines do
	local line = lines[i]
	if i > 1 then
		numgen = numgen + 1
	end

	for j=1,string.len(line) do
		numgen = numgen + 1
	end
end

local newpidindex = 1
local newpids = genPIDSeq(middlepos, endpos, agent, 1, numgen)

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
local newpid = newpids[newpidindex]
newpidindex = newpidindex + 1

@insert_character_pid+=
table.insert(pids[i+1], newpid)

@insert_newline_character_pid+=
table.insert(pids, i+1, { newpid })

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
	id = vim.api.nvim_buf_set_virtual_text(
		buf, 0, 
		math.max(y-2, 0), 
		{{ aut, vtextGroup[client_hl_group[other_agent]] }}, 
		{}),
	buf = buf
}

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

@get_context_for_current_buffer+=
prev = allprev[buf]
pids = allpids[buf]

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

@message_types+=
INFO = 5,

@create_new_buffer+=
buf = vim.api.nvim_create_buf(true, true)

@script_variables+=
local loc2rem = {}
local rem2loc = {}

@init_client+=
loc2rem = {}
rem2loc = {}

@map_received_buffer_id+=
if not rem2loc[ag] then
	rem2loc[ag] = {}
end

rem2loc[ag][bufid] = buf
loc2rem[buf] = { ag, bufid }

@convert_local_to_remote_buffer+=
local rem = loc2rem[buf]

@get_local_buf_from_remote+=
local ag, bufid = unpack(other_rem)
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
vim.api.nvim_buf_set_name(buf, bufname)

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

@register_autocommands_for_buffer_open_and_create+=
vim.api.nvim_command("augroup instantSession")
vim.api.nvim_command("autocmd!")
-- this is kind of messy
-- a better way to write this
-- would be great
vim.api.nvim_command("autocmd BufNewFile,BufRead * call execute('lua instantOpenOrCreateBuffer(' . expand('<abuf>') . ')', '')")
vim.api.nvim_command("augroup end")

@stop+=
@unregister_autocommands

@unregister_autocommands+=
vim.api.nvim_command("augroup instantSession")
vim.api.nvim_command("autocmd!")
vim.api.nvim_command("augroup end")

@script_variables+=
local only_share_cwd

@init_client+=
only_share_cwd = getConfig("g:instant_only_cwd", true)

@functions+=
function instantOpenOrCreateBuffer(buf)
	if sessionshare or buf == singlebuf then
		@get_buf_name_relative_to_cwd_or_just_tail

		if cwdname ~= fullname or not only_share_cwd then
			@get_buffer_lines
			@init_pids_of_buffer_content
			@init_prev_of_buffer_content
			@set_context_for_current_buffer

			@map_new_buffer_id
			@encode_initial_content_single
			@send_encoded

			@attach_to_current_buffer
		end
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


@get_author_from_other_agent_id+=
local aut = id2author[other_agent]

@script_variables+=
local follow = false
local follow_aut

@follow_function+=
local function StartFollow(aut)
	follow = true
	follow_aut = aut
	print("Following " .. aut)
end

local function StopFollow()
	follow = false
	print("Following Stopped.")
end

@export_symbols+=
StartFollow = StartFollow,
StopFollow = StopFollow,

@if_follow_this_author_center_view+=
if follow and follow_aut == aut then
	@if_different_buffer_switch
	@go_to_line_and_center_view
end

@if_different_buffer_switch+=
local curbuf = vim.api.nvim_get_current_buf()
if curbuf ~= buf then
	vim.api.nvim_set_current_buf(buf)
end

@go_to_line_and_center_view+=
vim.api.nvim_command("normal " .. (y-1) .. "gg")

@declare_functions+=
local genPIDSeq

@functions+=
function genPIDSeq(p, q, s, i, N)
	local a = (p[i] and p[i][1]) or 0
	local b = (q[i] and q[i][1]) or MAXINT

	if a+N < b-1 then
		local step = math.floor((b-1 - (a+1))/N)
		local start = a+1
		local G = {}
		for i=1,N do
			table.insert(G,
				{{math.random(start,start+step-1), s}})
			start = start + step
		end
		return G
	end

	local G = genPIDSeq(p, q, s, i+1, N)
	for j=1,N do
		table.insert(G[j], 1, {
			(p[i] and p[i][1]) or 0, 
			(p[i] and p[i][2]) or s})
	end
	return G
end

@script_variables+=
local author2id = {}
local id2author = {}

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

@special_save_function+=
local function SaveBuffers(force)
	@get_all_text_edit_buffers
	@remove_any_empty_name_buffers
	for _,buf in ipairs(bufs) do
		@get_buffer_name
		@check_if_containing_directory_exists_and_create_if_not
		@save_all_buffers
	end
end

@export_symbols+=
SaveBuffers = SaveBuffers,

@remove_any_empty_name_buffers+=
local i = 1
while i < #bufs do
	local buf = bufs[i]
	@get_buffer_name
	if string.len(fullname) == 0 then
		table.remove(bufs, i)
	else
		i = i + 1
	end
end

@get_buffer_name+=
local fullname = vim.api.nvim_buf_get_name(buf)

@check_if_containing_directory_exists_and_create_if_not+=
local parentdir = vim.api.nvim_call_function("fnamemodify", { fullname, ":h" })
local isdir = vim.api.nvim_call_function("isdirectory", { parentdir })
if isdir == 0 then
	vim.api.nvim_call_function("mkdir", { parentdir, "p" } )
end

@save_all_buffers+=
vim.api.nvim_command("b " .. buf)
if force then
	vim.api.nvim_command("w!") -- write all
else 
	vim.api.nvim_command("w") -- write all
end

@special_open_function+=
function OpenBuffers()
	@global_all_files_in_cwd
	local num_files = 0
	for _,file in ipairs(files) do
		vim.api.nvim_command("args " .. file)
		num_files = num_files + 1 
	end
	print("Opened " .. num_files .. " files.")
end

@export_symbols+=
OpenBuffers = OpenBuffers,

@global_all_files_in_cwd+=
local all = vim.api.nvim_call_function("glob", { "**" })
local files = {}
if string.len(all) > 0 then
	for path in vim.gsplit(all, "\n") do
		local isdir = vim.api.nvim_call_function("isdirectory", { path })
		if isdir == 0 then
			table.insert(files, path)
		end
	end
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

@register_undo_redo_commands+=
vim.api.nvim_buf_set_keymap(buf, 'n', 'u', '<cmd>lua require("instant").undo(' .. buf .. ')<CR>', {noremap = true})

@export_symbols+=
undo = undo,

@script_variables+=
local disable_undo = false

@undo_redo_functions+=
local function undo(buf)
	@get_operations_on_top_of_undo_stack
	@move_undo_stack_pointer_down

	disable_undo = true
	local other_rem, other_agent = loc2rem[buf], agent
	local lastPID
	for _, op in ipairs(ops) do
		@compute_inverse_operation
		@play_operation
		@send_operation
	end
	disable_undo = false
	@move_cursor_to_modification
end

@script_variables+=
local undostack = {}
local undosp = {}

@init_buffer_attach+=
undostack[buf] = {}
undosp[buf] = 0

@save_operation_in_undo_stack+=
if not disable_undo then
	table.insert(undoslice[buf], op)
end

@get_operations_on_top_of_undo_stack+=
if undosp[buf] == 0 then
	print("Already at oldest change")
	return
end
local ops = undostack[buf][undosp[buf]]

@move_undo_stack_pointer_down+=
undosp[buf] = undosp[buf] - 1

@compute_inverse_operation+=
if op[1] == OP_TYPE.INS then
	@invert_insert_operation
elseif op[1] == OP_TYPE.DEL then
	@invert_delete_operation
end

@invert_insert_operation+=
op = { OP_TYPE.DEL, op[3], op[2] }

@invert_delete_operation+=
op = { OP_TYPE.INS, op[3], op[2] }

@register_undo_redo_commands+=
vim.api.nvim_buf_set_keymap(buf, 'n', '<C-r>', '<cmd>lua require("instant").redo(' .. buf .. ')<CR>', {noremap = true})

@export_symbols+=
redo = redo,

@undo_redo_functions+=
local function redo(buf)
	@move_undo_stack_pointer_up
	@get_operations_on_top_of_undo_stack
	local other_rem, other_agent = loc2rem[buf], agent
	disable_undo = true
	local lastPID
	for _, op in ipairs(ops) do
		@play_operation
		@send_operation
	end
	disable_undo = false
	@move_cursor_to_modification
end

@move_undo_stack_pointer_up+=
if undosp[buf] == #undostack[buf] then
	print("Already at newest change")
	return
end

undosp[buf] = undosp[buf]+1

@send_operation+=
SendOp(buf, op)

@script_variables+=
local undoslice = {}

@init_buffer_attach+=
undoslice[buf] = {}

@push_on_undo_stack+=
if #undoslice[buf] > 0 then
	while undosp[buf] < #undostack[buf] do
		table.remove(undostack[buf]) -- remove last element
	end
	table.insert(undostack[buf], undoslice[buf])
	undosp[buf] = undosp[buf] + 1
	undoslice[buf] = {}
end

@move_cursor_to_modification+=
if lastPID then
	@find_pid_of_cursor
	if prev[y-1] and x-2 >= 0 and x-2 <= utf8len(prev[y-1]) then
		local bx = vim.str_byteindex(prev[y-1], x-2)
		vim.api.nvim_call_function("cursor", { y-1, bx+1 })
	end
end

@script_variables+=
local hl_group = {}
local client_hl_group = {}

@init_client_highlight_group+=
local user_hl_group = 5
for i=1,4 do
	if not hl_group[i] then
		hl_group[i] = true
		user_hl_group = i
		break
	end
end

client_hl_group[new_id] = user_hl_group 

@remove_client_hl_group+=
if client_hl_group[remove_id] ~= 5 then -- 5 means default hl group (there are four predefined)
	hl_group[client_hl_group[remove_id]] = nil
end
client_hl_group[remove_id] = nil
