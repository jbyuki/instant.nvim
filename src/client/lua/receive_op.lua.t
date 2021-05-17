##../../instant_client
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

@declare_functions+=
local findCharPositionBefore

@functions+=
function findCharPositionBefore(opid)
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

@get_author_from_other_agent_id+=
local aut = id2author[other_agent]

@script_variables+=
local author2id = {}
local id2author = {}

@get_context_for_current_buffer+=
prev = allprev[buf]
pids = allpids[buf]

@set_context_for_current_buffer+=
allprev[buf] = prev
allpids[buf] = pids
