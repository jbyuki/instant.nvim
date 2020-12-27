@../lua/instant/client/client.lua=
@requires
@declare_functions
@script_variables

local M = {}

-- Initiates a controller (an instance which tracks changes
-- and send them, and also play changes from remote clients )
-- buffer.
--
-- If buffer is already attached with a controller, returns nil
--
-- @param bufnr (number) Buffer handle
-- @returns controller, or nil
function M.start_controller(buf)
	@if_buffer_already_attach_return_nil
	@internal_variables
	local controller = {}
	@attach_to_buffer
	@register_undo_redo_commands
	@methods
	return setmetatable({}, { __index = controller})
end

@detach_all_controllers

return M

@script_variables+=
local attached = {}

@if_buffer_already_attach_return_nil+=
if attached[buf] then
	return nil
end

@attach_to_buffer+=
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

if attach_success then
	attached[buf] = true
end

@internal_variables+=
local detach = false

@return_true_if_detach+=
if detach then
	detach = nil
	return true
end

@methods+=
function controller:detach()
	detach = true
end

@get_both_ranges+=
local cur_lines = vim.api.nvim_buf_get_lines(buf, firstline, new_lastline, true)

local add_range = {
	sx = -1,
	sy = firstline,			
	ex = -1, -- at position there is \n
	ey = new_lastline
}
