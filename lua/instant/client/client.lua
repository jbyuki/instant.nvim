-- Generated from controller.lua.tl using ntangle.nvim
local attached = {}


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
	if attached[buf] then
		return nil
	end
	
	local detach = false
	
	local controller = {}
	local attach_success = vim.api.nvim_buf_attach(buf, false, {
		on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
			if detach then
				detach = nil
				return true
			end
			
	
			local cur_lines = vim.api.nvim_buf_get_lines(buf, firstline, new_lastline, true)
			
			local add_range = {
				sx = -1,
				sy = firstline,			
				ex = -1, -- at position there is \n
				ey = new_lastline
			}
		end,
		on_detach = function(_, buf)
			attached[buf] = nil
		end
	})
	
	if attach_success then
		attached[buf] = true
	end
	
	function controller:detach()
		detach = true
	end
	
	return setmetatable({}, { __index = controller})
end


return M

