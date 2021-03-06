##../../instant_client
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

@declare_functions+=
local afterPID

@functions+=
function afterPID(x, y)
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
  @if_mark_put_it_in_current_client
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
