@../../lua/instant/utf8.lua=
@requires
@script_variables
local M = {}
@functions
return M

@functions+=
function M.len(str)
	return vim.str_utfindex(str)
end

function M.char(str, i)
	if i >= M.len(str) or i < 0 then return nil end
	local s1 = vim.str_byteindex(str, i)
	local s2 = vim.str_byteindex(str, i+1)
	return string.sub(str, s1+1, s2)
end

@functions+=
function M.insert(str, i, c)
	if i == M.len(str) then
		return str .. c
	end
	local s1 = vim.str_byteindex(str, i)
	return string.sub(str, 1, s1) .. c .. string.sub(str, s1+1)
end

@functions+=
function M.remove(str, i)
	local s1 = vim.str_byteindex(str, i)
	local s2 = vim.str_byteindex(str, i+1)

	return string.sub(str, 1, s1) .. string.sub(str, s2+1)
end
