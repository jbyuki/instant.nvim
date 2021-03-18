-- Generated from test_multi.lua.tl using ntangle.nvim
local client1, client2, client3
local nodejs = false
local client1pipe = [[\\.\pipe\nvim-12800-0]]
local client2pipe = [[\\.\pipe\nvim-16008-0]]
local client3pipe = [[\\.\pipe\nvim-23172-0]]


local num_connected = 0

events = {}

local test_passed = 0
local test_failed = 0

local log

local assertEq

function log(str)
  print(str)
end

function assertEq(val1, val2)
	if val1 == val2 then
		test_passed = test_passed + 1
		log("assertEq(" .. vim.inspect(val1) .. ", " .. vim.inspect(val2) .. ") OK")
	else
		test_failed = test_failed + 1
		log("assertEq(" .. vim.inspect(val1) .. ", " .. vim.inspect(val2) .. ") FAIL")
	end
end

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
					vim.wait(1000)
					vim.fn.rpcrequest(client2, 'nvim_exec', "InstantJoinSingle 127.0.0.1 8080", false)
					vim.fn.rpcrequest(client3, 'nvim_exec', "InstantJoinSingle 127.0.0.1 8080", false)
					
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
						vim.wait(1000)
						vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStop", false)
						vim.fn.rpcrequest(client2, 'nvim_exec', "InstantStop", false)
						vim.fn.rpcrequest(client3, 'nvim_exec', "InstantStop", false)
						vim.fn.rpcrequest(client1, 'nvim_exec', "bufdo bwipeout! %", false)
						vim.fn.rpcrequest(client2, 'nvim_exec', "bufdo bwipeout! %", false)
						vim.fn.rpcrequest(client3, 'nvim_exec', "bufdo bwipeout! %", false)
						
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
	
	
else
	vim.schedule(function()
		vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStartServer", false)
		vim.wait(1000)
		
		vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStartSingle 127.0.0.1 8080", false)
		vim.wait(1000)
		vim.fn.rpcrequest(client2, 'nvim_exec', "InstantJoinSingle 127.0.0.1 8080", false)
		vim.fn.rpcrequest(client3, 'nvim_exec', "InstantJoinSingle 127.0.0.1 8080", false)
		
		vim.wait(100)
		vim.fn.rpcrequest(client1, 'nvim_buf_set_lines', 0, 0, -1, true, { ""} )
		vim.wait(100)
		
		local content1 = vim.fn.rpcrequest(client1, 'nvim_buf_get_lines', 0, 0, -1, true)
		assertEq(#content1, 1)
		assertEq(content1[1], "")
		
		
		local content2 = vim.fn.rpcrequest(client2, 'nvim_buf_get_lines', 0, 0, -1, true)
		assertEq(#content2, 1)
		assertEq(content2[1], "")
		
		
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
		vim.wait(1000)
		vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStop", false)
		vim.fn.rpcrequest(client2, 'nvim_exec', "InstantStop", false)
		vim.fn.rpcrequest(client3, 'nvim_exec', "InstantStop", false)
		vim.fn.rpcrequest(client1, 'nvim_exec', "bufdo bwipeout! %", false)
		vim.fn.rpcrequest(client2, 'nvim_exec', "bufdo bwipeout! %", false)
		vim.fn.rpcrequest(client3, 'nvim_exec', "bufdo bwipeout! %", false)
		
		vim.wait(1000)
		vim.fn.rpcrequest(client1, 'nvim_exec', "InstantStopServer", false)
		vim.wait(1000)
		
		vim.fn.chanclose(client3)
		vim.fn.chanclose(client2)
		vim.fn.chanclose(client1)
		
		log("")
		log("PASSED " .. test_passed)
		log("")
		log("FAILED " .. test_failed)
		log("")
		
	end)
end

