##../../instant_client
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
