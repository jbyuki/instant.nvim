@../test/single_buffer.lua=
@script_variables
@create_window_test
@declare_functions
@functions
@initiate_socket_connection_to_vim
local stdin, stdout, stderr
@create_pipes
@spawn_process
@register_pipe_callbacks

@spawn_process+=
handle, pid = vim.loop.spawn("node",
	{
		stdio = {stdin, stdout, stderr},
		args = { "ws_server.js" },
		cwd = "../server"
	}, function(code, signal)
		vim.schedule(function()
			log("exit code" .. code)
			log("exit signal" .. signal)
			@terminate_socket_connection_to_vim
		end)
	end)


@create_pipes+=
stdin = vim.loop.new_pipe(false)
stdout = vim.loop.new_pipe(false)
stderr = vim.loop.new_pipe(false)


@register_pipe_callbacks+=
stdout:read_start(function(err, data)
	assert(not err, err)
	if data then
		table.insert(events, data)
		@read_stdout_server
	end
end)

stderr:read_start(function(err, data)
	assert(not err, err)
	if data then
		table.insert(events, data)
	end
end)


@read_stdout_server+=
if vim.startswith(data, "Server is listening") then
	vim.schedule(function()
		@start_connection_on_vim_clients
	end)
end

@script_variables+=
local client1, client2
local client1pipe = [[\\.\\pipe\nvim-15876-0]]
local client2pipe = [[\\.\\pipe\nvim-29488-0]]

@initiate_socket_connection_to_vim+=
client1 = vim.fn.sockconnect("pipe", client1pipe, { rpc = true })
client2 = vim.fn.sockconnect("pipe", client2pipe, { rpc = true })

@terminate_socket_connection_to_vim+=
vim.fn.chanclose(client2)
vim.fn.chanclose(client1)

@start_connection_on_vim_clients+=
vim.fn.rpcrequest(client1, 'nvim_exec', "new", false)
vim.fn.rpcrequest(client2, 'nvim_exec', "new", false)
vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStartSingle 127.0.0.1 8080", false)
vim.fn.rpcrequest(client2, 'nvim_exec', "InstantJoinSingle 127.0.0.1 8080", false)

@script_variables+=
local num_connected = 0

@script_variables+=
events = {}

@read_stdout_server+=
if vim.startswith(data, "Peer connected") then
	vim.schedule(function()
		num_connected = num_connected + 1
		if num_connected == 2 then
			@both_clients_are_connected 
			@do_tests
			@stop_both_clients
		end
	end)
end

@both_clients_are_connected+=
table.insert(events, "Both clients connected and it's all fine")

@stop_both_clients+=
vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStop", false)
vim.fn.rpcrequest(client2, 'nvim_exec', "InstantStop", false)
vim.fn.rpcrequest(client1, 'nvim_exec', "bufdo bwipeout! %", false)
vim.fn.rpcrequest(client2, 'nvim_exec', "bufdo bwipeout! %", false)

@script_variables+=
local outputbuf
local outputwin

@create_window_test+=
outputbuf = vim.api.nvim_create_buf(false, true)

local curwidth = vim.api.nvim_win_get_width(0)
local curheight = vim.api.nvim_win_get_height(0)

local opts = {
	relative =  'win', 
	width =  curwidth-4, 
	height = curheight-4, 
	col = 2,
	row = 2, 
	style =  'minimal'
}

ouputwin = vim.api.nvim_open_win(outputbuf, 0, opts)

@declare_functions+=
local log

@functions+=
function log(str)
	table.insert(events,str)
	lines = {}
	for line in vim.gsplit(str, "\n") do 
		table.insert(lines, line)
	end
	vim.api.nvim_buf_set_lines(outputbuf, -1, -1, true, lines)
end

@script_variables+=
local test_passed = 0
local test_failed = 0

@declare_functions+=
local assertEq

@functions+=
function assertEq(val1, val2)
	if val1 == val2 then
		test_passed = test_passed + 1
		log("assertEq(" .. vim.inspect(val1) .. ", " .. vim.inspect(val2) .. ") OK")
	else
		test_failed = test_failed + 1
		log("assertEq(" .. vim.inspect(val1) .. ", " .. vim.inspect(val2) .. ") FAIL")
	end
