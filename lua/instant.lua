local StopClient

local GenerateWebSocketKey -- we must forward declare local functions because otherwise it picks the global one

local OpAnd, OpOr, OpRshift, OpLshift

local ConvertToBase64

local ConvertBytesToString

local SendText

local OpXor

local nocase

local DetachFromBuffer

local utf8len, utf8char

local utf8insert

local utf8remove

local genPID

local SendOp

local splitArray

local utf8split

local isPIDEqual

local isLower

local getConfig

local client

local base64 = {}

local websocketkey

events = {}

local iptable = {}

local frames = {}
local first_chunk
local fragmented = ""
local remaining = 0

local attached = {}

local detach = {}

allprev = {}
local prev = { "" }

-- pos = [(num, site)]
local MAXINT = 2^15 -- can be adjusted
local startpos, endpos = {{0, 0}}, {{MAXINT, 0}}
-- line = [pos]
-- pids = [line]
local allpids = {}
local pids = {}

local agent = 0

local author = vim.api.nvim_get_var("instant_username")

local ignores = {}

local singlebuf

local vtextGroup

local old_namespace

local cursors = {}
local cursorGroup

local sessionshare = false

local loc2rem = {}
local rem2loc = {}

local vimcmd = vim.api.nvim_command

local status_cb = {}

local b64 = 0
for i=string.byte('a'), string.byte('z') do base64[b64] = string.char(i) b64 = b64+1 end
for i=string.byte('A'), string.byte('Z') do base64[b64] = string.char(i) b64 = b64+1 end
for i=string.byte('0'), string.byte('9') do base64[b64] = string.char(i) b64 = b64+1 end
base64[b64] = '+' b64 = b64+1
base64[b64] = '/'


function GenerateWebSocketKey()
	key = {}
	for i =0,15 do
		table.insert(key, math.floor(math.random()*255))
	end
	
	return key
end

function OpAnd(a, b)
	return vim.api.nvim_call_function("and", {a, b})
end

function OpOr(a, b)
	return vim.api.nvim_call_function("or", {a, b})
end

function OpRshift(a, b)
	return math.floor(a/math.pow(2, b))
end

function OpLshift(a, b)
	return a*math.pow(2, b)
end

