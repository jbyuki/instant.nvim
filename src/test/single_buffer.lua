-- Generated using ntangle.nvim
local client1, client2, client3
local nodejs = false
local client1pipe = [[\\.\pipe\nvim-12345-0]]
local client2pipe = [[\\.\pipe\nvim-12346-0]]
local client3pipe = [[\\.\pipe\nvim-12347-0]]


local num_connected = 0

events = {}

local test_passed = 0
local test_failed = 0

local node_finish = false

local log

local assertEq

function log(str)
  print(str)
end

function assertEq(val1, val2)
	if val1 == val2 then
		test_passed = test_passed + 1
		log(vim.inspect(val1) .. " = " .. vim.inspect(val2) .. " OK")
	else
		test_failed = test_failed + 1
		log(vim.inspect(val1) .. " = " .. vim.inspect(val2) .. " FAIL")
	end
end

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

vim.wait(500)
client1 = vim.fn.sockconnect("pipe", client1pipe, { rpc = true })
client2 = vim.fn.sockconnect("pipe", client2pipe, { rpc = true })
client3 = vim.fn.sockconnect("pipe", client3pipe, { rpc = true })

local stdin, stdout, stderr
if nodejs then
	stdin = vim.loop.new_pipe(false)
	stdout = vim.loop.new_pipe(false)
	stderr = vim.loop.new_pipe(false)


	handle, pid = vim.loop.spawn("node",
		{
			stdio = {stdin, stdout, stderr},
			args = { "ws_server.js" },
			cwd = "../../server"
		}, function(code, signal)
			vim.schedule(function()
	      node_finish = true

				log("exit code" .. code)
				log("exit signal" .. signal)
				vim.fn.chanclose(client3)
				vim.fn.chanclose(client2)
				vim.fn.chanclose(client1)

			end)
		end)
	if not handle then
	  print(pid)
	else
	  print("started nodejs server " .. vim.inspect(pid))
	end

	stdout:read_start(function(err, data)
		assert(not err, err)
		if data then
	    vim.schedule(function()
	      print("nodejs out " .. vim.inspect(data))
	    end)
			table.insert(events, data)
			if vim.startswith(data, "Server is listening") then
				vim.schedule(function()
					vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStartSingle 127.0.0.1 8080", false)
					vim.wait(200)
					vim.fn.rpcrequest(client2, 'nvim_exec', "InstantJoinSingle 127.0.0.1 8080", false)
					vim.wait(200)
					vim.fn.rpcrequest(client3, 'nvim_exec', "InstantJoinSingle 127.0.0.1 8080", false)
					vim.wait(200)

				end)
			end

			if vim.startswith(data, "Peer connected") then
				vim.schedule(function()
					num_connected = num_connected + 1
					if num_connected == 3 then
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

						vim.wait(1000)
						vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStopServer", false)
						vim.wait(100)


						vim.wait(100)
						vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "again" } )
						vim.wait(100)

						vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStartServer", false)
						vim.wait(100)

						vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStartSingle 127.0.0.1 8080", false)
						vim.wait(200)
						vim.fn.rpcrequest(client2, 'nvim_exec', "InstantJoinSingle 127.0.0.1 8080", false)
						vim.wait(200)
						vim.fn.rpcrequest(client3, 'nvim_exec', "InstantJoinSingle 127.0.0.1 8080", false)
						vim.wait(200)

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

					end
				end)
			end

			if vim.startswith(data, "Peer disconnected") then
				vim.schedule(function()
					num_connected = num_connected - 1
					log("Peer disconnected " .. num_connected)
					if num_connected == 0 then
						log("")
						log("PASSED " .. test_passed)
						log("")
						log("FAILED " .. test_failed)
						log("")

						handle:kill()
					end
				end)
			end

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


  while not node_finish do
    vim.wait(1000)
  end

  handle_nvim1:kill()
  handle_nvim2:kill()
  handle_nvim3:kill()

else
	vim.schedule(function()
		vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStartServer", false)
		vim.wait(100)

		vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStartSingle 127.0.0.1 8080", false)
		vim.wait(200)
		vim.fn.rpcrequest(client2, 'nvim_exec', "InstantJoinSingle 127.0.0.1 8080", false)
		vim.wait(200)
		vim.fn.rpcrequest(client3, 'nvim_exec', "InstantJoinSingle 127.0.0.1 8080", false)
		vim.wait(200)

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

		vim.wait(1000)
		vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStopServer", false)
		vim.wait(100)


		vim.wait(100)
		vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "again" } )
		vim.wait(100)

		vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStartServer", false)
		vim.wait(100)

		vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStartSingle 127.0.0.1 8080", false)
		vim.wait(200)
		vim.fn.rpcrequest(client2, 'nvim_exec', "InstantJoinSingle 127.0.0.1 8080", false)
		vim.wait(200)
		vim.fn.rpcrequest(client3, 'nvim_exec', "InstantJoinSingle 127.0.0.1 8080", false)
		vim.wait(200)

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
		-- @stop_both_clients
		-- @stop_server_on_vim_client
		vim.fn.chanclose(client3)
		vim.fn.chanclose(client2)
		vim.fn.chanclose(client1)

		log("")
		log("PASSED " .. test_passed)
		log("")
		log("FAILED " .. test_failed)
		log("")

    handle_nvim1:kill()
    handle_nvim2:kill()
    handle_nvim3:kill()

	end)
end

