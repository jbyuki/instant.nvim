##../../instant_client
@register_undo_redo_commands+=
vim.api.nvim_buf_set_keymap(buf, 'n', 'u', '<cmd>lua require("instant").undo(' .. buf .. ')<CR>', {noremap = true})

@export_symbols+=
undo = undo,

@o+=
local a

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
	print("Already at oldest change.")
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

@script_variables+=
local autocmd_init = false

@register_autocommands_if_not_not_done+=
if not autocmd_init then
  vim.api.nvim_command("augroup instantUndo")
  vim.api.nvim_command("autocmd!")
  vim.api.nvim_command([[autocmd InsertLeave * lua require"instant".leave_insert()]])
  vim.api.nvim_command("augroup end")
  autocmd_init = false
end

@check_if_in_insert_mode+=
local mode = vim.api.nvim_call_function("mode", {})
local insert_mode = mode == "i"

@functions+=
function leave_insert()
  @save_all_non_empty_undo_slices
end

@export_symbols+=
leave_insert = leave_insert,

@o+=
local a

@save_all_non_empty_undo_slices+=
for buf,_ in pairs(undoslice) do
  @push_on_undo_stack
end
