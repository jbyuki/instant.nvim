##../../instant_client
@functions+=
local function MarkRange()
  @get_visual_range
  @get_pid_of_start_and_end
  @clear_any_visual_ext_mark_for_current_user
  @set_visual_ext_mark_for_range
  @send_mark_to_other_clients
end

@export_symbols+=
MarkRange = MarkRange,

@o+=
local a

@get_visual_range+=
local _, snum, scol, _ = unpack(vim.api.nvim_call_function("getpos", { "'<" }))
local _, enum, ecol, _ = unpack(vim.api.nvim_call_function("getpos", { "'>" }))

@get_pid_of_start_and_end+=
local curbuf = vim.api.nvim_get_current_buf()
local pids = allpids[curbuf]

ecol = math.min(ecol, string.len(prev[enum])+1)

local bscol = vim.str_utfindex(prev[snum], scol-1)
local becol = vim.str_utfindex(prev[enum], ecol-1)

local spid = pids[snum+1][bscol+1]
local epid
if #pids[enum+1] < becol+1 then
  epid = pids[enum+2][1]
else
  epid = pids[enum+1][becol+1]
end

@script_variables+=
local marks = {}

@clear_any_visual_ext_mark_for_current_user+=
if marks[agent] then
  vim.api.nvim_buf_clear_namespace(marks[agent].buf, marks[agent].ns_id, 0, -1)
  marks[agent] = nil
end

@set_visual_ext_mark_for_range+=
marks[agent] = {}
marks[agent].buf = curbuf
marks[agent].ns_id = vim.api.nvim_create_namespace("")
for y=snum-1,enum-1 do
  local lscol
  if y == snum-1 then lscol = scol-1
  else lscol = 0 end

  local lecol
  if y == enum-1 then lecol = ecol-1
  else lecol = -1 end

  vim.api.nvim_buf_add_highlight(
    marks[agent].buf, 
    marks[agent].ns_id, 
    "TermCursor", 
    y, lscol, lecol)
end

@functions+=
local function MarkClear()
  @clear_all_marks_by_clear_namespace
  @clear_all_marks_info
end

@export_symbols+=
MarkClear = MarkClear,

@o+=
local a

@clear_all_marks_by_clear_namespace+=
for _, mark in pairs(marks) do
  vim.api.nvim_buf_clear_namespace(mark.buf, mark.ns_id, 0, -1)
end

@clear_all_marks_info+=
marks = {}

@message_types+=
MARK = 10,

@o+=
local a

@send_mark_to_other_clients+=
local rem = loc2rem[curbuf]
local obj = {
	MSG_TYPE.MARK,
	agent,
  rem,
  spid, epid,
}

local encoded = vim.api.nvim_call_function("json_encode", { obj })
@send_encoded

@if_mark_put_it_in_current_client+=
if decoded[1] == MSG_TYPE.MARK then
	local _, other_agent, rem, spid, epid = unpack(decoded)
  local ag, rembuf = unpack(rem)
  local buf = rem2loc[ag][rembuf]
  
  @find_start_and_end_position_for_mark
  @clear_any_marks_from_other_agent
  @put_mark_from_other_agent
  @get_author_from_other_agent_id
  @put_virtual_text_with_username_for_mark
  @focus_mark_if_follow_other_agent
end

@find_start_and_end_position_for_mark+=
local sx, sy = findCharPositionExact(spid)
local ex, ey = findCharPositionExact(epid)

@clear_any_marks_from_other_agent+=
if marks[other_agent] then
  vim.api.nvim_buf_clear_namespace(marks[other_agent].buf, marks[other_agent].ns_id, 0, -1)
  marks[other_agent] = nil
end

@put_mark_from_other_agent+=
marks[other_agent] = {}
marks[other_agent].buf = buf
marks[other_agent].ns_id = vim.api.nvim_create_namespace("")
local scol = vim.str_byteindex(prev[sy-1], sx-1)
local ecol = vim.str_byteindex(prev[ey-1], ex-1)

for y=sy-1,ey-1 do
  local lscol
  if y == sy-1 then lscol = scol
  else lscol = 0 end

  local lecol
  if y == ey-1 then lecol = ecol
  else lecol = -1 end

  vim.api.nvim_buf_add_highlight(
    marks[other_agent].buf, 
    marks[other_agent].ns_id, 
    cursorGroup[client_hl_group[other_agent]],
    y-1, lscol, lecol)
end

@put_virtual_text_with_username_for_mark+=
vim.api.nvim_buf_set_virtual_text(
  buf, marks[other_agent].ns_id, 
  sy-2, 
  {{ aut, vtextGroup[client_hl_group[other_agent]] }}, 
  {})

@focus_mark_if_follow_other_agent+=
if follow and follow_aut == aut then
	@if_different_buffer_switch
  local y = sy
  @go_to_line_and_center_view
end
