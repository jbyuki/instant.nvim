##../../instant_client
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
