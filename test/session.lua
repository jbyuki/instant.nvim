-- Generated using ntangle.nvim
local client1, client2
local nodejs = true
local client1pipe = [[\\.\pipe\nvim-12345-0]]
local client2pipe = [[\\.\pipe\nvim-12346-0]]

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
		-- log("assertEq(" .. vim.inspect(val1) .. ", " .. vim.inspect(val2) .. ") OK")
	else
		test_failed = test_failed + 1
		log("assertEq(" .. vim.inspect(val1) .. ", " .. vim.inspect(val2) .. ") FAIL")
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

vim.wait(1000)
client1 = vim.fn.sockconnect("pipe", client1pipe, { rpc = true })
client2 = vim.fn.sockconnect("pipe", client2pipe, { rpc = true })

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
				vim.fn.chanclose(client2)
				vim.fn.chanclose(client1)
				
			end)
		end)
	
	stdout:read_start(function(err, data)
		assert(not err, err)
		if data then
			table.insert(events, data)
			if vim.startswith(data, "Server is listening") then
				vim.schedule(function()
					vim.fn.rpcrequest(client1, 'nvim_exec', "new hello world", false)
					vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStartSession 127.0.0.1 8080", false)
					vim.wait(1000)
					vim.fn.rpcrequest(client2, 'nvim_exec', "InstantJoinSession 127.0.0.1 8080", false)
					vim.wait(1000)
					
				end)
			end
			
			if vim.startswith(data, "Peer connected") then
				vim.schedule(function()
					num_connected = num_connected + 1
					if num_connected == 2 then
						table.insert(events, "Both clients connected and it's all fine")
						
						vim.wait(100)
						vim.fn.rpcrequest(client2, 'nvim_exec', "b hello", false)
						
						vim.wait(100)
						vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "test"} )
						vim.wait(1000)
						local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
						assertEq(#content2, 1)
						assertEq(content2[1], "test")
						
						vim.fn.rpcrequest(client1, 'nvim_exec', "new hi", false)
						vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "this is hi"} )
						
						vim.wait(100)
						
						vim.fn.rpcrequest(client2, 'nvim_exec', "b hi", false)
						local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
						assertEq(#content2, 1)
						assertEq(content2[1], "this is hi")
						
						vim.fn.rpcrequest(client1, 'nvim_exec', "new well", false)
						vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "great", "good" } )
						
						vim.wait(100)
						
						vim.fn.rpcrequest(client2, 'nvim_exec', "b well", false)
						local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
						assertEq(#content2, 2)
						assertEq(content2[1], "great")
						assertEq(content2[2], "good")
						
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
						
						vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStop", false)
						vim.fn.rpcrequest(client2, 'nvim_exec', "InstantStop", false)
						vim.fn.rpcrequest(client1, 'nvim_exec', "bufdo bwipeout! %", false)
						vim.fn.rpcrequest(client2, 'nvim_exec', "bufdo bwipeout! %", false)
						
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
			table.insert(events, data)
		end
	end)
	
	
  while not node_finish do
    vim.wait(1000)
  end
  
  handle_nvim1:kill()
  handle_nvim2:kill()
else
	vim.schedule(function()
		vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStartServer", false)
		vim.wait(1000)
		
		vim.fn.rpcrequest(client1, 'nvim_exec', "new hello world", false)
		vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStartSession 127.0.0.1 8080", false)
		vim.wait(1000)
		vim.fn.rpcrequest(client2, 'nvim_exec', "InstantJoinSession 127.0.0.1 8080", false)
		vim.wait(1000)
		
		vim.wait(100)
		vim.fn.rpcrequest(client2, 'nvim_exec', "b hello", false)
		
		vim.wait(100)
		vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "test"} )
		vim.wait(1000)
		local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
		assertEq(#content2, 1)
		assertEq(content2[1], "test")
		
		vim.fn.rpcrequest(client1, 'nvim_exec', "new hi", false)
		vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "this is hi"} )
		
		vim.wait(100)
		
		vim.fn.rpcrequest(client2, 'nvim_exec', "b hi", false)
		local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
		assertEq(#content2, 1)
		assertEq(content2[1], "this is hi")
		
		vim.fn.rpcrequest(client1, 'nvim_exec', "new well", false)
		vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { "great", "good" } )
		
		vim.wait(100)
		
		vim.fn.rpcrequest(client2, 'nvim_exec', "b well", false)
		local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
		assertEq(#content2, 2)
		assertEq(content2[1], "great")
		assertEq(content2[2], "good")
		
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
		
		vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStop", false)
		vim.fn.rpcrequest(client2, 'nvim_exec', "InstantStop", false)
		vim.fn.rpcrequest(client1, 'nvim_exec', "bufdo bwipeout! %", false)
		vim.fn.rpcrequest(client2, 'nvim_exec', "bufdo bwipeout! %", false)
		
		vim.wait(1000)
		vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStopServer", false)
		vim.wait(1000)
		
		vim.fn.chanclose(client2)
		vim.fn.chanclose(client1)
		
		log("")
		log("PASSED " .. test_passed)
		log("")
		log("FAILED " .. test_failed)
		log("")
		
    handle_nvim1:kill()
    handle_nvim2:kill()
	end)
end

