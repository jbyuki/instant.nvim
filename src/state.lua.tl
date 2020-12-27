@../lua/instant/client/state.lua=
@requires
@script_variables
@declare_functions
@functions

local M = {}

-- Initiates a state (an instance which tracks changes
-- and send them, and also play changes from remote clients )
-- buffer.
--
-- If buffer is already attached with a controller, returns nil
--
-- @returns controller, or nil
function M.new_state()
	@internal_variables
	local state = {}
	@methods
	return state
end

return M

@methods+=
-- Initiates a state (an instance which tracks changes
-- and send them, and also play changes from remote clients )
-- buffer.
--
-- If buffer is already attached with a controller, returns nil
--
-- @params cur_lines (table) lines in buffer
-- @params add_range (table) ranges of newly added characters
-- @params del_range (table) ranges of replaced characters
function state.update(cur_lines, add_range, del_range) 
	@go_from_ending_and_elimate_same
	@go_from_begining_and_elimate_same
end

@requires+=
local utf8 = require("instant.utf8")

@go_from_begining_and_elimate_same+=
while (add_range.sy < add_range.ey or (add_range.sy == add_range.ey and add_range.sx <= add_range.ex)) and 
	  (del_range.sy < del_range.ey or (del_range.sy == del_range.ey and del_range.sx <= del_range.ex)) do

	local c1, c2
	if add_range.sx == -1 then c1 = "\n"
	else c1 = utf8.char(cur_lines[add_range.sy-firstline+1] or "",add_range.sx) end

	if del_range.sx == -1 then c2 = "\n"
	else c2 = utf8.char(prev[del_range.sy+1] or "", del_range.sx) end

	if c1 ~= c2 then
		break
	end
	@advance_one_character_both_ranges
end

@advance_one_character_both_ranges+=
add_range.sx = add_range.sx+1
del_range.sx = del_range.sx+1

if add_range.sx == utf8.len(cur_lines[add_range.sy-firstline+1] or "") then
	add_range.sx = -1
	add_range.sy = add_range.sy + 1

end
if del_range.sx == utf8.len(prev[del_range.sy+1] or "") then
	del_range.sx = -1
	del_range.sy = del_range.sy + 1
end

@go_from_ending_and_elimate_same+=
while (add_range.ey > add_range.sy or (add_range.ey == add_range.sy and add_range.ex >= add_range.sx)) and 
	  (del_range.ey > del_range.sy or (del_range.ey == del_range.sy and del_range.ex >= del_range.sx)) do

	local c1, c2
	if add_range.ex == -1 then c1 = "\n"
	else c1 = utf8.char(cur_lines[add_range.ey-firstline+1] or "",add_range.ex) end

	if del_range.ex == -1 then c2 = "\n"
	else c2 = utf8.char(prev[del_range.ey+1] or "", del_range.ex) end

	if c1 ~= c2 then
		break
	end

	local add_prev, del_prev
	@step_back_one_character_both_ranges
	@shrink_range_at_end
end

@step_back_one_character_both_ranges+=
if add_range.ex == -1 then
	add_prev = { ey = add_range.ey-1, ex = utf8.len(cur_lines[add_range.ey-firstline] or "")-1 }
else
	add_prev = { ex = add_range.ex-1, ey = add_range.ey }
end

if del_range.ex == -1 then
	del_prev = { ey = del_range.ey-1, ex = utf8.len(prev[del_range.ey] or "")-1 }
else
	del_prev = { ex = del_range.ex-1, ey = del_range.ey }
end

@shrink_range_at_end+=
add_range.ex, add_range.ey = add_prev.ex, add_prev.ey
del_range.ex, del_range.ey = del_prev.ex, del_prev.ey
