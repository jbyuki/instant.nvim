-- Generated from test_session.lua.tl using ntangle.nvim
local client1, client2
local nodejs = false
local client1pipe = [[\\.\\pipe\nvim-15292-0]]
local client2pipe = [[\\.\\pipe\nvim-15640-0]]

local num_connected = 0

events = {}

local outputbuf
local outputwin

local test_passed = 0
local test_failed = 0

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

local log

local assertEq

function log(str)
	table.insert(events,str)
	lines = {}
	for line in vim.gsplit(str, "\n") do 
		table.insert(lines, line)
	end
	vim.api.nvim_buf_set_lines(outputbuf, -1, -1, true, lines)
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
			cwd = "../server"
		}, function(code, signal)
			vim.schedule(function()
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
		
	end)
end

