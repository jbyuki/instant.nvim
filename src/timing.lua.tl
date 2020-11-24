@../lua/instant/timer.lua=
local function start()
	return vim.api.nvim_call_function("reltime", {})
end

local function stop(start)
	local dt =  vim.api.nvim_call_function("reltime", { start })
	return tonumber(vim.api.nvim_call_function("reltimestr", {dt}))
end

return {
	start = start,
	stop = stop,
}