function ConvertToBase64(array)
	local i
	local str = ""
	for i=0,#array-3,3 do
		local b1 = array[i+0+1]
		local b2 = array[i+1+1]
		local b3 = array[i+2+1]

		local c1 = OpRshift(b1, 2)
		local c2 = OpLshift(OpAnd(b1, 0x3), 4)+OpRshift(b2, 4)
		local c3 = OpLshift(OpAnd(b2, 0xF), 2)+OpRshift(b3, 6)
		local c4 = OpAnd(b3, 0x3F)

		str = str .. base64[c1]
		str = str .. base64[c2]
		str = str .. base64[c3]
		str = str .. base64[c4]
	end

	local rest = #array * 8 - #str * 6
	if rest == 8 then
		local b1 = array[#array]
	
		local c1 = OpRshift(b1, 2)
		local c2 = OpLshift(OpAnd(b1, 0x3), 4)
	
		str = str .. base64[c1]
		str = str .. base64[c2]
		str = str .. "="
		str = str .. "="
	
	elseif rest == 16 then
		local b1 = array[#array-1]
		local b2 = array[#array]
	
		local c1 = OpRshift(b1, 2)
		local c2 = OpLshift(OpAnd(b1, 0x3), 4)+OpRshift(b2, 4)
		local c3 = OpLshift(OpAnd(b2, 0xF), 2)
	
		str = str .. base64[c1]
		str = str .. base64[c2]
		str = str .. base64[c3]
		str = str .. "="
	end
	

	return str
end

function ConvertBytesToString(tab)
	local s = ""
	for _,el in ipairs(tab) do
		s = s .. string.char(el)
	end
	return s
end

function SendText(str)
	local mask = {}
	for i=1,4 do
		table.insert(mask, math.floor(math.random() * 255))
	end
	
	local masked = {}
	for i=0,#str-1 do
		local j = i%4
		local trans = OpXor(string.byte(string.sub(str, i+1, i+1)), mask[j+1])
		table.insert(masked, trans)
	end
	
	local frame = {
		0x81, 0x80
	}
	
	if #masked <= 125 then
		frame[2] = frame[2] + #masked
	elseif #masked < math.pow(2, 16) then
		frame[2] = frame[2] + 126
		local b1 = OpRshift(#masked, 8)
		local b2 = OpAnd(#masked, 0xFF)
		table.insert(frame, b1)
		table.insert(frame, b2)
	else
		frame[2] = frame[2] + 127
		for i=0,7 do
			local b = OpAnd(OpRshift(#masked, (7-i)*8), 0xFF)
			table.insert(frame, b)
		end
	end
	
	
	for i=1,4 do
		table.insert(frame, mask[i])
	end
	
	for i=1,#masked do
		table.insert(frame, masked[i])
	end
	
	local s = ConvertBytesToString(frame)
	
	client:write(s)
	
end

function OpXor(a, b)
	return vim.api.nvim_call_function("xor", {a, b})
end

function nocase (s)
	s = string.gsub(s, "%a", function (c)
		if string.match(c, "[a-zA-Z]") then
			return string.format("[%s%s]", 
				string.lower(c),
				string.upper(c))
		else
			return c
		end
	end)
	return s
end

function utf8len(str)
	return vim.str_utfindex(str)
end

function utf8char(str, i)
	if i >= utf8len(str) or i < 0 then return nil end
	local s1 = vim.str_byteindex(str, i)
	local s2 = vim.str_byteindex(str, i+1)
	return string.sub(str, s1+1, s2)
end

function utf8insert(str, i, c)
	if i == utf8len(str) then
		return str .. c
	end
	local s1 = vim.str_byteindex(str, i)
	return string.sub(str, 1, s1) .. c .. string.sub(str, s1+1)
end

function utf8remove(str, i)
	local s1 = vim.str_byteindex(str, i)
	local s2 = vim.str_byteindex(str, i+1)

	return string.sub(str, 1, s1) .. string.sub(str, s2+1)
end

function genPID(p, q, s, i)
	local a = (p[i] and p[i][1]) or 0
	local b = (q[i] and q[i][1]) or MAXINT

	if a+1 < b then
		return {{math.random(a+1,b-1), s}}
	end

	local G = genPID(p, q, s, i+1)
	table.insert(G, 1, {
		(p[i] and p[i][1]) or 0, 
		(p[i] and p[i][2]) or s})
	return G
end

local function afterPID(x, y)
	if x == #pids[y] then return pids[y+1][1]
	else return pids[y][x+1] end
end

function SendOp(buf, op)
	local rem = loc2rem[buf]
	
	local obj = {
		["type"] = "text",
		["ops"] = { op },
		["buf"] = rem,
		["author"] = author,
	}
	local encoded = vim.api.nvim_call_function("json_encode", { obj })
	
	if not encoded then
		print("line number " .. debug.getinfo(1).currentline)
	end
	SendText(encoded)
	-- table.insert(events, "sent " .. encoded)
	
end

local function findCharPositionBefore(opid, ipid)
	local px, py = 1, 1
	for y,lpid in ipairs(pids) do
		for x,pid in ipairs(lpid) do
			if not isLower(pid, opid) and not isLower(pid, ipid) then 
				return px, py
			end
			px, py = x, y
		end
	end
end

function splitArray(a, p)
	local left, right = {}, {}
	for i=1,#a do
		if i < p then left[#left+1] = a[i]
		else right[#right+1] = a[i] end
	end
	return left, right
end

function utf8split(str, i)
	local s1 = vim.str_byteindex(str, i)
	return string.sub(str, 1, s1), string.sub(str, s1+1)
end

function isPIDEqual(a, b)
	if #a ~= #b then return false end
	for i=1,#a do
		if a[i][1] ~= b[i][1] then return false end
		if a[i][2] ~= b[i][2] then return false end
	end
	return true
end

local function findCharPositionExact(opid)
	local y1, y2 = 1, #pids
	while true do
		local ym = math.floor((y2 + y1)/2)
		if ym == y1 then break end
		if isLower(pids[ym][1], opid) then
			y1 = ym
		else
			y2 = ym
		end
	end
	
	local y = y1
	for x,pid in ipairs(pids[y]) do
		if isPIDEqual(pid, opid) then 
			return x, y
		end
	
		if not isLower(pid, opid) then
			return nil
		end
	end
	
	
end

function isLower(a, b)
	for i, ai in ipairs(a) do
		if i > #b then return false end
		local bi = b[i]
		if ai[1] < bi[1] then return true
		elseif ai[1] > bi[1] then return false
		elseif ai[2] < bi[2] then return true
		elseif ai[2] > bi[2] then return false
		end
	end
	return true
end

local function Refresh()
	local obj = {
		["type"] = "request",
	}
	local encoded = vim.api.nvim_call_function("json_encode", { obj })
	if not encoded then
		print("line number " .. debug.getinfo(1).currentline)
	end
	SendText(encoded)
	-- table.insert(events, "sent " .. encoded)
	
	
end

local function findPIDBefore2(opid)
	local pppid, ppid
	for y,lpid in ipairs(pids) do
		for x,pid in ipairs(lpid) do
			if not isLower(pid, opid) then 
				return pppid 
			end
			pppid = ppid
			ppid = pid
		end
	end
end

function getConfig(varname, default)
	local v, value = pcall(function() return vim.api.nvim_get_var("instant_name_hl_group") end)
	if not v then value = default end
	return value
end

function instantOpenOrCreateBuffer(buf)
	if sessionshare or buf == singlebuf then
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
		
		local middlepos = genPID(startpos, endpos, agent, 1)
		pids = {
			{ startpos },
			{ middlepos },
			{ endpos },
		}
		
		local bpid = pids[2][1] -- middlepos
		local epid = pids[3][1] -- endpos
		
		for i=1,#lines do
			local line = lines[i]
			if i > 1 then
				local newpid = genPID(bpid, epid, agent, 1)
				bpid = newpid
				
				table.insert(pids, i+1, { newpid })
				
				-- For testing purposes
				-- @script_variables+=
				-- local typeset = {}
				-- 
				-- @init_typeset+=
				-- for i=string.byte('a'),string.byte('z') do
				-- 	table.insert(typeset, string.char(i))
				-- end
				-- 
				-- for i=string.byte('A'),string.byte('Z') do
				-- 	table.insert(typeset, string.char(i))
				-- end
				-- 
				-- for i=string.byte('0'),string.byte('9') do
				-- 	table.insert(typeset, string.char(i))
				-- end
				-- 
				-- @type_random_function+=
				-- function TypeRandom(limit, ms)
				-- 	ms = ms or 50
				-- 	local timer = vim.loop.new_timer()
				-- 	local i = 0
				-- 	timer:start(300, ms, function()
				-- 		vim.schedule(function()
				-- 			if math.random() < 0.7 or vim.api.nvim_buf_line_count(0) < 2 then
				-- 				if math.random() < 0.1 then
				-- 					@pick_random_line
				-- 					@insert_new_line
				-- 				elseif math.random() < 0.1 then
				-- 					@pick_random_line
				-- 					@split_line_into_two_lines
				-- 				else
				-- 					@pick_random_line
				-- 					@pick_random_position_in_line
				-- 					@pick_random_character
				-- 					@insert_character
				-- 				end
				-- 			elseif math.random() < 0.9 then
				-- 				if math.random() < 0.1 then
				-- 					@pick_random_line
				-- 					@delete_line
				-- 				elseif math.random() < 0.1 then
				-- 					@pick_random_line
				-- 					@concat_line
				-- 				else
				-- 					@pick_random_line
				-- 					@pick_random_position_in_line
				-- 					@delete_character
				-- 				end
				-- 			else
				-- 				@pick_random_line
				-- 				@replace_with_random_line
				-- 			end
				-- 		end)
				-- 		if i > limit then timer:close() end
				-- 		i = i + 1
				-- 	end)
				-- end
				-- 
				-- @pick_random_line+=
				-- local lcount = vim.api.nvim_buf_line_count(0)
				-- local lnum = math.random(0, lcount-1) -- # zero indexed
				-- 
				-- @insert_new_line+=
				-- vim.api.nvim_buf_set_lines(0, lnum, lnum, true, { "" }) 
				-- 
				-- @pick_random_position_in_line+=
				-- local curline = vim.api.nvim_buf_get_lines(0, lnum, lnum+1, true)[1]
				-- local cnum = math.random(1, string.len(curline))
				-- 
				-- @pick_random_character+=
				-- local c = typeset[math.floor(math.random()*(#typeset-1)+0.5)+1]
				-- 
				-- @insert_character+=
				-- curline = string.sub(curline, 1, cnum-1) .. c .. string.sub(curline, cnum)
				-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, { curline }) 
				-- 
				-- @delete_line+=
				-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, {})
				-- 
				-- @delete_character+=
				-- curline = string.sub(curline, 1, cnum-1) .. string.sub(curline, cnum+1)
				-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, { curline }) 
				-- 
				-- @split_line_into_two_lines+=
				-- local curline = vim.api.nvim_buf_get_lines(0, lnum, lnum+1, true)[1]
				-- local cnum = math.random(0, string.len(curline)-1) 
				-- local r, l = utf8split(curline, cnum)
				-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, { r, l }) 
				-- 
				-- @concat_line+=
				-- if lnum < lcount-1 then 
				-- 	local c = vim.api.nvim_buf_get_lines(0, lnum, lnum+2, true)
				-- 	vim.api.nvim_buf_set_lines(0, lnum, lnum+2, true, { c[1] .. c[2] })
				-- end
				-- 
				-- @replace_with_random_line+=
				-- local lnewcount = math.random(1,20)
				-- local newline = ""
				-- for i=1,lnewcount do
				-- 	@pick_random_character
				-- 	newline = newline .. c
				-- end
				-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, { newline })
				-- 
				-- @display_xor_ranges+=
				-- table.insert(events, "add range " .. vim.inspect(add_range))
				-- table.insert(events, "del range " .. vim.inspect(del_range))
				-- 
				-- @check_if_pid_match_with_prev+=
				-- for i=1,#pids do
				-- 	local exp
				-- 	if i == 1 or i == #pids then
				-- 		exp = 1
				-- 	else
				-- 		exp = #prev[i-1] + 1
				-- 	end
				-- 	local res = #pids[i]
				-- 	if exp ~= res then
				-- 		table.insert(events, exp .. " " .. res .. " NG\n")
				-- 	end
				-- end
				-- 
				-- @display_states+=
				-- for i,lpid in ipairs(pids) do
				-- 	table.insert(events, i .. ": " .. vim.inspect(lpid))
				-- end
				-- for i,line in ipairs(prev) do
				-- 	table.insert(events, i .. ": " .. vim.inspect(line))
				-- end
				-- local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
				-- for i,line in ipairs(all_lines) do
				-- 	if prev[i] ~= line then
				-- 		table.insert(events, "DISC")
				-- 	end
				-- 	table.insert(events, i .. "> " .. vim.inspect(line))
				-- end
				
			end
		
			for j=1,string.len(line) do
				local newpid = genPID(bpid, epid, agent, 1)
				bpid = newpid
				
				table.insert(pids[i+1], newpid)
				
			end
		
		end
		
		prev = lines
		
		allprev[buf] = prev
		allpids[buf] = pids
		

		local fullname = vim.api.nvim_buf_get_name(buf)
		local cwdname = vim.api.nvim_call_function("fnamemodify",
			{ fullname, ":." })
		local bufname = cwdname
		if bufname == fullname then
			bufname = vim.api.nvim_call_function("fnamemodify",
			{ fullname, ":t" })
		end
		
		if not rem2loc[agent] then
			rem2loc[agent] = {}
		end
		
		rem2loc[agent][buf] = buf
		loc2rem[buf] = { agent, buf }
		
		local rem = loc2rem[buf]
		
		local obj = {
			["type"] = "initial",
			["name"] = bufname,
			["bufid"] = rem,
			["pids"] = allpids[buf],
			["content"] = allprev[buf]
		}
		encoded = vim.api.nvim_call_function("json_encode", { obj })
		
		if not encoded then
			print("line number " .. debug.getinfo(1).currentline)
		end
		SendText(encoded)
		-- table.insert(events, "sent " .. encoded)
		

		detach[buf] = nil
		
		ignores[buf] = {}
		
		if not attached[buf] then
			local attach_success = vim.api.nvim_buf_attach(buf, false, {
				on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
					if detach[buf] then
						table.insert(events, "Detached from buffer " .. buf)
						detach[buf] = nil
						return true
					end
					
					if ignores[buf][changedtick] then
						ignores[buf][changedtick] = nil
						return
					end
					
					prev = allprev[buf]
					pids = allpids[buf]
					
					local cur_lines = vim.api.nvim_buf_get_lines(buf, firstline, new_lastline, true)
					
					local add_range = {
						sx = -1,
						sy = firstline,			
						ex = -1, -- at position there is \n
						ey = new_lastline
					}
					
					local del_range = {
						sx = -1,
						sy = firstline,
						ex = -1,
						ey = lastline,
					}
					
					while (add_range.ey > add_range.sy or (add_range.ey == add_range.sy and add_range.ex >= add_range.sx)) and 
						  (del_range.ey > del_range.sy or (del_range.ey == del_range.sy and del_range.ex >= del_range.sx)) do
					
						local c1, c2
						if add_range.ex == -1 then c1 = "\n"
						else c1 = utf8char(cur_lines[add_range.ey-firstline+1] or "", add_range.ex) end
					
						if del_range.ex == -1 then c2 = "\n"
						else c2 = utf8char(prev[del_range.ey+1] or "", del_range.ex) end
					
						if c1 ~= c2 then
							break
						end
					
						local add_prev, del_prev
						if add_range.ex == -1 then
							add_prev = { ey = add_range.ey-1, ex = utf8len(cur_lines[add_range.ey-firstline] or "")-1 }
						else
							add_prev = { ex = add_range.ex-1, ey = add_range.ey }
						end
						
						if del_range.ex == -1 then
							del_prev = { ey = del_range.ey-1, ex = utf8len(prev[del_range.ey] or "")-1 }
						else
							del_prev = { ex = del_range.ex-1, ey = del_range.ey }
						end
						
						add_range.ex, add_range.ey = add_prev.ex, add_prev.ey
						del_range.ex, del_range.ey = del_prev.ex, del_prev.ey
						
					end
					
					while (add_range.sy < add_range.ey or (add_range.sy == add_range.ey and add_range.sx <= add_range.ex)) and 
						  (del_range.sy < del_range.ey or (del_range.sy == del_range.ey and del_range.sx <= del_range.ex)) do
					
						local c1, c2
						if add_range.sx == -1 then c1 = "\n"
						else c1 = utf8char(cur_lines[add_range.sy-firstline+1] or "", add_range.sx) end
					
						if del_range.sx == -1 then c2 = "\n"
						else c2 = utf8char(prev[del_range.sy+1] or "", del_range.sx) end
					
						if c1 ~= c2 then
							break
						end
						add_range.sx = add_range.sx+1
						del_range.sx = del_range.sx+1
						
						if add_range.sx == utf8len(cur_lines[add_range.sy-firstline+1] or "") then
							add_range.sx = -1
							add_range.sy = add_range.sy + 1
						end
						
						if del_range.sx == utf8len(prev[del_range.sy+1] or "") then
							del_range.sx = -1
							del_range.sy = del_range.sy + 1
						end
						
					end
					
					
					-- @display_xor_ranges
					local endx = del_range.ex
					for y=del_range.ey, del_range.sy,-1 do
						local startx=-1
						if y == del_range.sy then
							startx = del_range.sx
						end
						
						for x=endx,startx,-1 do
							if x == -1 then
								if #prev > 1 then
									if y > 0 then
										prev[y] = prev[y] .. (prev[y+1] or "")
									end
									table.remove(prev, y+1)
									
									local del_pid = pids[y+2][1]
									for i,pid in ipairs(pids[y+2]) do
										if i > 1 then
											table.insert(pids[y+1], pid)
										end
									end
									table.remove(pids, y+2)
									
									SendOp(buf, { "del", del_pid })
									
								end
							else
								prev[y+1] = utf8remove(prev[y+1], x)
								
								local del_pid = pids[y+2][x+2]
								table.remove(pids[y+2], x+2)
								
								SendOp(buf, { "del", del_pid })
								
							end
						end
						endx = utf8len(prev[y] or "")-1
					end
					
					local startx = add_range.sx
					for y=add_range.sy, add_range.ey do
						local endx
						if y == add_range.ey then
							endx = add_range.ex
						else
							endx = utf8len(cur_lines[y-firstline+1])-1
						end
						
						for x=startx,endx do
							if x == -1 then
								if cur_lines[y-firstline] then
									local l, r = utf8split(prev[y], utf8len(cur_lines[y-firstline]))
									prev[y] = l
									table.insert(prev, y+1, r)
								else
									table.insert(prev, y+1, "")
								end
								
								local pidx
								if cur_lines[y-firstline] then
									pidx = utf8len(cur_lines[y-firstline])+1
								else
									pidx = #pids[y+1]
								end
								
								local before_pid = pids[y+1][pidx]
								local after_pid = afterPID(pidx, y+1)
								local new_pid = genPID(before_pid, after_pid, agent, 1)
								
								local l, r = splitArray(pids[y+1], pidx+1)
								pids[y+1] = l
								table.insert(r, 1, new_pid)
								table.insert(pids, y+2, r)
								
								SendOp(buf, { "ins", "\n", before_pid, new_pid })
								
							else
								local c = utf8char(cur_lines[y-firstline+1], x)
								prev[y+1] = utf8insert(prev[y+1], x, c)
								
								local before_pid = pids[y+2][x+1]
								local after_pid = afterPID(x+1, y+2)
								local new_pid = genPID(before_pid, after_pid, agent, 1)
								
								table.insert(pids[y+2], x+2, new_pid)
								
								SendOp(buf, { "ins", c, before_pid, new_pid })
								
							end
						end
						startx = -1
					end
					
					allprev[buf] = prev
					allpids[buf] = pids
					
				end,
				on_detach = function(_, buf)
					table.insert(events, "detached " .. buf)
					attached[buf] = nil
				end
			})
		
			if attach_success then
				table.insert(events, "has_attached[" .. buf .. "] = true")
				attached[buf] = true
			end
		else
			detach[buf] = nil
		end
		
		
		
	end

end

local function attach_status_update(cb)
	table.insert(status_cb, cb)
	local positions = {}
	for aut, c in pairs(cursors) do 
		local buf = c.buf
		local fullname = vim.api.nvim_buf_get_name(buf)
		local cwdname = vim.api.nvim_call_function("fnamemodify",
			{ fullname, ":." })
		local bufname = cwdname
		if bufname == fullname then
			bufname = vim.api.nvim_call_function("fnamemodify",
			{ fullname, ":t" })
		end
		
		local line
		if c.ext_id then
			line,_ = unpack(vim.api.nvim_buf_get_extmark_by_id(
					buf, c.id, c.ext_id, {}))
		else
			line= c.y
		end
		table.insert(positions , {aut, bufname, line})
	end
	
	return positions
end



local function StartClient(first, appuri, port)
	local v, username = pcall(function() return vim.api.nvim_get_var("instant_username") end)
	if not v then
		error("Please specify a username in g:instant_username")
	end
	
	
	detach = {}
	
	vtextGroup = getConfig("instant_name_hl_group", "CursorLineNr")
	
	old_namespace = {}
	
	cursorGroup = getConfig("instant_cursor_hl_group", "Cursor")
	cursors = {}
	
	loc2rem = {}
	rem2loc = {}
	
	port = port or 80
	
	client = vim.loop.new_tcp()
	iptable = vim.loop.getaddrinfo(appuri)
	if #iptable == 0 then
		print("Could not resolve address")
		return
	end
	local ipentry = iptable[1]
	

	client:connect(ipentry.addr, port, vim.schedule_wrap(function(err) 
		if err then
			table.insert(events, "connection err " .. vim.inspect(err))
			for bufhandle,_ in pairs(allprev) do
				if vim.api.nvim_buf_is_loaded(bufhandle) then
					DetachFromBuffer(bufhandle)
				end
			end
			StopClient()
			
			
			for aut,_ in pairs(cursors) do
				if cursors[aut] then
					vim.api.nvim_buf_clear_namespace(
						cursors[aut].buf, cursors[aut].id,
						0, -1)
					cursors[aut] = nil
				end
				
				if old_namespace[aut] then
					vim.api.nvim_buf_clear_namespace(
						old_namespace[aut].buf, old_namespace[aut].id,
						0, -1)
					old_namespace[aut] = nil
				end
				
			end
			cursors = {}
			
			vimcmd("augroup instantSession")
			vimcmd("autocmd!")
			vimcmd("augroup end")
			
			
			error("There was an error during connection: " .. err)
			return
		end
		
		client:read_start(vim.schedule_wrap(function(err, chunk)
			if err then
				table.insert(events, "connection err " .. vim.inspect(err))
				for bufhandle,_ in pairs(allprev) do
					if vim.api.nvim_buf_is_loaded(bufhandle) then
						DetachFromBuffer(bufhandle)
					end
				end
				StopClient()
				
				
				for aut,_ in pairs(cursors) do
					if cursors[aut] then
						vim.api.nvim_buf_clear_namespace(
							cursors[aut].buf, cursors[aut].id,
							0, -1)
						cursors[aut] = nil
					end
					
					if old_namespace[aut] then
						vim.api.nvim_buf_clear_namespace(
							old_namespace[aut].buf, old_namespace[aut].id,
							0, -1)
						old_namespace[aut] = nil
					end
					
				end
				cursors = {}
				
				vimcmd("augroup instantSession")
				vimcmd("autocmd!")
				vimcmd("augroup end")
				
				
				error("There was an error during connection: " .. err)
				return
			end
			
			-- table.insert(events, "err: " .. vim.inspect(err) .. " chunk: " .. vim.inspect(chunk))
			
			if chunk then
				if string.match(chunk, nocase("^HTTP")) then
					-- can be Sec-WebSocket-Accept or Sec-Websocket-Accept
					if string.match(chunk, nocase("Sec%-WebSocket%-Accept")) then
						table.insert(events, "handshake was successful")
						local obj = {
							["type"] = "available"
						}
						local encoded = vim.api.nvim_call_function("json_encode", { obj })
						if not encoded then
							print("line number " .. debug.getinfo(1).currentline)
						end
						SendText(encoded)
						-- table.insert(events, "sent " .. encoded)
						
						
					end
				else
					local opcode, fin
					-- if multiple tcp packets are 
					-- sent at once
					while string.len(chunk) > 0 do
						-- if tcp packets are sent
						-- fragmented
						if remaining == 0 then
							first_chunk = chunk
						end
						local b1 = string.byte(string.sub(first_chunk,1,1))
						-- table.insert(frames, "FIN " .. OpAnd(b1, 0x80))
						-- table.insert(frames, "OPCODE " .. OpAnd(b1, 0xF))
						local b2 = string.byte(string.sub(first_chunk,2,2))
						-- table.insert(frames, "MASK " .. OpAnd(b2, 0x80))
						opcode = OpAnd(b1, 0xF)
						fin = OpRshift(b1, 7)
						
						if opcode == 0x1 then -- TEXT
							local paylen = OpAnd(b2, 0x7F)
							local paylenlen = 0
							if paylen == 126 then -- 16 bits length
								local b3 = string.byte(string.sub(first_chunk,3,3))
								local b4 = string.byte(string.sub(first_chunk,4,4))
								paylen = OpLshift(b3, 8) + b4
								paylenlen = 2
							elseif paylen == 127 then
								paylen = 0
								for i=0,7 do -- 64 bits length
									paylen = OpLshift(paylen, 8) 
									paylen = paylen + string.byte(string.sub(first_chunk,i+3,i+3))
								end
								paylenlen = 8
							end
							-- table.insert(frames, "PAYLOAD LENGTH " .. paylen)
							
							if remaining == 0 then
								local text = string.sub(chunk, 2+paylenlen+1, 2+paylenlen+1+(paylen-1))
								
								chunk = string.sub(chunk, 2+paylenlen+1+paylen)
								fragmented = text
								remaining = paylen - string.len(text)
							else
								fragmented = fragmented .. chunk
								remaining = remaining - string.len(chunk)
								chunk = ""
							end
						
							if remaining == 0 then
								local decoded = vim.api.nvim_call_function("json_decode", {fragmented})
								
								if decoded then
									if decoded["type"] == "text" then
										local ops = decoded["ops"]
										local opline = 0
										local opcol = 0
										local lastPID
										for _,op in ipairs(ops) do
											-- table.insert(events, "receive op " .. vim.inspect(op))
											-- @display_states
											local buf
											if sessionshare then
												local ag, bufid = unpack(decoded["buf"])
												buf = rem2loc[ag][bufid]
												
											else
												buf = singlebuf
											end
											
											prev = allprev[buf]
											pids = allpids[buf]
											
											local tick = vim.api.nvim_buf_get_changedtick(buf)+1
											ignores[buf][tick] = true
											
											if op[1] == "ins" then
												lastPID = op[4]
												
												local x, y = findCharPositionBefore(op[3], op[4])
												
												if op[2] == "\n" then
													opline = y-1
												else
													opline = y-2
												end
												opcol = x
												
												if op[2] == "\n" then 
													local py, py1 = splitArray(pids[y], x+1)
													pids[y] = py
													table.insert(py1, 1, op[4])
													table.insert(pids, y+1, py1)
												else table.insert(pids[y], x+1, op[4] ) end
												
												if op[2] == "\n" then 
													if y-2 >= 0 then
														local curline = vim.api.nvim_buf_get_lines(buf, y-2, y-1, true)[1]
														local l, r = utf8split(curline, x-1)
														vim.api.nvim_buf_set_lines(buf, y-2, y-1, true, { l, r })
													else
														vim.api.nvim_buf_set_lines(buf, 0, 0, true, { "" })
													end
												else 
													local curline = vim.api.nvim_buf_get_lines(buf, y-2, y-1, true)[1]
													curline = utf8insert(curline, x-1, op[2])
													vim.api.nvim_buf_set_lines(buf, y-2, y-1, true, { curline })
												end
												
												if op[2] == "\n" then 
													if y-1 >= 1 then
														local l, r = utf8split(prev[y-1], x-1)
														prev[y-1] = l
														table.insert(prev, y, r)
													else
														table.insert(prev, y, "")
													end
												else 
													prev[y-1] = utf8insert(prev[y-1], x-1, op[2])
												end
												
												
											elseif op[1] == "del" then
												lastPID = findPIDBefore2(op[2])
												
												local sx, sy = findCharPositionExact(op[2])
												
												if sx then
													if sx == 1 then
														opline = sy-1
													else
														opline = sy-2
													end
													opcol = sx-2
													
													if sx == 1 then
														if sy-3 >= 0 then
															local prevline = vim.api.nvim_buf_get_lines(buf, sy-3, sy-2, true)[1]
															local curline = vim.api.nvim_buf_get_lines(buf, sy-2, sy-1, true)[1]
															vim.api.nvim_buf_set_lines(buf, sy-3, sy-1, true, { prevline .. curline })
														else
															vim.api.nvim_buf_set_lines(buf, sy-2, sy-1, true, {})
														end
													else
														if sy > 1 then
															local curline = vim.api.nvim_buf_get_lines(buf, sy-2, sy-1, true)[1]
															curline = utf8remove(curline, sx-2)
															vim.api.nvim_buf_set_lines(buf, sy-2, sy-1, true, { curline })
														end
													end
													
													if sx == 1 then
														if sy-2 >= 1 then
															prev[sy-2] = prev[sy-2] .. string.sub(prev[sy-1], 1)
														end
														table.remove(prev, sy-1)
													else
														if sy > 1 then
															local curline = prev[sy-1]
															curline = utf8remove(curline, sx-2)
															prev[sy-1] = curline
														end
													end
													
													if sx == 1 then
														for i,pid in ipairs(pids[sy]) do
															if i > 1 then
																table.insert(pids[sy-1], pid)
															end
														end
														table.remove(pids, sy)
													else
														table.remove(pids[sy], sx)
													end
													
												end
												
											end
											allprev[buf] = prev
											allpids[buf] = pids
											
											local aut = decoded["author"]
											if lastPID then
												local x, y = findCharPositionExact(lastPID)
												
												if old_namespace[aut] then
													vim.api.nvim_buf_clear_namespace(
														old_namespace[aut].buf, old_namespace[aut].id,
														0, -1)
													old_namespace[aut] = nil
												end
												
												if cursors[aut] then
													vim.api.nvim_buf_clear_namespace(
														cursors[aut].buf, cursors[aut].id,
														0, -1)
													cursors[aut] = nil
												end
												
												if x then
													if x == 1 then x = 2 end
													old_namespace[aut] = {
														id = vim.api.nvim_buf_set_virtual_text(
															buf, 0, 
															math.max(y-2, 0), 
															{{ aut, vtextGroup }}, 
															{}),
														buf = buf
													}
													
													if prev[y-1] and x-2 >= 0 and x-2 <= utf8len(prev[y-1]) then
														local bx = vim.str_byteindex(prev[y-1], x-2)
														table.insert(events, "cursorGroup " .. cursorGroup)
														cursors[aut] = {
															id = vim.api.nvim_buf_add_highlight(buf,
																0, cursorGroup, y-2, bx, bx+1),
															buf = buf,
															line = y-2,
														}
														if vim.api.nvim_buf_set_extmark then
															cursors[aut].ext_id = 
																vim.api.nvim_buf_set_extmark(
																	buf, cursors[aut].id, y-2, bx, {})
														end
														
													end
													
												end
											end
											
											if #status_cb > 0 then
												local positions = {}
												for aut, c in pairs(cursors) do 
													local buf = c.buf
													local fullname = vim.api.nvim_buf_get_name(buf)
													local cwdname = vim.api.nvim_call_function("fnamemodify",
														{ fullname, ":." })
													local bufname = cwdname
													if bufname == fullname then
														bufname = vim.api.nvim_call_function("fnamemodify",
														{ fullname, ":t" })
													end
													
													local line
													if c.ext_id then
														line,_ = unpack(vim.api.nvim_buf_get_extmark_by_id(
																buf, c.id, c.ext_id, {}))
													else
														line= c.y
													end
													table.insert(positions , {aut, bufname, line})
												end
												
												for _,cb in ipairs(status_cb) do
													cb(positions)
												end
											end
											
											-- @check_if_pid_match_with_prev
										end
										
									end
									
									if decoded["type"] == "request" then
										local encoded
										if not sessionshare then
											local buf = singlebuf
											local rem = { agent, buf }
											local fullname = vim.api.nvim_buf_get_name(buf)
											local cwdname = vim.api.nvim_call_function("fnamemodify",
												{ fullname, ":." })
											local bufname = cwdname
											if bufname == fullname then
												bufname = vim.api.nvim_call_function("fnamemodify",
												{ fullname, ":t" })
											end
											
											local obj = {
												["type"] = "initial",
												["name"] = bufname,
												["bufid"] = rem,
												["pids"] = allpids[buf],
												["content"] = allprev[buf]
											}
											encoded = vim.api.nvim_call_function("json_encode", { obj })
											
											if not encoded then
												print("line number " .. debug.getinfo(1).currentline)
											end
											SendText(encoded)
											-- table.insert(events, "sent " .. encoded)
											
										else
											local allbufs = vim.api.nvim_list_bufs()
											local bufs = {}
											-- skip terminal, help, ... buffers
											for _,buf in ipairs(allbufs) do
												local buftype = vim.api.nvim_buf_get_option(buf, "buftype")
												if buftype == "" then
													table.insert(bufs, buf)
												end
											end
											
											for _,buf in ipairs(bufs) do
												local rem = { agent, buf }
												local fullname = vim.api.nvim_buf_get_name(buf)
												local cwdname = vim.api.nvim_call_function("fnamemodify",
													{ fullname, ":." })
												local bufname = cwdname
												if bufname == fullname then
													bufname = vim.api.nvim_call_function("fnamemodify",
													{ fullname, ":t" })
												end
												
												local obj = {
													["type"] = "initial",
													["name"] = bufname,
													["bufid"] = rem,
													["pids"] = allpids[buf],
													["content"] = allprev[buf]
												}
												encoded = vim.api.nvim_call_function("json_encode", { obj })
												
												if not encoded then
													print("line number " .. debug.getinfo(1).currentline)
												end
												SendText(encoded)
												-- table.insert(events, "sent " .. encoded)
												
											end
										end
									end
									
									if decoded["type"] == "initial" then
										local ag, bufid = unpack(decoded["bufid"])
										if not rem2loc[ag] or not rem2loc[ag][bufid] then
											local buf
											if not sessionshare then
												buf = singlebuf
												if decoded["name"] and string.len(decoded["name"]) > 0 then
													vim.api.nvim_buf_set_name(buf, decoded["name"])
												end
												
											else
												buf = vim.api.nvim_create_buf(true, true)
												
												detach[buf] = nil
												
												ignores[buf] = {}
												
												if not attached[buf] then
													local attach_success = vim.api.nvim_buf_attach(buf, false, {
														on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
															if detach[buf] then
																table.insert(events, "Detached from buffer " .. buf)
																detach[buf] = nil
																return true
															end
															
															if ignores[buf][changedtick] then
																ignores[buf][changedtick] = nil
																return
															end
															
															prev = allprev[buf]
															pids = allpids[buf]
															
															local cur_lines = vim.api.nvim_buf_get_lines(buf, firstline, new_lastline, true)
															
															local add_range = {
																sx = -1,
																sy = firstline,			
																ex = -1, -- at position there is \n
																ey = new_lastline
															}
															
															local del_range = {
																sx = -1,
																sy = firstline,
																ex = -1,
																ey = lastline,
															}
															
															while (add_range.ey > add_range.sy or (add_range.ey == add_range.sy and add_range.ex >= add_range.sx)) and 
																  (del_range.ey > del_range.sy or (del_range.ey == del_range.sy and del_range.ex >= del_range.sx)) do
															
																local c1, c2
																if add_range.ex == -1 then c1 = "\n"
																else c1 = utf8char(cur_lines[add_range.ey-firstline+1] or "", add_range.ex) end
															
																if del_range.ex == -1 then c2 = "\n"
																else c2 = utf8char(prev[del_range.ey+1] or "", del_range.ex) end
															
																if c1 ~= c2 then
																	break
																end
															
																local add_prev, del_prev
																if add_range.ex == -1 then
																	add_prev = { ey = add_range.ey-1, ex = utf8len(cur_lines[add_range.ey-firstline] or "")-1 }
																else
																	add_prev = { ex = add_range.ex-1, ey = add_range.ey }
																end
																
																if del_range.ex == -1 then
																	del_prev = { ey = del_range.ey-1, ex = utf8len(prev[del_range.ey] or "")-1 }
																else
																	del_prev = { ex = del_range.ex-1, ey = del_range.ey }
																end
																
																add_range.ex, add_range.ey = add_prev.ex, add_prev.ey
																del_range.ex, del_range.ey = del_prev.ex, del_prev.ey
																
															end
															
															while (add_range.sy < add_range.ey or (add_range.sy == add_range.ey and add_range.sx <= add_range.ex)) and 
																  (del_range.sy < del_range.ey or (del_range.sy == del_range.ey and del_range.sx <= del_range.ex)) do
															
																local c1, c2
																if add_range.sx == -1 then c1 = "\n"
																else c1 = utf8char(cur_lines[add_range.sy-firstline+1] or "", add_range.sx) end
															
																if del_range.sx == -1 then c2 = "\n"
																else c2 = utf8char(prev[del_range.sy+1] or "", del_range.sx) end
															
																if c1 ~= c2 then
																	break
																end
																add_range.sx = add_range.sx+1
																del_range.sx = del_range.sx+1
																
																if add_range.sx == utf8len(cur_lines[add_range.sy-firstline+1] or "") then
																	add_range.sx = -1
																	add_range.sy = add_range.sy + 1
																end
																
																if del_range.sx == utf8len(prev[del_range.sy+1] or "") then
																	del_range.sx = -1
																	del_range.sy = del_range.sy + 1
																end
																
															end
															
															
															-- @display_xor_ranges
															local endx = del_range.ex
															for y=del_range.ey, del_range.sy,-1 do
																local startx=-1
																if y == del_range.sy then
																	startx = del_range.sx
																end
																
																for x=endx,startx,-1 do
																	if x == -1 then
																		if #prev > 1 then
																			if y > 0 then
																				prev[y] = prev[y] .. (prev[y+1] or "")
																			end
																			table.remove(prev, y+1)
																			
																			local del_pid = pids[y+2][1]
																			for i,pid in ipairs(pids[y+2]) do
																				if i > 1 then
																					table.insert(pids[y+1], pid)
																				end
																			end
																			table.remove(pids, y+2)
																			
																			SendOp(buf, { "del", del_pid })
																			
																		end
																	else
																		prev[y+1] = utf8remove(prev[y+1], x)
																		
																		local del_pid = pids[y+2][x+2]
																		table.remove(pids[y+2], x+2)
																		
																		SendOp(buf, { "del", del_pid })
																		
																	end
																end
																endx = utf8len(prev[y] or "")-1
															end
															
															local startx = add_range.sx
															for y=add_range.sy, add_range.ey do
																local endx
																if y == add_range.ey then
																	endx = add_range.ex
																else
																	endx = utf8len(cur_lines[y-firstline+1])-1
																end
																
																for x=startx,endx do
																	if x == -1 then
																		if cur_lines[y-firstline] then
																			local l, r = utf8split(prev[y], utf8len(cur_lines[y-firstline]))
																			prev[y] = l
																			table.insert(prev, y+1, r)
																		else
																			table.insert(prev, y+1, "")
																		end
																		
																		local pidx
																		if cur_lines[y-firstline] then
																			pidx = utf8len(cur_lines[y-firstline])+1
																		else
																			pidx = #pids[y+1]
																		end
																		
																		local before_pid = pids[y+1][pidx]
																		local after_pid = afterPID(pidx, y+1)
																		local new_pid = genPID(before_pid, after_pid, agent, 1)
																		
																		local l, r = splitArray(pids[y+1], pidx+1)
																		pids[y+1] = l
																		table.insert(r, 1, new_pid)
																		table.insert(pids, y+2, r)
																		
																		SendOp(buf, { "ins", "\n", before_pid, new_pid })
																		
																	else
																		local c = utf8char(cur_lines[y-firstline+1], x)
																		prev[y+1] = utf8insert(prev[y+1], x, c)
																		
																		local before_pid = pids[y+2][x+1]
																		local after_pid = afterPID(x+1, y+2)
																		local new_pid = genPID(before_pid, after_pid, agent, 1)
																		
																		table.insert(pids[y+2], x+2, new_pid)
																		
																		SendOp(buf, { "ins", c, before_pid, new_pid })
																		
																	end
																end
																startx = -1
															end
															
															allprev[buf] = prev
															allpids[buf] = pids
															
														end,
														on_detach = function(_, buf)
															table.insert(events, "detached " .. buf)
															attached[buf] = nil
														end
													})
												
													if attach_success then
														table.insert(events, "has_attached[" .. buf .. "] = true")
														attached[buf] = true
													end
												else
													detach[buf] = nil
												end
												
												
												
												if decoded["name"] and string.len(decoded["name"]) > 0 then
													vim.api.nvim_buf_set_name(buf, decoded["name"])
												end
												
												if vim.api.nvim_buf_call then
													vim.api.nvim_buf_call(buf, function()
														vim.api.nvim_command("filetype detect")
													end)
												end
												
												vim.api.nvim_buf_set_option(buf, "buftype", "")
												
											end
									
											local ag, bufid = unpack(decoded["bufid"])
											if not rem2loc[ag] then
												rem2loc[ag] = {}
											end
											
											rem2loc[ag][bufid] = buf
											loc2rem[buf] = { ag, bufid }
											
									
											prev = decoded["content"]
											
											pids = decoded["pids"]
											
									
											local tick = vim.api.nvim_buf_get_changedtick(buf)+1
											ignores[buf][tick] = true
											
											vim.api.nvim_buf_set_lines(
												buf,
												0, -1, false, decoded["content"])
											
											allprev[buf] = prev
											allpids[buf] = pids
											
										else
											local buf = rem2loc[ag][bufid]
									
											prev = decoded["content"]
											
											pids = decoded["pids"]
											
									
											local tick = vim.api.nvim_buf_get_changedtick(buf)+1
											ignores[buf][tick] = true
											
											vim.api.nvim_buf_set_lines(
												buf,
												0, -1, false, decoded["content"])
											
											allprev[buf] = prev
											allpids[buf] = pids
											
									
											if decoded["name"] and string.len(decoded["name"]) > 0 then
												vim.api.nvim_buf_set_name(buf, decoded["name"])
											end
											
											if vim.api.nvim_buf_call then
												vim.api.nvim_buf_call(buf, function()
													vim.api.nvim_command("filetype detect")
												end)
											end
											
										end
									end
									
									if decoded["type"] == "response" then
										if decoded["is_first"] and first then
											agent = decoded["client_id"]
											
											local obj = {
												["type"] = "info",
												["sessionshare"] = sessionshare,
												["author"] = author,
											}
											local encoded = vim.api.nvim_call_function("json_encode", { obj })
											if not encoded then
												print("line number " .. debug.getinfo(1).currentline)
											end
											SendText(encoded)
											-- table.insert(events, "sent " .. encoded)
											
											
											print("Connected!")
									
											if sessionshare then
												local allbufs = vim.api.nvim_list_bufs()
												local bufs = {}
												-- skip terminal, help, ... buffers
												for _,buf in ipairs(allbufs) do
													local buftype = vim.api.nvim_buf_get_option(buf, "buftype")
													if buftype == "" then
														table.insert(bufs, buf)
													end
												end
												
												for _, buf in ipairs(bufs) do
													detach[buf] = nil
													
													ignores[buf] = {}
													
													if not attached[buf] then
														local attach_success = vim.api.nvim_buf_attach(buf, false, {
															on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
																if detach[buf] then
																	table.insert(events, "Detached from buffer " .. buf)
																	detach[buf] = nil
																	return true
																end
																
																if ignores[buf][changedtick] then
																	ignores[buf][changedtick] = nil
																	return
																end
																
																prev = allprev[buf]
																pids = allpids[buf]
																
																local cur_lines = vim.api.nvim_buf_get_lines(buf, firstline, new_lastline, true)
																
																local add_range = {
																	sx = -1,
																	sy = firstline,			
																	ex = -1, -- at position there is \n
																	ey = new_lastline
																}
																
																local del_range = {
																	sx = -1,
																	sy = firstline,
																	ex = -1,
																	ey = lastline,
																}
																
																while (add_range.ey > add_range.sy or (add_range.ey == add_range.sy and add_range.ex >= add_range.sx)) and 
																	  (del_range.ey > del_range.sy or (del_range.ey == del_range.sy and del_range.ex >= del_range.sx)) do
																
																	local c1, c2
																	if add_range.ex == -1 then c1 = "\n"
																	else c1 = utf8char(cur_lines[add_range.ey-firstline+1] or "", add_range.ex) end
																
																	if del_range.ex == -1 then c2 = "\n"
																	else c2 = utf8char(prev[del_range.ey+1] or "", del_range.ex) end
																
																	if c1 ~= c2 then
																		break
																	end
																
																	local add_prev, del_prev
																	if add_range.ex == -1 then
																		add_prev = { ey = add_range.ey-1, ex = utf8len(cur_lines[add_range.ey-firstline] or "")-1 }
																	else
																		add_prev = { ex = add_range.ex-1, ey = add_range.ey }
																	end
																	
																	if del_range.ex == -1 then
																		del_prev = { ey = del_range.ey-1, ex = utf8len(prev[del_range.ey] or "")-1 }
																	else
																		del_prev = { ex = del_range.ex-1, ey = del_range.ey }
																	end
																	
																	add_range.ex, add_range.ey = add_prev.ex, add_prev.ey
																	del_range.ex, del_range.ey = del_prev.ex, del_prev.ey
																	
																end
																
																while (add_range.sy < add_range.ey or (add_range.sy == add_range.ey and add_range.sx <= add_range.ex)) and 
																	  (del_range.sy < del_range.ey or (del_range.sy == del_range.ey and del_range.sx <= del_range.ex)) do
																
																	local c1, c2
																	if add_range.sx == -1 then c1 = "\n"
																	else c1 = utf8char(cur_lines[add_range.sy-firstline+1] or "", add_range.sx) end
																
																	if del_range.sx == -1 then c2 = "\n"
																	else c2 = utf8char(prev[del_range.sy+1] or "", del_range.sx) end
																
																	if c1 ~= c2 then
																		break
																	end
																	add_range.sx = add_range.sx+1
																	del_range.sx = del_range.sx+1
																	
																	if add_range.sx == utf8len(cur_lines[add_range.sy-firstline+1] or "") then
																		add_range.sx = -1
																		add_range.sy = add_range.sy + 1
																	end
																	
																	if del_range.sx == utf8len(prev[del_range.sy+1] or "") then
																		del_range.sx = -1
																		del_range.sy = del_range.sy + 1
																	end
																	
																end
																
																
																-- @display_xor_ranges
																local endx = del_range.ex
																for y=del_range.ey, del_range.sy,-1 do
																	local startx=-1
																	if y == del_range.sy then
																		startx = del_range.sx
																	end
																	
																	for x=endx,startx,-1 do
																		if x == -1 then
																			if #prev > 1 then
																				if y > 0 then
																					prev[y] = prev[y] .. (prev[y+1] or "")
																				end
																				table.remove(prev, y+1)
																				
																				local del_pid = pids[y+2][1]
																				for i,pid in ipairs(pids[y+2]) do
																					if i > 1 then
																						table.insert(pids[y+1], pid)
																					end
																				end
																				table.remove(pids, y+2)
																				
																				SendOp(buf, { "del", del_pid })
																				
																			end
																		else
																			prev[y+1] = utf8remove(prev[y+1], x)
																			
																			local del_pid = pids[y+2][x+2]
																			table.remove(pids[y+2], x+2)
																			
																			SendOp(buf, { "del", del_pid })
																			
																		end
																	end
																	endx = utf8len(prev[y] or "")-1
																end
																
																local startx = add_range.sx
																for y=add_range.sy, add_range.ey do
																	local endx
																	if y == add_range.ey then
																		endx = add_range.ex
																	else
																		endx = utf8len(cur_lines[y-firstline+1])-1
																	end
																	
																	for x=startx,endx do
																		if x == -1 then
																			if cur_lines[y-firstline] then
																				local l, r = utf8split(prev[y], utf8len(cur_lines[y-firstline]))
																				prev[y] = l
																				table.insert(prev, y+1, r)
																			else
																				table.insert(prev, y+1, "")
																			end
																			
																			local pidx
																			if cur_lines[y-firstline] then
																				pidx = utf8len(cur_lines[y-firstline])+1
																			else
																				pidx = #pids[y+1]
																			end
																			
																			local before_pid = pids[y+1][pidx]
																			local after_pid = afterPID(pidx, y+1)
																			local new_pid = genPID(before_pid, after_pid, agent, 1)
																			
																			local l, r = splitArray(pids[y+1], pidx+1)
																			pids[y+1] = l
																			table.insert(r, 1, new_pid)
																			table.insert(pids, y+2, r)
																			
																			SendOp(buf, { "ins", "\n", before_pid, new_pid })
																			
																		else
																			local c = utf8char(cur_lines[y-firstline+1], x)
																			prev[y+1] = utf8insert(prev[y+1], x, c)
																			
																			local before_pid = pids[y+2][x+1]
																			local after_pid = afterPID(x+1, y+2)
																			local new_pid = genPID(before_pid, after_pid, agent, 1)
																			
																			table.insert(pids[y+2], x+2, new_pid)
																			
																			SendOp(buf, { "ins", c, before_pid, new_pid })
																			
																		end
																	end
																	startx = -1
																end
																
																allprev[buf] = prev
																allpids[buf] = pids
																
															end,
															on_detach = function(_, buf)
																table.insert(events, "detached " .. buf)
																attached[buf] = nil
															end
														})
													
														if attach_success then
															table.insert(events, "has_attached[" .. buf .. "] = true")
															attached[buf] = true
														end
													else
														detach[buf] = nil
													end
													
													
													
												end
												
												for _, buf in ipairs(bufs) do
													local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
													
													local middlepos = genPID(startpos, endpos, agent, 1)
													pids = {
														{ startpos },
														{ middlepos },
														{ endpos },
													}
													
													local bpid = pids[2][1] -- middlepos
													local epid = pids[3][1] -- endpos
													
													for i=1,#lines do
														local line = lines[i]
														if i > 1 then
															local newpid = genPID(bpid, epid, agent, 1)
															bpid = newpid
															
															table.insert(pids, i+1, { newpid })
															
															-- For testing purposes
															-- @script_variables+=
															-- local typeset = {}
															-- 
															-- @init_typeset+=
															-- for i=string.byte('a'),string.byte('z') do
															-- 	table.insert(typeset, string.char(i))
															-- end
															-- 
															-- for i=string.byte('A'),string.byte('Z') do
															-- 	table.insert(typeset, string.char(i))
															-- end
															-- 
															-- for i=string.byte('0'),string.byte('9') do
															-- 	table.insert(typeset, string.char(i))
															-- end
															-- 
															-- @type_random_function+=
															-- function TypeRandom(limit, ms)
															-- 	ms = ms or 50
															-- 	local timer = vim.loop.new_timer()
															-- 	local i = 0
															-- 	timer:start(300, ms, function()
															-- 		vim.schedule(function()
															-- 			if math.random() < 0.7 or vim.api.nvim_buf_line_count(0) < 2 then
															-- 				if math.random() < 0.1 then
															-- 					@pick_random_line
															-- 					@insert_new_line
															-- 				elseif math.random() < 0.1 then
															-- 					@pick_random_line
															-- 					@split_line_into_two_lines
															-- 				else
															-- 					@pick_random_line
															-- 					@pick_random_position_in_line
															-- 					@pick_random_character
															-- 					@insert_character
															-- 				end
															-- 			elseif math.random() < 0.9 then
															-- 				if math.random() < 0.1 then
															-- 					@pick_random_line
															-- 					@delete_line
															-- 				elseif math.random() < 0.1 then
															-- 					@pick_random_line
															-- 					@concat_line
															-- 				else
															-- 					@pick_random_line
															-- 					@pick_random_position_in_line
															-- 					@delete_character
															-- 				end
															-- 			else
															-- 				@pick_random_line
															-- 				@replace_with_random_line
															-- 			end
															-- 		end)
															-- 		if i > limit then timer:close() end
															-- 		i = i + 1
															-- 	end)
															-- end
															-- 
															-- @pick_random_line+=
															-- local lcount = vim.api.nvim_buf_line_count(0)
															-- local lnum = math.random(0, lcount-1) -- # zero indexed
															-- 
															-- @insert_new_line+=
															-- vim.api.nvim_buf_set_lines(0, lnum, lnum, true, { "" }) 
															-- 
															-- @pick_random_position_in_line+=
															-- local curline = vim.api.nvim_buf_get_lines(0, lnum, lnum+1, true)[1]
															-- local cnum = math.random(1, string.len(curline))
															-- 
															-- @pick_random_character+=
															-- local c = typeset[math.floor(math.random()*(#typeset-1)+0.5)+1]
															-- 
															-- @insert_character+=
															-- curline = string.sub(curline, 1, cnum-1) .. c .. string.sub(curline, cnum)
															-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, { curline }) 
															-- 
															-- @delete_line+=
															-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, {})
															-- 
															-- @delete_character+=
															-- curline = string.sub(curline, 1, cnum-1) .. string.sub(curline, cnum+1)
															-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, { curline }) 
															-- 
															-- @split_line_into_two_lines+=
															-- local curline = vim.api.nvim_buf_get_lines(0, lnum, lnum+1, true)[1]
															-- local cnum = math.random(0, string.len(curline)-1) 
															-- local r, l = utf8split(curline, cnum)
															-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, { r, l }) 
															-- 
															-- @concat_line+=
															-- if lnum < lcount-1 then 
															-- 	local c = vim.api.nvim_buf_get_lines(0, lnum, lnum+2, true)
															-- 	vim.api.nvim_buf_set_lines(0, lnum, lnum+2, true, { c[1] .. c[2] })
															-- end
															-- 
															-- @replace_with_random_line+=
															-- local lnewcount = math.random(1,20)
															-- local newline = ""
															-- for i=1,lnewcount do
															-- 	@pick_random_character
															-- 	newline = newline .. c
															-- end
															-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, { newline })
															-- 
															-- @display_xor_ranges+=
															-- table.insert(events, "add range " .. vim.inspect(add_range))
															-- table.insert(events, "del range " .. vim.inspect(del_range))
															-- 
															-- @check_if_pid_match_with_prev+=
															-- for i=1,#pids do
															-- 	local exp
															-- 	if i == 1 or i == #pids then
															-- 		exp = 1
															-- 	else
															-- 		exp = #prev[i-1] + 1
															-- 	end
															-- 	local res = #pids[i]
															-- 	if exp ~= res then
															-- 		table.insert(events, exp .. " " .. res .. " NG\n")
															-- 	end
															-- end
															-- 
															-- @display_states+=
															-- for i,lpid in ipairs(pids) do
															-- 	table.insert(events, i .. ": " .. vim.inspect(lpid))
															-- end
															-- for i,line in ipairs(prev) do
															-- 	table.insert(events, i .. ": " .. vim.inspect(line))
															-- end
															-- local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
															-- for i,line in ipairs(all_lines) do
															-- 	if prev[i] ~= line then
															-- 		table.insert(events, "DISC")
															-- 	end
															-- 	table.insert(events, i .. "> " .. vim.inspect(line))
															-- end
															
														end
													
														for j=1,string.len(line) do
															local newpid = genPID(bpid, epid, agent, 1)
															bpid = newpid
															
															table.insert(pids[i+1], newpid)
															
														end
													
													end
													
													prev = lines
													
													allprev[buf] = prev
													allpids[buf] = pids
													
													if not rem2loc[agent] then
														rem2loc[agent] = {}
													end
													
													rem2loc[agent][buf] = buf
													loc2rem[buf] = { agent, buf }
													
												end
												
											else
												local buf = singlebuf
									
												detach[buf] = nil
												
												ignores[buf] = {}
												
												if not attached[buf] then
													local attach_success = vim.api.nvim_buf_attach(buf, false, {
														on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
															if detach[buf] then
																table.insert(events, "Detached from buffer " .. buf)
																detach[buf] = nil
																return true
															end
															
															if ignores[buf][changedtick] then
																ignores[buf][changedtick] = nil
																return
															end
															
															prev = allprev[buf]
															pids = allpids[buf]
															
															local cur_lines = vim.api.nvim_buf_get_lines(buf, firstline, new_lastline, true)
															
															local add_range = {
																sx = -1,
																sy = firstline,			
																ex = -1, -- at position there is \n
																ey = new_lastline
															}
															
															local del_range = {
																sx = -1,
																sy = firstline,
																ex = -1,
																ey = lastline,
															}
															
															while (add_range.ey > add_range.sy or (add_range.ey == add_range.sy and add_range.ex >= add_range.sx)) and 
																  (del_range.ey > del_range.sy or (del_range.ey == del_range.sy and del_range.ex >= del_range.sx)) do
															
																local c1, c2
																if add_range.ex == -1 then c1 = "\n"
																else c1 = utf8char(cur_lines[add_range.ey-firstline+1] or "", add_range.ex) end
															
																if del_range.ex == -1 then c2 = "\n"
																else c2 = utf8char(prev[del_range.ey+1] or "", del_range.ex) end
															
																if c1 ~= c2 then
																	break
																end
															
																local add_prev, del_prev
																if add_range.ex == -1 then
																	add_prev = { ey = add_range.ey-1, ex = utf8len(cur_lines[add_range.ey-firstline] or "")-1 }
																else
																	add_prev = { ex = add_range.ex-1, ey = add_range.ey }
																end
																
																if del_range.ex == -1 then
																	del_prev = { ey = del_range.ey-1, ex = utf8len(prev[del_range.ey] or "")-1 }
																else
																	del_prev = { ex = del_range.ex-1, ey = del_range.ey }
																end
																
																add_range.ex, add_range.ey = add_prev.ex, add_prev.ey
																del_range.ex, del_range.ey = del_prev.ex, del_prev.ey
																
															end
															
															while (add_range.sy < add_range.ey or (add_range.sy == add_range.ey and add_range.sx <= add_range.ex)) and 
																  (del_range.sy < del_range.ey or (del_range.sy == del_range.ey and del_range.sx <= del_range.ex)) do
															
																local c1, c2
																if add_range.sx == -1 then c1 = "\n"
																else c1 = utf8char(cur_lines[add_range.sy-firstline+1] or "", add_range.sx) end
															
																if del_range.sx == -1 then c2 = "\n"
																else c2 = utf8char(prev[del_range.sy+1] or "", del_range.sx) end
															
																if c1 ~= c2 then
																	break
																end
																add_range.sx = add_range.sx+1
																del_range.sx = del_range.sx+1
																
																if add_range.sx == utf8len(cur_lines[add_range.sy-firstline+1] or "") then
																	add_range.sx = -1
																	add_range.sy = add_range.sy + 1
																end
																
																if del_range.sx == utf8len(prev[del_range.sy+1] or "") then
																	del_range.sx = -1
																	del_range.sy = del_range.sy + 1
																end
																
															end
															
															
															-- @display_xor_ranges
															local endx = del_range.ex
															for y=del_range.ey, del_range.sy,-1 do
																local startx=-1
																if y == del_range.sy then
																	startx = del_range.sx
																end
																
																for x=endx,startx,-1 do
																	if x == -1 then
																		if #prev > 1 then
																			if y > 0 then
																				prev[y] = prev[y] .. (prev[y+1] or "")
																			end
																			table.remove(prev, y+1)
																			
																			local del_pid = pids[y+2][1]
																			for i,pid in ipairs(pids[y+2]) do
																				if i > 1 then
																					table.insert(pids[y+1], pid)
																				end
																			end
																			table.remove(pids, y+2)
																			
																			SendOp(buf, { "del", del_pid })
																			
																		end
																	else
																		prev[y+1] = utf8remove(prev[y+1], x)
																		
																		local del_pid = pids[y+2][x+2]
																		table.remove(pids[y+2], x+2)
																		
																		SendOp(buf, { "del", del_pid })
																		
																	end
																end
																endx = utf8len(prev[y] or "")-1
															end
															
															local startx = add_range.sx
															for y=add_range.sy, add_range.ey do
																local endx
																if y == add_range.ey then
																	endx = add_range.ex
																else
																	endx = utf8len(cur_lines[y-firstline+1])-1
																end
																
																for x=startx,endx do
																	if x == -1 then
																		if cur_lines[y-firstline] then
																			local l, r = utf8split(prev[y], utf8len(cur_lines[y-firstline]))
																			prev[y] = l
																			table.insert(prev, y+1, r)
																		else
																			table.insert(prev, y+1, "")
																		end
																		
																		local pidx
																		if cur_lines[y-firstline] then
																			pidx = utf8len(cur_lines[y-firstline])+1
																		else
																			pidx = #pids[y+1]
																		end
																		
																		local before_pid = pids[y+1][pidx]
																		local after_pid = afterPID(pidx, y+1)
																		local new_pid = genPID(before_pid, after_pid, agent, 1)
																		
																		local l, r = splitArray(pids[y+1], pidx+1)
																		pids[y+1] = l
																		table.insert(r, 1, new_pid)
																		table.insert(pids, y+2, r)
																		
																		SendOp(buf, { "ins", "\n", before_pid, new_pid })
																		
																	else
																		local c = utf8char(cur_lines[y-firstline+1], x)
																		prev[y+1] = utf8insert(prev[y+1], x, c)
																		
																		local before_pid = pids[y+2][x+1]
																		local after_pid = afterPID(x+1, y+2)
																		local new_pid = genPID(before_pid, after_pid, agent, 1)
																		
																		table.insert(pids[y+2], x+2, new_pid)
																		
																		SendOp(buf, { "ins", c, before_pid, new_pid })
																		
																	end
																end
																startx = -1
															end
															
															allprev[buf] = prev
															allpids[buf] = pids
															
														end,
														on_detach = function(_, buf)
															table.insert(events, "detached " .. buf)
															attached[buf] = nil
														end
													})
												
													if attach_success then
														table.insert(events, "has_attached[" .. buf .. "] = true")
														attached[buf] = true
													end
												else
													detach[buf] = nil
												end
												
												
												
									
												local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
												
												local middlepos = genPID(startpos, endpos, agent, 1)
												pids = {
													{ startpos },
													{ middlepos },
													{ endpos },
												}
												
												local bpid = pids[2][1] -- middlepos
												local epid = pids[3][1] -- endpos
												
												for i=1,#lines do
													local line = lines[i]
													if i > 1 then
														local newpid = genPID(bpid, epid, agent, 1)
														bpid = newpid
														
														table.insert(pids, i+1, { newpid })
														
														-- For testing purposes
														-- @script_variables+=
														-- local typeset = {}
														-- 
														-- @init_typeset+=
														-- for i=string.byte('a'),string.byte('z') do
														-- 	table.insert(typeset, string.char(i))
														-- end
														-- 
														-- for i=string.byte('A'),string.byte('Z') do
														-- 	table.insert(typeset, string.char(i))
														-- end
														-- 
														-- for i=string.byte('0'),string.byte('9') do
														-- 	table.insert(typeset, string.char(i))
														-- end
														-- 
														-- @type_random_function+=
														-- function TypeRandom(limit, ms)
														-- 	ms = ms or 50
														-- 	local timer = vim.loop.new_timer()
														-- 	local i = 0
														-- 	timer:start(300, ms, function()
														-- 		vim.schedule(function()
														-- 			if math.random() < 0.7 or vim.api.nvim_buf_line_count(0) < 2 then
														-- 				if math.random() < 0.1 then
														-- 					@pick_random_line
														-- 					@insert_new_line
														-- 				elseif math.random() < 0.1 then
														-- 					@pick_random_line
														-- 					@split_line_into_two_lines
														-- 				else
														-- 					@pick_random_line
														-- 					@pick_random_position_in_line
														-- 					@pick_random_character
														-- 					@insert_character
														-- 				end
														-- 			elseif math.random() < 0.9 then
														-- 				if math.random() < 0.1 then
														-- 					@pick_random_line
														-- 					@delete_line
														-- 				elseif math.random() < 0.1 then
														-- 					@pick_random_line
														-- 					@concat_line
														-- 				else
														-- 					@pick_random_line
														-- 					@pick_random_position_in_line
														-- 					@delete_character
														-- 				end
														-- 			else
														-- 				@pick_random_line
														-- 				@replace_with_random_line
														-- 			end
														-- 		end)
														-- 		if i > limit then timer:close() end
														-- 		i = i + 1
														-- 	end)
														-- end
														-- 
														-- @pick_random_line+=
														-- local lcount = vim.api.nvim_buf_line_count(0)
														-- local lnum = math.random(0, lcount-1) -- # zero indexed
														-- 
														-- @insert_new_line+=
														-- vim.api.nvim_buf_set_lines(0, lnum, lnum, true, { "" }) 
														-- 
														-- @pick_random_position_in_line+=
														-- local curline = vim.api.nvim_buf_get_lines(0, lnum, lnum+1, true)[1]
														-- local cnum = math.random(1, string.len(curline))
														-- 
														-- @pick_random_character+=
														-- local c = typeset[math.floor(math.random()*(#typeset-1)+0.5)+1]
														-- 
														-- @insert_character+=
														-- curline = string.sub(curline, 1, cnum-1) .. c .. string.sub(curline, cnum)
														-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, { curline }) 
														-- 
														-- @delete_line+=
														-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, {})
														-- 
														-- @delete_character+=
														-- curline = string.sub(curline, 1, cnum-1) .. string.sub(curline, cnum+1)
														-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, { curline }) 
														-- 
														-- @split_line_into_two_lines+=
														-- local curline = vim.api.nvim_buf_get_lines(0, lnum, lnum+1, true)[1]
														-- local cnum = math.random(0, string.len(curline)-1) 
														-- local r, l = utf8split(curline, cnum)
														-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, { r, l }) 
														-- 
														-- @concat_line+=
														-- if lnum < lcount-1 then 
														-- 	local c = vim.api.nvim_buf_get_lines(0, lnum, lnum+2, true)
														-- 	vim.api.nvim_buf_set_lines(0, lnum, lnum+2, true, { c[1] .. c[2] })
														-- end
														-- 
														-- @replace_with_random_line+=
														-- local lnewcount = math.random(1,20)
														-- local newline = ""
														-- for i=1,lnewcount do
														-- 	@pick_random_character
														-- 	newline = newline .. c
														-- end
														-- vim.api.nvim_buf_set_lines(0, lnum, lnum+1, true, { newline })
														-- 
														-- @display_xor_ranges+=
														-- table.insert(events, "add range " .. vim.inspect(add_range))
														-- table.insert(events, "del range " .. vim.inspect(del_range))
														-- 
														-- @check_if_pid_match_with_prev+=
														-- for i=1,#pids do
														-- 	local exp
														-- 	if i == 1 or i == #pids then
														-- 		exp = 1
														-- 	else
														-- 		exp = #prev[i-1] + 1
														-- 	end
														-- 	local res = #pids[i]
														-- 	if exp ~= res then
														-- 		table.insert(events, exp .. " " .. res .. " NG\n")
														-- 	end
														-- end
														-- 
														-- @display_states+=
														-- for i,lpid in ipairs(pids) do
														-- 	table.insert(events, i .. ": " .. vim.inspect(lpid))
														-- end
														-- for i,line in ipairs(prev) do
														-- 	table.insert(events, i .. ": " .. vim.inspect(line))
														-- end
														-- local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
														-- for i,line in ipairs(all_lines) do
														-- 	if prev[i] ~= line then
														-- 		table.insert(events, "DISC")
														-- 	end
														-- 	table.insert(events, i .. "> " .. vim.inspect(line))
														-- end
														
													end
												
													for j=1,string.len(line) do
														local newpid = genPID(bpid, epid, agent, 1)
														bpid = newpid
														
														table.insert(pids[i+1], newpid)
														
													end
												
												end
												
												prev = lines
												
												allprev[buf] = prev
												allpids[buf] = pids
												
									
											end
									
											vimcmd("augroup instantSession")
											vimcmd("autocmd!")
											-- this is kind of messy
											-- a better way to write this
											-- would be great
											vimcmd("autocmd BufNewFile,BufRead * call execute('lua instantOpenOrCreateBuffer(' . expand('<abuf>') . ')', '')")
											vimcmd("augroup end")
											
										elseif not decoded["is_first"] and not first then
											if decoded["sessionshare"] ~= sessionshare then
												print("ERROR: Share mode client server mismatch (session mode, single buffer mode)")
												for bufhandle,_ in pairs(allprev) do
													if vim.api.nvim_buf_is_loaded(bufhandle) then
														DetachFromBuffer(bufhandle)
													end
												end
												StopClient()
												
												
												for aut,_ in pairs(cursors) do
													if cursors[aut] then
														vim.api.nvim_buf_clear_namespace(
															cursors[aut].buf, cursors[aut].id,
															0, -1)
														cursors[aut] = nil
													end
													
													if old_namespace[aut] then
														vim.api.nvim_buf_clear_namespace(
															old_namespace[aut].buf, old_namespace[aut].id,
															0, -1)
														old_namespace[aut] = nil
													end
													
												end
												cursors = {}
												
												vimcmd("augroup instantSession")
												vimcmd("autocmd!")
												vimcmd("augroup end")
												
												
											else
												agent = decoded["client_id"]
												
												local obj = {
													["type"] = "info",
													["sessionshare"] = sessionshare,
													["author"] = author,
												}
												local encoded = vim.api.nvim_call_function("json_encode", { obj })
												if not encoded then
													print("line number " .. debug.getinfo(1).currentline)
												end
												SendText(encoded)
												-- table.insert(events, "sent " .. encoded)
												
												
									
												if not sessionshare then
													local buf = singlebuf
									
													detach[buf] = nil
													
													ignores[buf] = {}
													
													if not attached[buf] then
														local attach_success = vim.api.nvim_buf_attach(buf, false, {
															on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
																if detach[buf] then
																	table.insert(events, "Detached from buffer " .. buf)
																	detach[buf] = nil
																	return true
																end
																
																if ignores[buf][changedtick] then
																	ignores[buf][changedtick] = nil
																	return
																end
																
																prev = allprev[buf]
																pids = allpids[buf]
																
																local cur_lines = vim.api.nvim_buf_get_lines(buf, firstline, new_lastline, true)
																
																local add_range = {
																	sx = -1,
																	sy = firstline,			
																	ex = -1, -- at position there is \n
																	ey = new_lastline
																}
																
																local del_range = {
																	sx = -1,
																	sy = firstline,
																	ex = -1,
																	ey = lastline,
																}
																
																while (add_range.ey > add_range.sy or (add_range.ey == add_range.sy and add_range.ex >= add_range.sx)) and 
																	  (del_range.ey > del_range.sy or (del_range.ey == del_range.sy and del_range.ex >= del_range.sx)) do
																
																	local c1, c2
																	if add_range.ex == -1 then c1 = "\n"
																	else c1 = utf8char(cur_lines[add_range.ey-firstline+1] or "", add_range.ex) end
																
																	if del_range.ex == -1 then c2 = "\n"
																	else c2 = utf8char(prev[del_range.ey+1] or "", del_range.ex) end
																
																	if c1 ~= c2 then
																		break
																	end
																
																	local add_prev, del_prev
																	if add_range.ex == -1 then
																		add_prev = { ey = add_range.ey-1, ex = utf8len(cur_lines[add_range.ey-firstline] or "")-1 }
																	else
																		add_prev = { ex = add_range.ex-1, ey = add_range.ey }
																	end
																	
																	if del_range.ex == -1 then
																		del_prev = { ey = del_range.ey-1, ex = utf8len(prev[del_range.ey] or "")-1 }
																	else
																		del_prev = { ex = del_range.ex-1, ey = del_range.ey }
																	end
																	
																	add_range.ex, add_range.ey = add_prev.ex, add_prev.ey
																	del_range.ex, del_range.ey = del_prev.ex, del_prev.ey
																	
																end
																
																while (add_range.sy < add_range.ey or (add_range.sy == add_range.ey and add_range.sx <= add_range.ex)) and 
																	  (del_range.sy < del_range.ey or (del_range.sy == del_range.ey and del_range.sx <= del_range.ex)) do
																
																	local c1, c2
																	if add_range.sx == -1 then c1 = "\n"
																	else c1 = utf8char(cur_lines[add_range.sy-firstline+1] or "", add_range.sx) end
																
																	if del_range.sx == -1 then c2 = "\n"
																	else c2 = utf8char(prev[del_range.sy+1] or "", del_range.sx) end
																
																	if c1 ~= c2 then
																		break
																	end
																	add_range.sx = add_range.sx+1
																	del_range.sx = del_range.sx+1
																	
																	if add_range.sx == utf8len(cur_lines[add_range.sy-firstline+1] or "") then
																		add_range.sx = -1
																		add_range.sy = add_range.sy + 1
																	end
																	
																	if del_range.sx == utf8len(prev[del_range.sy+1] or "") then
																		del_range.sx = -1
																		del_range.sy = del_range.sy + 1
																	end
																	
																end
																
																
																-- @display_xor_ranges
																local endx = del_range.ex
																for y=del_range.ey, del_range.sy,-1 do
																	local startx=-1
																	if y == del_range.sy then
																		startx = del_range.sx
																	end
																	
																	for x=endx,startx,-1 do
																		if x == -1 then
																			if #prev > 1 then
																				if y > 0 then
																					prev[y] = prev[y] .. (prev[y+1] or "")
																				end
																				table.remove(prev, y+1)
																				
																				local del_pid = pids[y+2][1]
																				for i,pid in ipairs(pids[y+2]) do
																					if i > 1 then
																						table.insert(pids[y+1], pid)
																					end
																				end
																				table.remove(pids, y+2)
																				
																				SendOp(buf, { "del", del_pid })
																				
																			end
																		else
																			prev[y+1] = utf8remove(prev[y+1], x)
																			
																			local del_pid = pids[y+2][x+2]
																			table.remove(pids[y+2], x+2)
																			
																			SendOp(buf, { "del", del_pid })
																			
																		end
																	end
																	endx = utf8len(prev[y] or "")-1
																end
																
																local startx = add_range.sx
																for y=add_range.sy, add_range.ey do
																	local endx
																	if y == add_range.ey then
																		endx = add_range.ex
																	else
																		endx = utf8len(cur_lines[y-firstline+1])-1
																	end
																	
																	for x=startx,endx do
																		if x == -1 then
																			if cur_lines[y-firstline] then
																				local l, r = utf8split(prev[y], utf8len(cur_lines[y-firstline]))
																				prev[y] = l
																				table.insert(prev, y+1, r)
																			else
																				table.insert(prev, y+1, "")
																			end
																			
																			local pidx
																			if cur_lines[y-firstline] then
																				pidx = utf8len(cur_lines[y-firstline])+1
																			else
																				pidx = #pids[y+1]
																			end
																			
																			local before_pid = pids[y+1][pidx]
																			local after_pid = afterPID(pidx, y+1)
																			local new_pid = genPID(before_pid, after_pid, agent, 1)
																			
																			local l, r = splitArray(pids[y+1], pidx+1)
																			pids[y+1] = l
																			table.insert(r, 1, new_pid)
																			table.insert(pids, y+2, r)
																			
																			SendOp(buf, { "ins", "\n", before_pid, new_pid })
																			
																		else
																			local c = utf8char(cur_lines[y-firstline+1], x)
																			prev[y+1] = utf8insert(prev[y+1], x, c)
																			
																			local before_pid = pids[y+2][x+1]
																			local after_pid = afterPID(x+1, y+2)
																			local new_pid = genPID(before_pid, after_pid, agent, 1)
																			
																			table.insert(pids[y+2], x+2, new_pid)
																			
																			SendOp(buf, { "ins", c, before_pid, new_pid })
																			
																		end
																	end
																	startx = -1
																end
																
																allprev[buf] = prev
																allpids[buf] = pids
																
															end,
															on_detach = function(_, buf)
																table.insert(events, "detached " .. buf)
																attached[buf] = nil
															end
														})
													
														if attach_success then
															table.insert(events, "has_attached[" .. buf .. "] = true")
															attached[buf] = true
														end
													else
														detach[buf] = nil
													end
													
													
													
												end
												local obj = {
													["type"] = "request",
												}
												local encoded = vim.api.nvim_call_function("json_encode", { obj })
												if not encoded then
													print("line number " .. debug.getinfo(1).currentline)
												end
												SendText(encoded)
												-- table.insert(events, "sent " .. encoded)
												
												
												print("Connected!")
											end
										elseif decoded["is_first"] and not first then
											table.insert(events, "ERROR: Tried to join an empty server")
											print("ERROR: Tried to join an empty server")
											for bufhandle,_ in pairs(allprev) do
												if vim.api.nvim_buf_is_loaded(bufhandle) then
													DetachFromBuffer(bufhandle)
												end
											end
											StopClient()
											
											
											for aut,_ in pairs(cursors) do
												if cursors[aut] then
													vim.api.nvim_buf_clear_namespace(
														cursors[aut].buf, cursors[aut].id,
														0, -1)
													cursors[aut] = nil
												end
												
												if old_namespace[aut] then
													vim.api.nvim_buf_clear_namespace(
														old_namespace[aut].buf, old_namespace[aut].id,
														0, -1)
													old_namespace[aut] = nil
												end
												
											end
											cursors = {}
											
											vimcmd("augroup instantSession")
											vimcmd("autocmd!")
											vimcmd("augroup end")
											
											
										elseif not decoded["is_first"] and first then
											table.insert(events, "ERROR: Tried to start a server which is already busy")
											print("ERROR: Tried to start a server which is already busy")
											for bufhandle,_ in pairs(allprev) do
												if vim.api.nvim_buf_is_loaded(bufhandle) then
													DetachFromBuffer(bufhandle)
												end
											end
											StopClient()
											
											
											for aut,_ in pairs(cursors) do
												if cursors[aut] then
													vim.api.nvim_buf_clear_namespace(
														cursors[aut].buf, cursors[aut].id,
														0, -1)
													cursors[aut] = nil
												end
												
												if old_namespace[aut] then
													vim.api.nvim_buf_clear_namespace(
														old_namespace[aut].buf, old_namespace[aut].id,
														0, -1)
													old_namespace[aut] = nil
												end
												
											end
											cursors = {}
											
											vimcmd("augroup instantSession")
											vimcmd("autocmd!")
											vimcmd("augroup end")
											
											
										end
									end
									
									if decoded["type"] == "status" then
										print("Connected: " .. tostring(decoded["num_clients"]) .. " client(s). ")
									end
									
								else
									table.insert(events, "Could not decode json " .. fragmented)
								end
								
							end
						end
						
						if opcode == 0x9 then -- PING
							local paylen = OpAnd(b2, 0x7F)
							local paylenlen = 0
							if paylen == 126 then -- 16 bits length
								local b3 = string.byte(string.sub(first_chunk,3,3))
								local b4 = string.byte(string.sub(first_chunk,4,4))
								paylen = OpLshift(b3, 8) + b4
								paylenlen = 2
							elseif paylen == 127 then
								paylen = 0
								for i=0,7 do -- 64 bits length
									paylen = OpLshift(paylen, 8) 
									paylen = paylen + string.byte(string.sub(first_chunk,i+3,i+3))
								end
								paylenlen = 8
							end
							-- table.insert(frames, "PAYLOAD LENGTH " .. paylen)
							
							--table.insert(frames, "SENT PONG")
							local mask = {}
							for i=1,4 do
								table.insert(mask, math.floor(math.random() * 255))
							end
							
							local frame = {
								0x8A, 0x80,
							}
							for i=1,4 do 
								table.insert(frame, mask[i])
							end
							local s = ConvertBytesToString(frame)
							
							client:write(s)
							
							
						end
						
					end
				end
			end
			
		end))
		client:write("GET / HTTP/1.1\r\n")
		client:write("Host: " .. appuri .. ":" .. port .. "\r\n")
		client:write("Upgrade: websocket\r\n")
		client:write("Connection: Upgrade\r\n")
		websocketkey = ConvertToBase64(GenerateWebSocketKey())
		client:write("Sec-WebSocket-Key: " .. websocketkey .. "\r\n")
		client:write("Sec-WebSocket-Version: 13\r\n")
		client:write("\r\n")
		
	end))
end

function StopClient()
	local mask = {}
	for i=1,4 do
		table.insert(mask, math.floor(math.random() * 255))
	end
	
	local frame = {
		0x88, 0x80,
	}
	for i=1,4 do 
		table.insert(frame, mask[i])
	end
	local s = ConvertBytesToString(frame)
	
	client:write(s)
	
	
	client:close()
	client = nil
	
end


function DetachFromBuffer(bufnr)
	table.insert(events, "Detaching from buffer... " .. bufnr)
	detach[bufnr] = true
end


local function Start(host, port)
	if client and client:is_active() then
		error("Client is already connected. Use InstantStop first to disconnect.")
	end
	

	local buf = vim.api.nvim_get_current_buf()
	singlebuf = buf
	local first = true
	sessionshare = false
	StartClient(first, host, port)
	

end

local function Join(host, port)
	if client and client:is_active() then
		error("Client is already connected. Use InstantStop first to disconnect.")
	end
	

	local buf = vim.api.nvim_get_current_buf()
	singlebuf = buf
	local first = false
	sessionshare = false
	StartClient(first, host, port)
	
end

local function Stop()
	for bufhandle,_ in pairs(allprev) do
		if vim.api.nvim_buf_is_loaded(bufhandle) then
			DetachFromBuffer(bufhandle)
		end
	end
	StopClient()
	
	
	for aut,_ in pairs(cursors) do
		if cursors[aut] then
			vim.api.nvim_buf_clear_namespace(
				cursors[aut].buf, cursors[aut].id,
				0, -1)
			cursors[aut] = nil
		end
		
		if old_namespace[aut] then
			vim.api.nvim_buf_clear_namespace(
				old_namespace[aut].buf, old_namespace[aut].id,
				0, -1)
			old_namespace[aut] = nil
		end
		
	end
	cursors = {}
	
	vimcmd("augroup instantSession")
	vimcmd("autocmd!")
	vimcmd("augroup end")
	
	
	print("Disconnected!")
end


local function StartSession(host, port)
	if client and client:is_active() then
		error("Client is already connected. Use InstantStop first to disconnect.")
	end
	

	local first = true
	sessionshare = true
	StartClient(first, host, port)
	
end

local function JoinSession(host, port)
	if client and client:is_active() then
		error("Client is already connected. Use InstantStop first to disconnect.")
	end
	

	local first = false
	sessionshare = true
	StartClient(first, host, port)
	
end


local function Status()
	if client and client:is_active() then
		local obj = {
			["type"] = "status",
		}
		local encoded = vim.api.nvim_call_function("json_encode", { obj })
		if not encoded then
			print("line number " .. debug.getinfo(1).currentline)
		end
		SendText(encoded)
		-- table.insert(events, "sent " .. encoded)
		
		
	else
		print("Disconnected")
	end
end


return {
Start = Start,
Join = Join,
Stop = Stop,

Refresh = Refresh,

Status = Status,

StartSession = StartSession,
JoinSession = JoinSession,

attach_status_update = attach_status_update,

}

