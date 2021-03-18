@../../test/session.lua=
@script_variables
@declare_functions
@functions
@spawn_neovim_instances
vim.wait(1000)
@initiate_socket_connection_to_vim
local stdin, stdout, stderr
if nodejs then
	@create_pipes
	@spawn_process
	@register_pipe_callbacks
  @wait_for_nodejs_to_finish
  @close_neovim_instances
else
	vim.schedule(function()
		@start_server_on_vim_client
		@start_connection_on_vim_clients
		@open_buffer_on_client2
		@do_tests
		@stop_both_clients
		@stop_server_on_vim_client
		@terminate_socket_connection_to_vim
		@display_final_result
    @close_neovim_instances
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
      @set_nodejs_as_finished
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
local nodejs = true
local client1pipe = [[\\.\pipe\nvim-12345-0]]
local client2pipe = [[\\.\pipe\nvim-12346-0]]

@initiate_socket_connection_to_vim+=
client1 = vim.fn.sockconnect("pipe", client1pipe, { rpc = true })
client2 = vim.fn.sockconnect("pipe", client2pipe, { rpc = true })

@terminate_socket_connection_to_vim+=
vim.fn.chanclose(client2)
vim.fn.chanclose(client1)

@start_connection_on_vim_clients+=
vim.fn.rpcrequest(client1, 'nvim_exec', "new hello world", false)
vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStartSession 127.0.0.1 8080", false)
vim.wait(1000)
vim.fn.rpcrequest(client2, 'nvim_exec', "InstantJoinSession 127.0.0.1 8080", false)
vim.wait(1000)

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
			@open_buffer_on_client2
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
		-- log("assertEq(" .. vim.inspect(val1) .. ", " .. vim.inspect(val2) .. ") OK")
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

@open_buffer_on_client2+=
vim.wait(100)
vim.fn.rpcrequest(client2, 'nvim_exec', "b hello", false)

@do_tests+=
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "test"} )
vim.wait(1000)
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
vim.fn.rpcrequest(client1, 'nvim_exec', "new hi", false)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "this is hi"} )

vim.wait(100)

vim.fn.rpcrequest(client2, 'nvim_exec', "b hi", false)
local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 1)
assertEq(content2[1], "this is hi")

@do_tests+=
vim.fn.rpcrequest(client1, 'nvim_exec', "new well", false)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "great", "good" } )

vim.wait(100)

vim.fn.rpcrequest(client2, 'nvim_exec', "b well", false)
local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 2)
assertEq(content2[1], "great")
assertEq(content2[2], "good")

@do_tests+=
vim.fn.rpcrequest(client1, 'nvim_exec', "b hi", false)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "hmm..." } )

vim.wait(100)

local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 2)
assertEq(content2[1], "great")
assertEq(content2[2], "good")

vim.fn.rpcrequest(client2, 'nvim_exec', "b hi", false)
local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 1)
assertEq(content2[1], "hmm...")

@start_server_on_vim_client+=
vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStartServer", false)
vim.wait(1000)

@stop_server_on_vim_client+=
vim.wait(1000)
vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStopServer", false)
vim.wait(1000)

@do_tests+=
vim.fn.rpcrequest(client1, 'nvim_exec', "new test123", false)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "AAA" } )

vim.wait(100)

vim.fn.rpcrequest(client2, 'nvim_exec', "b test123", false)
local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 1)
assertEq(content2[1], "AAA")

vim.wait(100)

vim.fn.rpcrequest(client2, 'nvim_buf_set_lines', 0, -1, -1, true, { "BBB" } )

vim.wait(100)

local content1 = vim.fn.rpcrequest(client1, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content1, 2)
assertEq(content1[1], "AAA")
assertEq(content1[2], "BBB")

@script_variables+=
local node_finish = false

@set_nodejs_as_finished+=
node_finish = true

@wait_for_nodejs_to_finish+=
while not node_finish do
  vim.wait(1000)
end

@spawn_neovim_instances+=
local handle_nvim1, err = vim.loop.spawn("nvim",
	{
		args = {"--headless", "--listen", client1pipe },
		cwd = ".",
	}, function(code, signal)
    vim.schedule(function()
      print(client1pipe .. " exited!")
    end)
end)

assert(handle_nvim1, err)

local handle_nvim2, err = vim.loop.spawn("nvim",
	{
		args = {"--headless", "--listen", client2pipe },
		cwd = ".",
	}, function(code, signal)
    vim.schedule(function()
      print(client2pipe .. " exited!")
    end)
end)

assert(handle_nvim2, err)

@close_neovim_instances+=
handle_nvim1:kill()
handle_nvim2:kill()
