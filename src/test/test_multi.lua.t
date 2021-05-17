@../test/single_buffer.lua=
@script_variables
@declare_functions
@functions
@spawn_neovim_instances
vim.wait(500)
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
		@do_tests
		-- @stop_both_clients
		-- @stop_server_on_vim_client
    @retrieve_debug_informations_from_clients
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
local client1pipe = [[\\.\pipe\nvim-12345-0]]
local client2pipe = [[\\.\pipe\nvim-12346-0]]
local client3pipe = [[\\.\pipe\nvim-12347-0]]


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
vim.wait(200)
vim.fn.rpcrequest(client2, 'nvim_exec', "InstantJoinSingle 127.0.0.1 8080", false)
vim.wait(200)
vim.fn.rpcrequest(client3, 'nvim_exec', "InstantJoinSingle 127.0.0.1 8080", false)
vim.wait(200)

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
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStop", false)
vim.wait(200)
vim.fn.rpcrequest(client2, 'nvim_exec', "InstantStop", false)
vim.wait(200)
vim.fn.rpcrequest(client3, 'nvim_exec', "InstantStop", false)
vim.wait(200)
-- vim.fn.rpcrequest(client1, 'nvim_exec', "bufdo bwipeout! %", false)
-- vim.fn.rpcrequest(client2, 'nvim_exec', "bufdo bwipeout! %", false)
-- vim.fn.rpcrequest(client3, 'nvim_exec', "bufdo bwipeout! %", false)

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
		log(vim.inspect(val1) .. " = " .. vim.inspect(val2) .. " OK")
	else
		test_failed = test_failed + 1
		log(vim.inspect(val1) .. " = " .. vim.inspect(val2) .. " FAIL")
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
vim.wait(100)

@stop_server_on_vim_client+=
vim.wait(1000)
vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStopServer", false)
vim.wait(100)

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

local content3 = vim.fn.rpcrequest(client3, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content3, 1)
assertEq(content3[1], "")

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

local handle_nvim3, err = vim.loop.spawn("nvim",
	{
		args = {"--headless", "--listen", client3pipe },
		cwd = ".",
	}, function(code, signal)
    vim.schedule(function()
      print(client3pipe .. " exited!")
    end)
end)

assert(handle_nvim3, err)

@close_neovim_instances+=
handle_nvim1:kill()
handle_nvim2:kill()
handle_nvim3:kill()

@do_tests+=
@stop_both_clients
@stop_server_on_vim_client

vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "again" } )
vim.wait(100)

@start_server_on_vim_client
@start_connection_on_vim_clients
vim.wait(100)
vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "AAA" } )
vim.wait(100)

local content1 = vim.fn.rpcrequest(client1, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content1, 1)
assertEq(content1[1], "AAA")

vim.wait(100)

local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content2, 1)
assertEq(content2[1], "AAA")

vim.wait(100)

local content3 = vim.fn.rpcrequest(client3, 'nvim_buf_get_lines', 0, 0, -1, true)
assertEq(#content3, 1)
assertEq(content3[1], "AAA")

-- @retrieve_debug_informations_from_clients+=
-- local client1_sent = vim.fn.rpcrequest(client1, 'nvim_exec_lua', [[return client_sent]], {})
-- print("client1_sent")
-- for _, msg in ipairs(client1_sent) do
  -- print(vim.inspect(msg))
-- end
-- 
-- 
-- local client2_sent = vim.fn.rpcrequest(client2, 'nvim_exec_lua', [[return client_sent]], {})
-- print("client2_sent")
-- for _, msg in ipairs(client2_sent) do
  -- print(vim.inspect(msg))
-- end
-- 
-- local client3_sent = vim.fn.rpcrequest(client3, 'nvim_exec_lua', [[return client_sent]], {})
-- print("client3_sent")
-- for _, msg in ipairs(client3_sent) do
  -- print(vim.inspect(msg))
-- end
-- 
-- local server_received = vim.fn.rpcrequest(client1, 'nvim_exec_lua', [[return server_received]], {})
-- print("server_received")
-- for _, msg in ipairs(server_received) do
  -- print(vim.inspect(msg))
-- end
-- 
-- local client1_received = vim.fn.rpcrequest(client1, 'nvim_exec_lua', [[return client_received]], {})
-- print("client1_received")
-- for _, msg in ipairs(client1_received) do
  -- print(vim.inspect(msg))
-- end
-- 
-- 
-- local client2_recived = vim.fn.rpcrequest(client2, 'nvim_exec_lua', [[return client_received]], {})
-- print("client2_recived")
-- for _, msg in ipairs(client2_recived) do
  -- print(vim.inspect(msg))
-- end
-- 
-- local client3_received = vim.fn.rpcrequest(client3, 'nvim_exec_lua', [[return client_received]], {})
-- print("client3_received")
-- for _, msg in ipairs(client3_received) do
  -- print(vim.inspect(msg))
-- end