end

@display_final_result+=
log("")
log("PASSED " .. test_passed)
log("")
log("FAILED " .. test_failed)
log("")

@do_tests+=
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "test"} )
vim.wait(100)
local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 1)
assertEq(content2[1], "test")

@read_stdout_server+=
if vim.startswith(data, "Peer disconnected") then
	vim.schedule(function()
		num_connected = num_connected - 1
		log("Peer disconnected " .. num_connected)
		if num_connected == 0 then
			@display_final_result
			handle:kill()
		end
	end)
end

@do_tests+=
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "hello"} )
vim.wait(100)
local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 1)
assertEq(content2[1], "hello")

vim.wait(100)

@do_tests+=
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { ""} )
vim.wait(100)
local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 1)
assertEq(content2[1], "")

vim.wait(100)

@do_tests+=
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "test again" } )
vim.wait(100)
local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 1)
assertEq(content2[1], "test again")

vim.wait(100)

@do_tests+=
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "test again", "hey hey" } )
vim.wait(100)
local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 2)
assertEq(content2[1], "test again")
assertEq(content2[2], "hey hey")

vim.wait(100)

@do_tests+=
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "a" } )
vim.wait(100)
local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 1)
assertEq(content2[1], "a")

vim.wait(100)

@do_tests+=
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "aaaaaaaa" } )
vim.wait(100)
local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 1)
assertEq(content2[1], "aaaaaaaa")

vim.wait(100)

@do_tests+=
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "hello" } )
vim.wait(100)
local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 1)
assertEq(content2[1], "hello")

vim.wait(100)

@do_tests+=
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "hallo" } )
vim.wait(100)
local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 1)
assertEq(content2[1], "hallo")

vim.wait(100)

@do_tests+=
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "halllo" } )
vim.wait(100)
local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 1)
assertEq(content2[1], "halllo")

vim.wait(100)

@do_tests+=
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "halll" } )
vim.wait(100)
local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 1)
assertEq(content2[1], "halll")

vim.wait(100)

@do_tests+=
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "alll" } )
vim.wait(100)
local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 1)
assertEq(content2[1], "alll")

vim.wait(100)

@do_tests+=
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 1, 1, false, { "test" } )
vim.wait(100)
local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 2)
assertEq(content2[1], "alll")
assertEq(content2[2], "test")

vim.wait(100)

@do_tests+=
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 1, 2, false, { "testo" } )
vim.wait(100)
local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 2)
assertEq(content2[1], "alll")
assertEq(content2[2], "testo")

vim.wait(100)

@do_tests+=
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 2, 2, false, { "another" } )
vim.wait(100)
local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 3)
assertEq(content2[1], "alll")
assertEq(content2[2], "testo")
assertEq(content2[3], "another")

vim.wait(100)

@do_tests+=
vim.wait(100)
vim.fn.rpcrequest(client2, 'nvim_buf_set_lines', 0, 2, 3, false, { "hehe" } )
vim.wait(100)
local content2 = vim.fn.rpcrequest(client1, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 3)
assertEq(content2[1], "alll")
assertEq(content2[2], "testo")
assertEq(content2[3], "hehe")

vim.wait(100)

@do_tests+=
vim.wait(100)
vim.fn.rpcrequest(client2, 'nvim_buf_set_lines', 0, 2, 3, false, { "hat the" } )
vim.wait(100)
local content2 = vim.fn.rpcrequest(client1, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 3)
assertEq(content2[1], "alll")
assertEq(content2[2], "testo")
assertEq(content2[3], "hat the")

vim.wait(100)

@do_tests+=
vim.wait(100)
vim.fn.rpcrequest(client2, 'nvim_buf_set_lines', 0, 0, 1, false, { "lll" } )
vim.wait(100)
local content2 = vim.fn.rpcrequest(client1, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 3)
assertEq(content2[1], "lll")
assertEq(content2[2], "testo")
assertEq(content2[3], "hat the")

vim.wait(100)
