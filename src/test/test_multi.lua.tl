@../test/single_buffer.lua=
@script_variables
@declare_functions
@functions
@initiate_socket_connection_to_vim
local stdin, stdout, stderr
if nodejs then
	@create_pipes
	@spawn_process
	@register_pipe_callbacks
else
	vim.schedule(function()
		@start_server_on_vim_client
		@start_connection_on_vim_clients
		@do_tests
		@stop_both_clients
		@stop_server_on_vim_client
		@terminate_socket_connection_to_vim
		@display_final_result
	end)
end

@spawn_process+=
handle, pid = vim.loop.spawn("node",
	{
		stdio = {stdin, stdout, stderr},
		args = { "ws_server.js" },
		cwd = "../../server"
	}, function(code, signal)
		vim.schedule(function()
			log("exit code" .. code)
			log("exit signal" .. signal)
			@terminate_socket_connection_to_vim
		end)
	end)
if not handle then
  print(pid)
else
  print("started nodejs server " .. vim.inspect(pid))
end

@create_pipes+=
stdin = vim.loop.new_pipe(false)
stdout = vim.loop.new_pipe(false)
stderr = vim.loop.new_pipe(false)


@register_pipe_callbacks+=
stdout:read_start(function(err, data)
	assert(not err, err)
	if data then
    vim.schedule(function()
      print("nodejs out " .. vim.inspect(data))
    end)
		table.insert(events, data)
		@read_stdout_server
	end
end)

stderr:read_start(function(err, data)
	assert(not err, err)
	if data then
    vim.schedule(function()
      print("nodejs err " .. vim.inspect(data))
    end)
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
local client1, client2, client3
local nodejs = false
local client1pipe = [[\\.\pipe\nvim-12800-0]]
local client2pipe = [[\\.\pipe\nvim-16008-0]]
local client3pipe = [[\\.\pipe\nvim-23172-0]]


@initiate_socket_connection_to_vim+=
client1 = vim.fn.sockconnect("pipe", client1pipe, { rpc = true })
client2 = vim.fn.sockconnect("pipe", client2pipe, { rpc = true })
client3 = vim.fn.sockconnect("pipe", client3pipe, { rpc = true })

@terminate_socket_connection_to_vim+=
vim.fn.chanclose(client3)
vim.fn.chanclose(client2)
vim.fn.chanclose(client1)

@start_connection_on_vim_clients+=
vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStartSingle 127.0.0.1 8080", false)
vim.wait(1000)
vim.fn.rpcrequest(client2, 'nvim_exec', "InstantJoinSingle 127.0.0.1 8080", false)
vim.fn.rpcrequest(client3, 'nvim_exec', "InstantJoinSingle 127.0.0.1 8080", false)

@script_variables+=
local num_connected = 0

@script_variables+=
events = {}

@read_stdout_server+=
if vim.startswith(data, "Peer connected") then
	vim.schedule(function()
		num_connected = num_connected + 1
		if num_connected == 3 then
			@do_tests
			@stop_both_clients
		end
	end)
end

@stop_both_clients+=
vim.wait(1000)
vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStop", false)
vim.fn.rpcrequest(client2, 'nvim_exec', "InstantStop", false)
vim.fn.rpcrequest(client3, 'nvim_exec', "InstantStop", false)
vim.fn.rpcrequest(client1, 'nvim_exec', "bufdo bwipeout! %", false)
vim.fn.rpcrequest(client2, 'nvim_exec', "bufdo bwipeout! %", false)
vim.fn.rpcrequest(client3, 'nvim_exec', "bufdo bwipeout! %", false)

@declare_functions+=
local log

@functions+=
function log(str)
  print(str)
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

@start_server_on_vim_client+=
vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStartServer", false)
vim.wait(1000)

@stop_server_on_vim_client+=
vim.wait(1000)
vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStopServer", false)
vim.wait(1000)

@clear_clients+=
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { ""} )
vim.wait(100)

local content1 = vim.fn.rpcrequest(client1, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content1, 1)
assertEq(content1[1], "")


local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 1)
assertEq(content2[1], "")


@do_tests+=
@clear_clients
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "hello"} )
vim.wait(500)

local content1 = vim.fn.rpcrequest(client1, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content1, 1)
assertEq(content1[1], "hello")

vim.wait(100)

local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 1)
assertEq(content2[1], "hello")

vim.wait(100)

local content3 = vim.fn.rpcrequest(client3, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content3, 1)
assertEq(content3[1], "hello")
