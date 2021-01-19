##../../instant_client
@special_save_function+=
local function SaveBuffers(force)
	@get_all_text_edit_buffers
	@remove_any_empty_name_buffers
	for _,buf in ipairs(bufs) do
		@get_buffer_name
		@check_if_containing_directory_exists_and_create_if_not
		@save_all_buffers
	end
end

@export_symbols+=
SaveBuffers = SaveBuffers,

@remove_any_empty_name_buffers+=
local i = 1
while i < #bufs do
	local buf = bufs[i]
	@get_buffer_name
	if string.len(fullname) == 0 then
		table.remove(bufs, i)
	else
		i = i + 1
	end
end

@get_buffer_name+=
local fullname = vim.api.nvim_buf_get_name(buf)

@check_if_containing_directory_exists_and_create_if_not+=
local parentdir = vim.api.nvim_call_function("fnamemodify", { fullname, ":h" })
local isdir = vim.api.nvim_call_function("isdirectory", { parentdir })
if isdir == 0 then
	vim.api.nvim_call_function("mkdir", { parentdir, "p" } )
end

@save_all_buffers+=
vim.api.nvim_command("b " .. buf)
if force then
	vim.api.nvim_command("w!") -- write all
else 
	vim.api.nvim_command("w") -- write all
end

@special_open_function+=
function OpenBuffers()
	@global_all_files_in_cwd
	local num_files = 0
	for _,file in ipairs(files) do
		vim.api.nvim_command("args " .. file)
		num_files = num_files + 1 
	end
	print("Opened " .. num_files .. " files.")
end

@export_symbols+=
OpenBuffers = OpenBuffers,

@global_all_files_in_cwd+=
local all = vim.api.nvim_call_function("glob", { "**" })
local files = {}
if string.len(all) > 0 then
	for path in vim.gsplit(all, "\n") do
		local isdir = vim.api.nvim_call_function("isdirectory", { path })
		if isdir == 0 then
			table.insert(files, path)
		end
	end
end
