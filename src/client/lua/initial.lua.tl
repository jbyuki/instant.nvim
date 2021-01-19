##../../instant_client
@if_request_send_all_lines+=
if decoded[1] == MSG_TYPE.REQUEST then
	local encoded
	if not sessionshare then
		local buf = singlebuf
		local rem = { agent, buf }
		@get_buf_name_relative_to_cwd_or_just_tail
		@encode_initial_content_single
		@send_encoded
	else
		@get_all_text_edit_buffers
		for _,buf in ipairs(bufs) do
			local rem = { agent, buf }
			@get_buf_name_relative_to_cwd_or_just_tail
			@encode_initial_content_single
			@send_encoded
		end
	end
end


@handshake_finished+=
local obj = {
	MSG_TYPE.INFO,
	sessionshare,
	author,
	agent,
}
local encoded = vim.api.nvim_call_function("json_encode", { obj })
@send_encoded

@send_encoded+=
ws_client:send_text(encoded)


@if_initial_and_not_initialized_set_buffer_lines+=
if decoded[1] == MSG_TYPE.INITIAL then
	local _, bufname, bufid, pidslist, content = unpack(decoded)

	local ag, bufid = unpack(bufid)
	if not rem2loc[ag] or not rem2loc[ag][bufid] then
		local buf
		if not sessionshare then
			buf = singlebuf
			@rename_buffer_to_initial
		else
			@create_new_buffer
			@attach_to_current_buffer
			@rename_buffer_to_initial
			@detect_file_type
			@remove_buf_type_of_scratch_buffer
		end

		@map_received_buffer_id

		@set_lines_for_initial_prev
		@set_pids_for_initial

		@get_changedtick_and_add_to_ignore
		@set_lines_in_current_buffer
		@set_context_for_current_buffer
	else
		local buf = rem2loc[ag][bufid]

		@set_lines_for_initial_prev
		@set_pids_for_initial

		@get_changedtick_and_add_to_ignore
		@set_lines_in_current_buffer
		@set_context_for_current_buffer

		@rename_buffer_to_initial
		@detect_file_type
	end
end

@message_types+=
AVAILABLE = 2,

@if_available_check_if_its_ok+=
if decoded[1] == MSG_TYPE.AVAILABLE then
	local _, is_first, client_id, is_sessionshare  = unpack(decoded)
	if is_first and first then
		@init_client_id

		if sessionshare then
			@get_all_text_edit_buffers
			@attach_to_all_opened_buffers
			@init_content_for_all_opened_buffers
		else
			local buf = singlebuf

			@attach_to_current_buffer
			@map_new_buffer_id

			@get_buffer_lines
			@init_pids_of_buffer_content
			@init_prev_of_buffer_content
			@set_context_for_current_buffer

		end

		@register_autocommands_for_buffer_open_and_create
	elseif not is_first and not first then
		if is_sessionshare ~= sessionshare then
			print("ERROR: Share mode client server mismatch (session mode, single buffer mode)")
			@stop
		else
			@init_client_id

			if not sessionshare then
				local buf = singlebuf

				@attach_to_current_buffer
			end
			@send_request_for_initial_content
			@register_autocommands_for_buffer_open_and_create
		end
	elseif is_first and not first then
		print("ERROR: Tried to join an empty server")
		@stop
	elseif not is_first and first then
		print("ERROR: Tried to start a server which is already busy")
		@stop
	end
end

@message_types+=
REQUEST = 3,

@send_request_for_initial_content+=
local obj = {
	MSG_TYPE.REQUEST,
}
local encoded = vim.api.nvim_call_function("json_encode", {  obj  })
@send_encoded

@check_if_has_username+=
local v, username = pcall(function() return vim.api.nvim_get_var("instant_username") end)
if not v then
	error("Please specify a username in g:instant_username")
end

@attach_to_current_buffer+=
@init_buffer_attach
@register_buf_change_callback

@message_types+=
INITIAL = 6,

@encode_initial_content_single+=
local pidslist = {}
for _,lpid in ipairs(allpids[buf]) do
	for _,pid in ipairs(lpid) do
		table.insert(pidslist, pid[1][1])
	end
end

local obj = {
	MSG_TYPE.INITIAL,
	bufname,
	rem,
	pidslist,
	allprev[buf]
}

encoded = vim.api.nvim_call_function("json_encode", {  obj  })

@set_lines_for_initial_prev+=
prev = content

@set_pids_for_initial+=
local pidindex = 1
pids = {}

table.insert(pids, { { { pidslist[pidindex], 0 } } })
pidindex = pidindex + 1

for _, line in ipairs(content) do
	local lpid = {}
	for i=0,utf8len(line) do
		table.insert(lpid, { { pidslist[pidindex], ag } })
		pidindex = pidindex + 1
	end
	table.insert(pids, lpid)
end

table.insert(pids, { { { pidslist[pidindex], 0 } } })

@set_lines_in_current_buffer+=
vim.api.nvim_buf_set_lines(
	buf,
	0, -1, false, prev)

@check_if_client_is_not_connected+=
if ws_client and ws_client:is_active() then
	error("Client is already connected. Use InstantStop first to disconnect.")
end

@get_buffer_lines+=
local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)

@init_prev_of_buffer_content+=
prev = lines

@init_pids_of_buffer_content+=
local middlepos = genPID(startpos, endpos, agent, 1)
pids = {
	{ startpos },
	{ middlepos },
	{ endpos },
}

local numgen = 0
for i=1,#lines do
	local line = lines[i]
	if i > 1 then
		numgen = numgen + 1
	end

	for j=1,string.len(line) do
		numgen = numgen + 1
	end
end

local newpidindex = 1
local newpids = genPIDSeq(middlepos, endpos, agent, 1, numgen)

for i=1,#lines do
	local line = lines[i]
	if i > 1 then
		@generate_character_pid
		@insert_newline_character_pid
	end

	for j=1,string.len(line) do
		@generate_character_pid
		@insert_character_pid
	end
end

@generate_character_pid+=
local newpid = newpids[newpidindex]
newpidindex = newpidindex + 1

@insert_character_pid+=
table.insert(pids[i+1], newpid)

@insert_newline_character_pid+=
table.insert(pids, i+1, { newpid })

@attach_to_all_opened_buffers+=
for _, buf in ipairs(bufs) do
	@attach_to_current_buffer
end

@init_content_for_all_opened_buffers+=
for _, buf in ipairs(bufs) do
	@get_buffer_lines
	@init_pids_of_buffer_content
	@init_prev_of_buffer_content
	@set_context_for_current_buffer
	@set_buf_table_for_opened_buffers
end

@message_types+=
INFO = 5,

@create_new_buffer+=
buf = vim.api.nvim_create_buf(true, true)

@script_variables+=
local loc2rem = {}
local rem2loc = {}

@init_client+=
loc2rem = {}
rem2loc = {}

@map_received_buffer_id+=
if not rem2loc[ag] then
	rem2loc[ag] = {}
end

rem2loc[ag][bufid] = buf
loc2rem[buf] = { ag, bufid }

@convert_local_to_remote_buffer+=
local rem = loc2rem[buf]

@get_local_buf_from_remote+=
local ag, bufid = unpack(other_rem)
buf = rem2loc[ag][bufid]

@set_buf_table_for_opened_buffers+=
if not rem2loc[agent] then
	rem2loc[agent] = {}
end

rem2loc[agent][buf] = buf
loc2rem[buf] = { agent, buf }

@get_buf_name_relative_to_cwd_or_just_tail+=
local fullname = vim.api.nvim_buf_get_name(buf)
local cwdname = vim.api.nvim_call_function("fnamemodify",
	{ fullname, ":." })
local bufname = cwdname
if bufname == fullname then
	bufname = vim.api.nvim_call_function("fnamemodify",
	{ fullname, ":t" })
end

@rename_buffer_to_initial+=
vim.api.nvim_buf_set_name(buf, bufname)

@get_all_text_edit_buffers+=
local allbufs = vim.api.nvim_list_bufs()
local bufs = {}
-- skip terminal, help, ... buffers
for _,buf in ipairs(allbufs) do
	local buftype = vim.api.nvim_buf_get_option(buf, "buftype")
	if buftype == "" then
		table.insert(bufs, buf)
	end
end

@register_autocommands_for_buffer_open_and_create+=
vim.api.nvim_command("augroup instantSession")
vim.api.nvim_command("autocmd!")
-- this is kind of messy
-- a better way to write this
-- would be great
vim.api.nvim_command("autocmd BufNewFile,BufRead * call execute('lua instantOpenOrCreateBuffer(' . expand('<abuf>') . ')', '')")
vim.api.nvim_command("augroup end")

@stop+=
@unregister_autocommands

@unregister_autocommands+=
vim.api.nvim_command("augroup instantSession")
vim.api.nvim_command("autocmd!")
vim.api.nvim_command("augroup end")

@script_variables+=
local only_share_cwd

@init_client+=
only_share_cwd = getConfig("g:instant_only_cwd", true)

@functions+=
function instantOpenOrCreateBuffer(buf)
	if sessionshare or buf == singlebuf then
		@get_buf_name_relative_to_cwd_or_just_tail

		if cwdname ~= fullname or not only_share_cwd then
			@get_buffer_lines
			@init_pids_of_buffer_content
			@init_prev_of_buffer_content
			@set_context_for_current_buffer

			@map_new_buffer_id
			@encode_initial_content_single
			@send_encoded

			@attach_to_current_buffer
		end
	end
end

@map_new_buffer_id+=
if not rem2loc[agent] then
	rem2loc[agent] = {}
end

rem2loc[agent][buf] = buf
loc2rem[buf] = { agent, buf }

local rem = loc2rem[buf]

@detect_file_type+=
if vim.api.nvim_buf_call then
	vim.api.nvim_buf_call(buf, function()
		vim.api.nvim_command("filetype detect")
	end)
end

@remove_buf_type_of_scratch_buffer+=
vim.api.nvim_buf_set_option(buf, "buftype", "")

@set_cursor_extended_mark+=
if vim.api.nvim_buf_set_extmark then
	cursors[aut].ext_id = 
		vim.api.nvim_buf_set_extmark(
			buf, cursors[aut].id, y-2, bx, {})
end
