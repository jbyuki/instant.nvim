-- Generated using ntangle.nvim
local websocket_client = require("instant.websocket_client")

local DetachFromBuffer

local getConfig

local findCharPositionBefore

local splitArray

local utf8split

local isPIDEqual

local isLowerOrEqual

local utf8len, utf8char

local utf8insert

local utf8remove

local genPID

local afterPID

local SendOp

local genPIDSeq

local log

local api_attach = {}
local api_attach_id = 1

local attached = {}

local detach = {}

allprev = {}
local prev = { "" }

local vtextGroup

local old_namespace

local cursors = {}
local cursorGroup

local follow = false
local follow_aut

local loc2rem = {}
local rem2loc = {}

local only_share_cwd

local received = {}

local ws_client

local singlebuf

local sessionshare = false

local disable_undo = false

local undostack = {}
local undosp = {}

local undoslice = {}

local hl_group = {}
local client_hl_group = {}

local autocmd_init = false

local marks = {}

local author2id = {}
local id2author = {}

-- pos = [(num, site)]
local MAXINT = 1e10 -- can be adjusted
local startpos, endpos = {{0, 0}}, {{MAXINT, 0}}
-- line = [pos]
-- pids = [line]
allpids = {}
local pids = {}

local agent = 0

local author = vim.api.nvim_get_var("instant_username")

local ignores = {}

local log_filename
if vim.g.instant_log then
  log_filename = vim.fn.stdpath("data") .. "/instant.log"
end

local MSG_TYPE = {
DATA = 9,

AVAILABLE = 2,

REQUEST = 3,

INITIAL = 6,

INFO = 5,

MARK = 10,

TEXT = 1,

CONNECT = 7,

DISCONNECT = 8,

}
local OP_TYPE = {
DEL = 1,

INS = 2,

}

local function findPIDBefore(opid)
	local x, y = findCharPositionBefore(opid)
	if x == 1 then
		return pids[y-1][#pids[y-1]]
	elseif x then
		return pids[y][x-1]
	end
end

function getConfig(varname, default)
	local v, value = pcall(function() return vim.api.nvim_get_var(varname) end)
	if not v then value = default end
	return value
end

function instantOpenOrCreateBuffer(buf)
	if (sessionshare and not received[buf]) or buf == singlebuf then
		local fullname = vim.api.nvim_buf_get_name(buf)
		local cwdname = vim.api.nvim_call_function("fnamemodify",
			{ fullname, ":." })
		local bufname = cwdname
		if bufname == fullname then
			bufname = vim.api.nvim_call_function("fnamemodify",
			{ fullname, ":t" })
		end


		if cwdname ~= fullname or not only_share_cwd then
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)

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
					local newpid = newpids[newpidindex]
					newpidindex = newpidindex + 1

					table.insert(pids, i+1, { newpid })

				end

				for j=1,string.len(line) do
					local newpid = newpids[newpidindex]
					newpidindex = newpidindex + 1

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

			local rem = loc2rem[buf]

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

			ws_client:send_text(encoded)


			attached[buf] = nil

			detach[buf] = nil

			undostack[buf] = {}
			undosp[buf] = 0

			undoslice[buf] = {}

			ignores[buf] = {}

			if not attached[buf] then
				local attach_success = vim.api.nvim_buf_attach(buf, false, {
					on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
						if detach[buf] then
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

										SendOp(buf, { OP_TYPE.DEL, del_pid, "\n" })

									end
								else
									local c = utf8char(prev[y+1], x)

									prev[y+1] = utf8remove(prev[y+1], x)

									local del_pid = pids[y+2][x+2]
									table.remove(pids[y+2], x+2)

									SendOp(buf, { OP_TYPE.DEL, del_pid, c })

								end
							end
							endx = utf8len(prev[y] or "")-1
						end

						local len_insert = 0
						local startx = add_range.sx
						for y=add_range.sy, add_range.ey do
							local endx
							if y == add_range.ey then
								endx = add_range.ex
							else
								endx = utf8len(cur_lines[y-firstline+1])-1
							end

							for x=startx,endx do
								len_insert = len_insert + 1 
							end
							startx = -1
						end

						local before_pid, after_pid
						if add_range.sx == -1 then
							local pidx
							local x, y = add_range.sx, add_range.sy
							if cur_lines[y-firstline] then
								pidx = utf8len(cur_lines[y-firstline])+1
							else
								pidx = #pids[y+1]
							end
							before_pid = pids[y+1][pidx]
							after_pid = afterPID(pidx, y+1)

						else
							local x, y = add_range.sx, add_range.sy
							before_pid = pids[y+2][x+1]
							after_pid = afterPID(x+1, y+2)

						end

						local newpidindex = 1
						local newpids = genPIDSeq(before_pid, after_pid, agent, 1, len_insert)

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

									local new_pid = newpids[newpidindex]
									newpidindex = newpidindex + 1

									local l, r = splitArray(pids[y+1], pidx+1)
									pids[y+1] = l
									table.insert(r, 1, new_pid)
									table.insert(pids, y+2, r)

									SendOp(buf, { OP_TYPE.INS, "\n", new_pid })

								else
									local c = utf8char(cur_lines[y-firstline+1], x)
									prev[y+1] = utf8insert(prev[y+1], x, c)

									local new_pid = newpids[newpidindex]
									newpidindex = newpidindex + 1

									table.insert(pids[y+2], x+2, new_pid)

									SendOp(buf, { OP_TYPE.INS, c, new_pid })

								end
							end
							startx = -1
						end

						allprev[buf] = prev
						allpids[buf] = pids

			      local mode = vim.api.nvim_call_function("mode", {})
			      local insert_mode = mode == "i"

			      if not insert_mode then
			        if #undoslice[buf] > 0 then
			        	while undosp[buf] < #undostack[buf] do
			        		table.remove(undostack[buf]) -- remove last element
			        	end
			        	table.insert(undostack[buf], undoslice[buf])
			        	undosp[buf] = undosp[buf] + 1
			        	undoslice[buf] = {}
			        end

			      end

					end,
					on_detach = function(_, buf)
						attached[buf] = nil
					end
				})

				vim.api.nvim_buf_set_keymap(buf, 'n', 'u', '<cmd>lua require("instant").undo(' .. buf .. ')<CR>', {noremap = true})

				vim.api.nvim_buf_set_keymap(buf, 'n', '<C-r>', '<cmd>lua require("instant").redo(' .. buf .. ')<CR>', {noremap = true})


				if attach_success then
					attached[buf] = true
				end
			else
				detach[buf] = nil
			end



		end
	end
end

function leave_insert()
  for buf,_ in pairs(undoslice) do
    if #undoslice[buf] > 0 then
    	while undosp[buf] < #undostack[buf] do
    		table.remove(undostack[buf]) -- remove last element
    	end
    	table.insert(undostack[buf], undoslice[buf])
    	undosp[buf] = undosp[buf] + 1
    	undoslice[buf] = {}
    end

  end
end

local function MarkRange()
  local _, snum, scol, _ = unpack(vim.api.nvim_call_function("getpos", { "'<" }))
  local _, enum, ecol, _ = unpack(vim.api.nvim_call_function("getpos", { "'>" }))

  local curbuf = vim.api.nvim_get_current_buf()
  local pids = allpids[curbuf]
  local prev = allprev[curbuf]

  ecol = math.min(ecol, string.len(prev[enum])+1)

  local bscol = vim.str_utfindex(prev[snum], scol-1)
  local becol = vim.str_utfindex(prev[enum], ecol-1)

  local spid = pids[snum+1][bscol+1]
  local epid
  if #pids[enum+1] < becol+1 then
    epid = pids[enum+2][1]
  else
    epid = pids[enum+1][becol+1]
  end

  if marks[agent] then
    vim.api.nvim_buf_clear_namespace(marks[agent].buf, marks[agent].ns_id, 0, -1)
    marks[agent] = nil
  end

  marks[agent] = {}
  marks[agent].buf = curbuf
  marks[agent].ns_id = vim.api.nvim_create_namespace("")
  for y=snum-1,enum-1 do
    local lscol
    if y == snum-1 then lscol = scol-1
    else lscol = 0 end

    local lecol
    if y == enum-1 then lecol = ecol-1
    else lecol = -1 end

    vim.api.nvim_buf_add_highlight(
      marks[agent].buf, 
      marks[agent].ns_id, 
      "TermCursor", 
      y, lscol, lecol)
  end

  local rem = loc2rem[curbuf]
  local obj = {
  	MSG_TYPE.MARK,
  	agent,
    rem,
    spid, epid,
  }

  local encoded = vim.api.nvim_call_function("json_encode", { obj })
  ws_client:send_text(encoded)


end

local function MarkClear()
  for _, mark in pairs(marks) do
    vim.api.nvim_buf_clear_namespace(mark.buf, mark.ns_id, 0, -1)
  end

  marks = {}

end

function findCharPositionBefore(opid)
	local y1, y2 = 1, #pids
	while true do
		local ym = math.floor((y2 + y1)/2)
		if ym == y1 then break end
		if isLowerOrEqual(pids[ym][1], opid) then
			y1 = ym
		else
			y2 = ym
		end
	end

	local px, py = 1, 1
	for y=y1,#pids do
		for x,pid in ipairs(pids[y]) do
			if not isLowerOrEqual(pid, opid) then
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
		if isLowerOrEqual(pids[ym][1], opid) then
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

		if not isLowerOrEqual(pid, opid) then
			return nil
		end
	end


end

function isLowerOrEqual(a, b)
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

function afterPID(x, y)
	if x == #pids[y] then return pids[y+1][1]
	else return pids[y][x+1] end
end

function SendOp(buf, op)
	if not disable_undo then
		table.insert(undoslice[buf], op)
	end

	local rem = loc2rem[buf]

	local obj = {
		MSG_TYPE.TEXT,
		op,
		rem,
		agent,
	}

	local encoded = vim.api.nvim_call_function("json_encode", { obj })


  log(string.format("send[%d] : %s", agent, vim.inspect(encoded)))
	ws_client:send_text(encoded)

end

function genPIDSeq(p, q, s, i, N)
	local a = (p[i] and p[i][1]) or 0
	local b = (q[i] and q[i][1]) or MAXINT

	if a+N < b-1 then
		local step = math.floor((b-1 - (a+1))/N)
		local start = a+1
		local G = {}
		for i=1,N do
			table.insert(G,
				{{math.random(start,start+step-1), s}})
			start = start + step
		end
		return G
	end

	local G = genPIDSeq(p, q, s, i+1, N)
	for j=1,N do
		table.insert(G[j], 1, {
			(p[i] and p[i][1]) or 0, 
			(p[i] and p[i][2]) or s})
	end
	return G
end
function log(str)
  if log_filename then
    local f = io.open(log_filename, "a")
    if f then
      f:write(str .. "\n")
      f:close()
    end
  end
end


local function StartClient(first, appuri, port)
	local v, username = pcall(function() return vim.api.nvim_get_var("instant_username") end)
	if not v then
		error("Please specify a username in g:instant_username")
	end

	detach = {}

	vtextGroup = {
		getConfig("instant_name_hl_group_user1", "CursorLineNr"),
		getConfig("instant_name_hl_group_user2", "CursorLineNr"),
		getConfig("instant_name_hl_group_user3", "CursorLineNr"),
		getConfig("instant_name_hl_group_user4", "CursorLineNr"),
		getConfig("instant_name_hl_group_default", "CursorLineNr")
	}

	old_namespace = {}

	cursorGroup = {
		getConfig("instant_cursor_hl_group_user1", "Cursor"),
		getConfig("instant_cursor_hl_group_user2", "Cursor"),
		getConfig("instant_cursor_hl_group_user3", "Cursor"),
		getConfig("instant_cursor_hl_group_user4", "Cursor"),
		getConfig("instant_cursor_hl_group_default", "Cursor")
	}

	cursors = {}

	loc2rem = {}
	rem2loc = {}

	only_share_cwd = getConfig("g:instant_only_cwd", true)

	ws_client = websocket_client { uri = appuri, port = port }
	ws_client:connect {
		on_connect = function()
			local obj = {
				MSG_TYPE.INFO,
				sessionshare,
				author,
				agent,
			}
			local encoded = vim.api.nvim_call_function("json_encode", { obj })
			ws_client:send_text(encoded)


			for _, o in pairs(api_attach) do
				if o.on_connect then
					o.on_connect()
				end
			end

      vim.schedule(function() print("Connected!") end)
		end,
		on_text = function(wsdata)
			local decoded = vim.api.nvim_call_function("json_decode", {  wsdata })

			if decoded then
			  log(string.format("rec[%d] : %s", agent, vim.inspect(decoded)))
				if decoded[1] == MSG_TYPE.TEXT then
					local _, op, other_rem, other_agent = unpack(decoded)
					local lastPID
					local opline = 0
					local opcol = 0

					local ag, bufid = unpack(other_rem)
					buf = rem2loc[ag][bufid]

					prev = allprev[buf]
					pids = allpids[buf]

					local tick = vim.api.nvim_buf_get_changedtick(buf)+1
					ignores[buf][tick] = true

					if op[1] == OP_TYPE.INS then
						lastPID = op[3]

						local x, y = findCharPositionBefore(op[3])

						if op[2] == "\n" then
							opline = y-1
						else
							opline = y-2
						end
						opcol = x

						if op[2] == "\n" then 
							local py, py1 = splitArray(pids[y], x+1)
							pids[y] = py
							table.insert(py1, 1, op[3])
							table.insert(pids, y+1, py1)
						else table.insert(pids[y], x+1, op[3] ) end

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


					elseif op[1] == OP_TYPE.DEL then
						lastPID = findPIDBefore(op[2])

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
					local aut = id2author[other_agent]

					if lastPID and other_agent ~= agent then
						local x, y = findCharPositionExact(lastPID)

						if old_namespace[aut] then
							if attached[old_namespace[aut].buf] then
								vim.api.nvim_buf_clear_namespace(
									old_namespace[aut].buf, old_namespace[aut].id,
									0, -1)
							end
							old_namespace[aut] = nil
						end

						if cursors[aut] then
							if attached[cursors[aut].buf] then
								vim.api.nvim_buf_clear_namespace(
									cursors[aut].buf, cursors[aut].id,
									0, -1)
							end
							cursors[aut] = nil
						end

						if x then
							if x == 1 then x = 2 end
							old_namespace[aut] = {
								id = vim.api.nvim_buf_set_virtual_text(
									buf, 0, 
									math.max(y-2, 0), 
									{{ aut, vtextGroup[client_hl_group[other_agent]] }}, 
									{}),
								buf = buf
							}

							if prev[y-1] and x-2 >= 0 and x-2 <= utf8len(prev[y-1]) then
								local bx = vim.str_byteindex(prev[y-1], x-2)
								cursors[aut] = {
									id = vim.api.nvim_buf_add_highlight(buf,
										0, cursorGroup[client_hl_group[other_agent]], y-2, bx, bx+1),
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
						if follow and follow_aut == aut then
							local curbuf = vim.api.nvim_get_current_buf()
							if curbuf ~= buf then
								vim.api.nvim_set_current_buf(buf)
							end

							vim.api.nvim_command("normal " .. (y-1) .. "gg")
						end


						for _, o in pairs(api_attach) do
							if o.on_change then
								o.on_change(aut, buf, y-2)
							end
						end

					end
					-- @check_if_pid_match_with_prev

				end

				if decoded[1] == MSG_TYPE.REQUEST then
					local encoded
					if not sessionshare then
						local buf = singlebuf
				    local rem
				    if loc2rem[buf] then
				      rem = loc2rem[buf]
				    else
				      rem = { agent, buf }
				    end
						local fullname = vim.api.nvim_buf_get_name(buf)
						local cwdname = vim.api.nvim_call_function("fnamemodify",
							{ fullname, ":." })
						local bufname = cwdname
						if bufname == fullname then
							bufname = vim.api.nvim_call_function("fnamemodify",
							{ fullname, ":t" })
						end

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

						ws_client:send_text(encoded)

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

							ws_client:send_text(encoded)

						end
					end
				end


				if decoded[1] == MSG_TYPE.INITIAL then
					local _, bufname, bufid, pidslist, content = unpack(decoded)

					local ag, bufid = unpack(bufid)
					if not rem2loc[ag] or not rem2loc[ag][bufid] then
						local buf
						if not sessionshare then
							buf = singlebuf
							vim.api.nvim_buf_set_name(buf, bufname)

							if vim.api.nvim_buf_call then
								vim.api.nvim_buf_call(buf, function()
									vim.api.nvim_command("doautocmd BufRead " .. vim.api.nvim_buf_get_name(buf))
								end)
							end

						else
							buf = vim.api.nvim_create_buf(true, true)

				      received[buf] = true
							attached[buf] = nil

							detach[buf] = nil

							undostack[buf] = {}
							undosp[buf] = 0

							undoslice[buf] = {}

							ignores[buf] = {}

							if not attached[buf] then
								local attach_success = vim.api.nvim_buf_attach(buf, false, {
									on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
										if detach[buf] then
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

														SendOp(buf, { OP_TYPE.DEL, del_pid, "\n" })

													end
												else
													local c = utf8char(prev[y+1], x)

													prev[y+1] = utf8remove(prev[y+1], x)

													local del_pid = pids[y+2][x+2]
													table.remove(pids[y+2], x+2)

													SendOp(buf, { OP_TYPE.DEL, del_pid, c })

												end
											end
											endx = utf8len(prev[y] or "")-1
										end

										local len_insert = 0
										local startx = add_range.sx
										for y=add_range.sy, add_range.ey do
											local endx
											if y == add_range.ey then
												endx = add_range.ex
											else
												endx = utf8len(cur_lines[y-firstline+1])-1
											end

											for x=startx,endx do
												len_insert = len_insert + 1 
											end
											startx = -1
										end

										local before_pid, after_pid
										if add_range.sx == -1 then
											local pidx
											local x, y = add_range.sx, add_range.sy
											if cur_lines[y-firstline] then
												pidx = utf8len(cur_lines[y-firstline])+1
											else
												pidx = #pids[y+1]
											end
											before_pid = pids[y+1][pidx]
											after_pid = afterPID(pidx, y+1)

										else
											local x, y = add_range.sx, add_range.sy
											before_pid = pids[y+2][x+1]
											after_pid = afterPID(x+1, y+2)

										end

										local newpidindex = 1
										local newpids = genPIDSeq(before_pid, after_pid, agent, 1, len_insert)

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

													local new_pid = newpids[newpidindex]
													newpidindex = newpidindex + 1

													local l, r = splitArray(pids[y+1], pidx+1)
													pids[y+1] = l
													table.insert(r, 1, new_pid)
													table.insert(pids, y+2, r)

													SendOp(buf, { OP_TYPE.INS, "\n", new_pid })

												else
													local c = utf8char(cur_lines[y-firstline+1], x)
													prev[y+1] = utf8insert(prev[y+1], x, c)

													local new_pid = newpids[newpidindex]
													newpidindex = newpidindex + 1

													table.insert(pids[y+2], x+2, new_pid)

													SendOp(buf, { OP_TYPE.INS, c, new_pid })

												end
											end
											startx = -1
										end

										allprev[buf] = prev
										allpids[buf] = pids

							      local mode = vim.api.nvim_call_function("mode", {})
							      local insert_mode = mode == "i"

							      if not insert_mode then
							        if #undoslice[buf] > 0 then
							        	while undosp[buf] < #undostack[buf] do
							        		table.remove(undostack[buf]) -- remove last element
							        	end
							        	table.insert(undostack[buf], undoslice[buf])
							        	undosp[buf] = undosp[buf] + 1
							        	undoslice[buf] = {}
							        end

							      end

									end,
									on_detach = function(_, buf)
										attached[buf] = nil
									end
								})

								vim.api.nvim_buf_set_keymap(buf, 'n', 'u', '<cmd>lua require("instant").undo(' .. buf .. ')<CR>', {noremap = true})

								vim.api.nvim_buf_set_keymap(buf, 'n', '<C-r>', '<cmd>lua require("instant").redo(' .. buf .. ')<CR>', {noremap = true})


								if attach_success then
									attached[buf] = true
								end
							else
								detach[buf] = nil
							end



							vim.api.nvim_buf_set_name(buf, bufname)

							if vim.api.nvim_buf_call then
								vim.api.nvim_buf_call(buf, function()
									vim.api.nvim_command("doautocmd BufRead " .. vim.api.nvim_buf_get_name(buf))
								end)
							end

							vim.api.nvim_buf_set_option(buf, "buftype", "")

						end

						if not rem2loc[ag] then
							rem2loc[ag] = {}
						end

						rem2loc[ag][bufid] = buf
						loc2rem[buf] = { ag, bufid }


						prev = content

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


						local tick = vim.api.nvim_buf_get_changedtick(buf)+1
						ignores[buf][tick] = true

						vim.api.nvim_buf_set_lines(
							buf,
							0, -1, false, prev)

						allprev[buf] = prev
						allpids[buf] = pids
					else
						local buf = rem2loc[ag][bufid]

						prev = content

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


						local tick = vim.api.nvim_buf_get_changedtick(buf)+1
						ignores[buf][tick] = true

						vim.api.nvim_buf_set_lines(
							buf,
							0, -1, false, prev)

						allprev[buf] = prev
						allpids[buf] = pids

						vim.api.nvim_buf_set_name(buf, bufname)

						if vim.api.nvim_buf_call then
							vim.api.nvim_buf_call(buf, function()
								vim.api.nvim_command("doautocmd BufRead " .. vim.api.nvim_buf_get_name(buf))
							end)
						end

					end
				end

				if decoded[1] == MSG_TYPE.AVAILABLE then
					local _, is_first, client_id, is_sessionshare  = unpack(decoded)
					if is_first and first then
						agent = client_id


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
								attached[buf] = nil

								detach[buf] = nil

								undostack[buf] = {}
								undosp[buf] = 0

								undoslice[buf] = {}

								ignores[buf] = {}

								if not attached[buf] then
									local attach_success = vim.api.nvim_buf_attach(buf, false, {
										on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
											if detach[buf] then
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

															SendOp(buf, { OP_TYPE.DEL, del_pid, "\n" })

														end
													else
														local c = utf8char(prev[y+1], x)

														prev[y+1] = utf8remove(prev[y+1], x)

														local del_pid = pids[y+2][x+2]
														table.remove(pids[y+2], x+2)

														SendOp(buf, { OP_TYPE.DEL, del_pid, c })

													end
												end
												endx = utf8len(prev[y] or "")-1
											end

											local len_insert = 0
											local startx = add_range.sx
											for y=add_range.sy, add_range.ey do
												local endx
												if y == add_range.ey then
													endx = add_range.ex
												else
													endx = utf8len(cur_lines[y-firstline+1])-1
												end

												for x=startx,endx do
													len_insert = len_insert + 1 
												end
												startx = -1
											end

											local before_pid, after_pid
											if add_range.sx == -1 then
												local pidx
												local x, y = add_range.sx, add_range.sy
												if cur_lines[y-firstline] then
													pidx = utf8len(cur_lines[y-firstline])+1
												else
													pidx = #pids[y+1]
												end
												before_pid = pids[y+1][pidx]
												after_pid = afterPID(pidx, y+1)

											else
												local x, y = add_range.sx, add_range.sy
												before_pid = pids[y+2][x+1]
												after_pid = afterPID(x+1, y+2)

											end

											local newpidindex = 1
											local newpids = genPIDSeq(before_pid, after_pid, agent, 1, len_insert)

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

														local new_pid = newpids[newpidindex]
														newpidindex = newpidindex + 1

														local l, r = splitArray(pids[y+1], pidx+1)
														pids[y+1] = l
														table.insert(r, 1, new_pid)
														table.insert(pids, y+2, r)

														SendOp(buf, { OP_TYPE.INS, "\n", new_pid })

													else
														local c = utf8char(cur_lines[y-firstline+1], x)
														prev[y+1] = utf8insert(prev[y+1], x, c)

														local new_pid = newpids[newpidindex]
														newpidindex = newpidindex + 1

														table.insert(pids[y+2], x+2, new_pid)

														SendOp(buf, { OP_TYPE.INS, c, new_pid })

													end
												end
												startx = -1
											end

											allprev[buf] = prev
											allpids[buf] = pids

								      local mode = vim.api.nvim_call_function("mode", {})
								      local insert_mode = mode == "i"

								      if not insert_mode then
								        if #undoslice[buf] > 0 then
								        	while undosp[buf] < #undostack[buf] do
								        		table.remove(undostack[buf]) -- remove last element
								        	end
								        	table.insert(undostack[buf], undoslice[buf])
								        	undosp[buf] = undosp[buf] + 1
								        	undoslice[buf] = {}
								        end

								      end

										end,
										on_detach = function(_, buf)
											attached[buf] = nil
										end
									})

									vim.api.nvim_buf_set_keymap(buf, 'n', 'u', '<cmd>lua require("instant").undo(' .. buf .. ')<CR>', {noremap = true})

									vim.api.nvim_buf_set_keymap(buf, 'n', '<C-r>', '<cmd>lua require("instant").redo(' .. buf .. ')<CR>', {noremap = true})


									if attach_success then
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
										local newpid = newpids[newpidindex]
										newpidindex = newpidindex + 1

										table.insert(pids, i+1, { newpid })

									end

									for j=1,string.len(line) do
										local newpid = newpids[newpidindex]
										newpidindex = newpidindex + 1

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

							attached[buf] = nil

							detach[buf] = nil

							undostack[buf] = {}
							undosp[buf] = 0

							undoslice[buf] = {}

							ignores[buf] = {}

							if not attached[buf] then
								local attach_success = vim.api.nvim_buf_attach(buf, false, {
									on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
										if detach[buf] then
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

														SendOp(buf, { OP_TYPE.DEL, del_pid, "\n" })

													end
												else
													local c = utf8char(prev[y+1], x)

													prev[y+1] = utf8remove(prev[y+1], x)

													local del_pid = pids[y+2][x+2]
													table.remove(pids[y+2], x+2)

													SendOp(buf, { OP_TYPE.DEL, del_pid, c })

												end
											end
											endx = utf8len(prev[y] or "")-1
										end

										local len_insert = 0
										local startx = add_range.sx
										for y=add_range.sy, add_range.ey do
											local endx
											if y == add_range.ey then
												endx = add_range.ex
											else
												endx = utf8len(cur_lines[y-firstline+1])-1
											end

											for x=startx,endx do
												len_insert = len_insert + 1 
											end
											startx = -1
										end

										local before_pid, after_pid
										if add_range.sx == -1 then
											local pidx
											local x, y = add_range.sx, add_range.sy
											if cur_lines[y-firstline] then
												pidx = utf8len(cur_lines[y-firstline])+1
											else
												pidx = #pids[y+1]
											end
											before_pid = pids[y+1][pidx]
											after_pid = afterPID(pidx, y+1)

										else
											local x, y = add_range.sx, add_range.sy
											before_pid = pids[y+2][x+1]
											after_pid = afterPID(x+1, y+2)

										end

										local newpidindex = 1
										local newpids = genPIDSeq(before_pid, after_pid, agent, 1, len_insert)

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

													local new_pid = newpids[newpidindex]
													newpidindex = newpidindex + 1

													local l, r = splitArray(pids[y+1], pidx+1)
													pids[y+1] = l
													table.insert(r, 1, new_pid)
													table.insert(pids, y+2, r)

													SendOp(buf, { OP_TYPE.INS, "\n", new_pid })

												else
													local c = utf8char(cur_lines[y-firstline+1], x)
													prev[y+1] = utf8insert(prev[y+1], x, c)

													local new_pid = newpids[newpidindex]
													newpidindex = newpidindex + 1

													table.insert(pids[y+2], x+2, new_pid)

													SendOp(buf, { OP_TYPE.INS, c, new_pid })

												end
											end
											startx = -1
										end

										allprev[buf] = prev
										allpids[buf] = pids

							      local mode = vim.api.nvim_call_function("mode", {})
							      local insert_mode = mode == "i"

							      if not insert_mode then
							        if #undoslice[buf] > 0 then
							        	while undosp[buf] < #undostack[buf] do
							        		table.remove(undostack[buf]) -- remove last element
							        	end
							        	table.insert(undostack[buf], undoslice[buf])
							        	undosp[buf] = undosp[buf] + 1
							        	undoslice[buf] = {}
							        end

							      end

									end,
									on_detach = function(_, buf)
										attached[buf] = nil
									end
								})

								vim.api.nvim_buf_set_keymap(buf, 'n', 'u', '<cmd>lua require("instant").undo(' .. buf .. ')<CR>', {noremap = true})

								vim.api.nvim_buf_set_keymap(buf, 'n', '<C-r>', '<cmd>lua require("instant").redo(' .. buf .. ')<CR>', {noremap = true})


								if attach_success then
									attached[buf] = true
								end
							else
								detach[buf] = nil
							end



							if not rem2loc[agent] then
								rem2loc[agent] = {}
							end

							rem2loc[agent][buf] = buf
							loc2rem[buf] = { agent, buf }

							local rem = loc2rem[buf]


							local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)

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
									local newpid = newpids[newpidindex]
									newpidindex = newpidindex + 1

									table.insert(pids, i+1, { newpid })

								end

								for j=1,string.len(line) do
									local newpid = newpids[newpidindex]
									newpidindex = newpidindex + 1

									table.insert(pids[i+1], newpid)

								end
							end

							prev = lines

							allprev[buf] = prev
							allpids[buf] = pids

						end

						vim.api.nvim_command("augroup instantSession")
						vim.api.nvim_command("autocmd!")
						-- this is kind of messy
						-- a better way to write this
						-- would be great
						vim.api.nvim_command("autocmd BufNewFile,BufRead * call execute('lua instantOpenOrCreateBuffer(' . expand('<abuf>') . ')', '')")
						vim.api.nvim_command("augroup end")

					elseif not is_first and not first then
						if is_sessionshare ~= sessionshare then
							print("ERROR: Share mode client server mismatch (session mode, single buffer mode)")
							for aut,_ in pairs(cursors) do
								if cursors[aut] then
									if attached[cursors[aut].buf] then
										vim.api.nvim_buf_clear_namespace(
											cursors[aut].buf, cursors[aut].id,
											0, -1)
									end
									cursors[aut] = nil
								end

								if old_namespace[aut] then
									if attached[old_namespace[aut].buf] then
										vim.api.nvim_buf_clear_namespace(
											old_namespace[aut].buf, old_namespace[aut].id,
											0, -1)
									end
									old_namespace[aut] = nil
								end

							end
							cursors = {}
							vim.api.nvim_command("augroup instantSession")
							vim.api.nvim_command("autocmd!")
							vim.api.nvim_command("augroup end")


							for bufhandle,_ in pairs(allprev) do
								if vim.api.nvim_buf_is_loaded(bufhandle) then
									DetachFromBuffer(bufhandle)
								end
							end

							agent = 0
						else
							agent = client_id


							if not sessionshare then
								local buf = singlebuf

								attached[buf] = nil

								detach[buf] = nil

								undostack[buf] = {}
								undosp[buf] = 0

								undoslice[buf] = {}

								ignores[buf] = {}

								if not attached[buf] then
									local attach_success = vim.api.nvim_buf_attach(buf, false, {
										on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
											if detach[buf] then
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

															SendOp(buf, { OP_TYPE.DEL, del_pid, "\n" })

														end
													else
														local c = utf8char(prev[y+1], x)

														prev[y+1] = utf8remove(prev[y+1], x)

														local del_pid = pids[y+2][x+2]
														table.remove(pids[y+2], x+2)

														SendOp(buf, { OP_TYPE.DEL, del_pid, c })

													end
												end
												endx = utf8len(prev[y] or "")-1
											end

											local len_insert = 0
											local startx = add_range.sx
											for y=add_range.sy, add_range.ey do
												local endx
												if y == add_range.ey then
													endx = add_range.ex
												else
													endx = utf8len(cur_lines[y-firstline+1])-1
												end

												for x=startx,endx do
													len_insert = len_insert + 1 
												end
												startx = -1
											end

											local before_pid, after_pid
											if add_range.sx == -1 then
												local pidx
												local x, y = add_range.sx, add_range.sy
												if cur_lines[y-firstline] then
													pidx = utf8len(cur_lines[y-firstline])+1
												else
													pidx = #pids[y+1]
												end
												before_pid = pids[y+1][pidx]
												after_pid = afterPID(pidx, y+1)

											else
												local x, y = add_range.sx, add_range.sy
												before_pid = pids[y+2][x+1]
												after_pid = afterPID(x+1, y+2)

											end

											local newpidindex = 1
											local newpids = genPIDSeq(before_pid, after_pid, agent, 1, len_insert)

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

														local new_pid = newpids[newpidindex]
														newpidindex = newpidindex + 1

														local l, r = splitArray(pids[y+1], pidx+1)
														pids[y+1] = l
														table.insert(r, 1, new_pid)
														table.insert(pids, y+2, r)

														SendOp(buf, { OP_TYPE.INS, "\n", new_pid })

													else
														local c = utf8char(cur_lines[y-firstline+1], x)
														prev[y+1] = utf8insert(prev[y+1], x, c)

														local new_pid = newpids[newpidindex]
														newpidindex = newpidindex + 1

														table.insert(pids[y+2], x+2, new_pid)

														SendOp(buf, { OP_TYPE.INS, c, new_pid })

													end
												end
												startx = -1
											end

											allprev[buf] = prev
											allpids[buf] = pids

								      local mode = vim.api.nvim_call_function("mode", {})
								      local insert_mode = mode == "i"

								      if not insert_mode then
								        if #undoslice[buf] > 0 then
								        	while undosp[buf] < #undostack[buf] do
								        		table.remove(undostack[buf]) -- remove last element
								        	end
								        	table.insert(undostack[buf], undoslice[buf])
								        	undosp[buf] = undosp[buf] + 1
								        	undoslice[buf] = {}
								        end

								      end

										end,
										on_detach = function(_, buf)
											attached[buf] = nil
										end
									})

									vim.api.nvim_buf_set_keymap(buf, 'n', 'u', '<cmd>lua require("instant").undo(' .. buf .. ')<CR>', {noremap = true})

									vim.api.nvim_buf_set_keymap(buf, 'n', '<C-r>', '<cmd>lua require("instant").redo(' .. buf .. ')<CR>', {noremap = true})


									if attach_success then
										attached[buf] = true
									end
								else
									detach[buf] = nil
								end



							end
							local obj = {
								MSG_TYPE.REQUEST,
							}
							local encoded = vim.api.nvim_call_function("json_encode", {  obj  })
							ws_client:send_text(encoded)


							vim.api.nvim_command("augroup instantSession")
							vim.api.nvim_command("autocmd!")
							-- this is kind of messy
							-- a better way to write this
							-- would be great
							vim.api.nvim_command("autocmd BufNewFile,BufRead * call execute('lua instantOpenOrCreateBuffer(' . expand('<abuf>') . ')', '')")
							vim.api.nvim_command("augroup end")

						end
					elseif is_first and not first then
						print("ERROR: Tried to join an empty server")
						for aut,_ in pairs(cursors) do
							if cursors[aut] then
								if attached[cursors[aut].buf] then
									vim.api.nvim_buf_clear_namespace(
										cursors[aut].buf, cursors[aut].id,
										0, -1)
								end
								cursors[aut] = nil
							end

							if old_namespace[aut] then
								if attached[old_namespace[aut].buf] then
									vim.api.nvim_buf_clear_namespace(
										old_namespace[aut].buf, old_namespace[aut].id,
										0, -1)
								end
								old_namespace[aut] = nil
							end

						end
						cursors = {}
						vim.api.nvim_command("augroup instantSession")
						vim.api.nvim_command("autocmd!")
						vim.api.nvim_command("augroup end")


						for bufhandle,_ in pairs(allprev) do
							if vim.api.nvim_buf_is_loaded(bufhandle) then
								DetachFromBuffer(bufhandle)
							end
						end

						agent = 0
					elseif not is_first and first then
						print("ERROR: Tried to start a server which is already busy")
						for aut,_ in pairs(cursors) do
							if cursors[aut] then
								if attached[cursors[aut].buf] then
									vim.api.nvim_buf_clear_namespace(
										cursors[aut].buf, cursors[aut].id,
										0, -1)
								end
								cursors[aut] = nil
							end

							if old_namespace[aut] then
								if attached[old_namespace[aut].buf] then
									vim.api.nvim_buf_clear_namespace(
										old_namespace[aut].buf, old_namespace[aut].id,
										0, -1)
								end
								old_namespace[aut] = nil
							end

						end
						cursors = {}
						vim.api.nvim_command("augroup instantSession")
						vim.api.nvim_command("autocmd!")
						vim.api.nvim_command("augroup end")


						for bufhandle,_ in pairs(allprev) do
							if vim.api.nvim_buf_is_loaded(bufhandle) then
								DetachFromBuffer(bufhandle)
							end
						end

						agent = 0
					end
				end

				if decoded[1] == MSG_TYPE.CONNECT then
					local _, new_id, new_aut = unpack(decoded)
					author2id[new_aut] = new_id
					id2author[new_id] = new_aut
					local user_hl_group = 5
					for i=1,4 do
						if not hl_group[i] then
							hl_group[i] = true
							user_hl_group = i
							break
						end
					end

					client_hl_group[new_id] = user_hl_group 

					for _, o in pairs(api_attach) do
						if o.on_clientconnected then
							o.on_clientconnected(new_aut)
						end
					end

				end

				if decoded[1] == MSG_TYPE.DISCONNECT then
					local _, remove_id = unpack(decoded)
					local aut = id2author[remove_id]
					if aut then
						author2id[aut] = nil
						id2author[remove_id] = nil
						if client_hl_group[remove_id] ~= 5 then -- 5 means default hl group (there are four predefined)
							hl_group[client_hl_group[remove_id]] = nil
						end
						client_hl_group[remove_id] = nil

						for _, o in pairs(api_attach) do
							if o.on_clientdisconnected then
								o.on_clientdisconnected(aut)
							end
						end

					end
				end
				if decoded[1] == MSG_TYPE.DATA then
					local _, data = unpack(decoded)
					for _, o in pairs(api_attach) do
						if o.on_data then
							o.on_data(data)
						end
					end

				end

			  if decoded[1] == MSG_TYPE.MARK then
			  	local _, other_agent, rem, spid, epid = unpack(decoded)
			    local ag, rembuf = unpack(rem)
			    local buf = rem2loc[ag][rembuf]
			    
			    local sx, sy = findCharPositionExact(spid)
			    local ex, ey = findCharPositionExact(epid)

			    if marks[other_agent] then
			      vim.api.nvim_buf_clear_namespace(marks[other_agent].buf, marks[other_agent].ns_id, 0, -1)
			      marks[other_agent] = nil
			    end

			    marks[other_agent] = {}
			    marks[other_agent].buf = buf
			    marks[other_agent].ns_id = vim.api.nvim_create_namespace("")
			    local scol = vim.str_byteindex(prev[sy-1], sx-1)
			    local ecol = vim.str_byteindex(prev[ey-1], ex-1)

			    for y=sy-1,ey-1 do
			      local lscol
			      if y == sy-1 then lscol = scol
			      else lscol = 0 end

			      local lecol
			      if y == ey-1 then lecol = ecol
			      else lecol = -1 end

			      vim.api.nvim_buf_add_highlight(
			        marks[other_agent].buf, 
			        marks[other_agent].ns_id, 
			        cursorGroup[client_hl_group[other_agent]],
			        y-1, lscol, lecol)
			    end

			    local aut = id2author[other_agent]

			    vim.api.nvim_buf_set_virtual_text(
			      buf, marks[other_agent].ns_id, 
			      sy-2, 
			      {{ aut, vtextGroup[client_hl_group[other_agent]] }}, 
			      {})

			    if follow and follow_aut == aut then
			    	local curbuf = vim.api.nvim_get_current_buf()
			    	if curbuf ~= buf then
			    		vim.api.nvim_set_current_buf(buf)
			    	end

			      local y = sy
			      vim.api.nvim_command("normal " .. (y-1) .. "gg")
			    end
			  end

			else
				error("Could not decode json " .. wsdata)
			end

		end,
		on_disconnect = function()
			for aut,_ in pairs(cursors) do
				if cursors[aut] then
					if attached[cursors[aut].buf] then
						vim.api.nvim_buf_clear_namespace(
							cursors[aut].buf, cursors[aut].id,
							0, -1)
					end
					cursors[aut] = nil
				end

				if old_namespace[aut] then
					if attached[old_namespace[aut].buf] then
						vim.api.nvim_buf_clear_namespace(
							old_namespace[aut].buf, old_namespace[aut].id,
							0, -1)
					end
					old_namespace[aut] = nil
				end

			end
			cursors = {}
			vim.api.nvim_command("augroup instantSession")
			vim.api.nvim_command("autocmd!")
			vim.api.nvim_command("augroup end")


			for bufhandle,_ in pairs(allprev) do
				if vim.api.nvim_buf_is_loaded(bufhandle) then
					DetachFromBuffer(bufhandle)
				end
			end

			agent = 0
			for _, o in pairs(api_attach) do
				if o.on_disconnect then
					o.on_disconnect()
				end
			end

			vim.schedule(function() print("Disconnected.") end)
		end
	}
end


function DetachFromBuffer(bufnr)
	detach[bufnr] = true
end


local function Start(host, port)
	if ws_client and ws_client:is_active() then
		error("Client is already connected. Use InstantStop first to disconnect.")
	end

  if not autocmd_init then
    vim.api.nvim_command("augroup instantUndo")
    vim.api.nvim_command("autocmd!")
    vim.api.nvim_command([[autocmd InsertLeave * lua require"instant".leave_insert()]])
    vim.api.nvim_command("augroup end")
    autocmd_init = true
  end


  local buf = vim.api.nvim_get_current_buf()
	singlebuf = buf
	local first = true
	sessionshare = false
	StartClient(first, host, port)


end

local function Join(host, port)
	if ws_client and ws_client:is_active() then
		error("Client is already connected. Use InstantStop first to disconnect.")
	end

  if not autocmd_init then
    vim.api.nvim_command("augroup instantUndo")
    vim.api.nvim_command("autocmd!")
    vim.api.nvim_command([[autocmd InsertLeave * lua require"instant".leave_insert()]])
    vim.api.nvim_command("augroup end")
    autocmd_init = true
  end


  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_buf(0, buf)

	singlebuf = buf
	local first = false
	sessionshare = false
	StartClient(first, host, port)

end

local function Stop()
	ws_client:disconnect()
	ws_client = nil

end


local function StartSession(host, port)
	if ws_client and ws_client:is_active() then
		error("Client is already connected. Use InstantStop first to disconnect.")
	end

  if not autocmd_init then
    vim.api.nvim_command("augroup instantUndo")
    vim.api.nvim_command("autocmd!")
    vim.api.nvim_command([[autocmd InsertLeave * lua require"instant".leave_insert()]])
    vim.api.nvim_command("augroup end")
    autocmd_init = true
  end


	local first = true
	sessionshare = true
	StartClient(first, host, port)

end

local function JoinSession(host, port)
	if ws_client and ws_client:is_active() then
		error("Client is already connected. Use InstantStop first to disconnect.")
	end

  if not autocmd_init then
    vim.api.nvim_command("augroup instantUndo")
    vim.api.nvim_command("autocmd!")
    vim.api.nvim_command([[autocmd InsertLeave * lua require"instant".leave_insert()]])
    vim.api.nvim_command("augroup end")
    autocmd_init = true
  end


	local first = false
	sessionshare = true
	StartClient(first, host, port)

end


local function Status()
	if ws_client and ws_client:is_active() then
		local positions = {}
		for _, aut in pairs(id2author) do 
			local c = cursors[aut]
			if c then
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

				table.insert(positions , {aut, bufname, line+1})
			else
				table.insert(positions , {aut, "", ""})
			end
		end

		local info_str = {}
		for _,pos in ipairs(positions) do
			table.insert(info_str, table.concat(pos, " "))
		end
		print("Connected. " .. #info_str .. " other client(s)\n\n" .. table.concat(info_str, "\n"))

	else
		print("Disconnected.")
	end
end

local function StartFollow(aut)
	follow = true
	follow_aut = aut
	print("Following " .. aut)
end

local function StopFollow()
	follow = false
	print("Following Stopped.")
end

local function SaveBuffers(force)
	local allbufs = vim.api.nvim_list_bufs()
	local bufs = {}
	-- skip terminal, help, ... buffers
	for _,buf in ipairs(allbufs) do
		local buftype = vim.api.nvim_buf_get_option(buf, "buftype")
		if buftype == "" then
			table.insert(bufs, buf)
		end
	end

	local i = 1
	while i < #bufs do
		local buf = bufs[i]
		local fullname = vim.api.nvim_buf_get_name(buf)

		if string.len(fullname) == 0 then
			table.remove(bufs, i)
		else
			i = i + 1
		end
	end

	for _,buf in ipairs(bufs) do
		local fullname = vim.api.nvim_buf_get_name(buf)

		local parentdir = vim.api.nvim_call_function("fnamemodify", { fullname, ":h" })
		local isdir = vim.api.nvim_call_function("isdirectory", { parentdir })
		if isdir == 0 then
			vim.api.nvim_call_function("mkdir", { parentdir, "p" } )
		end

		vim.api.nvim_command("b " .. buf)
		if force then
			vim.api.nvim_command("w!") -- write all
		else 
			vim.api.nvim_command("w") -- write all
		end

	end
end

function OpenBuffers()
	local all = vim.api.nvim_call_function("glob", { "**" })
	local files = {}
	if string.len(all) > 0 then
		for path in vim.gsplit(all, "\n") do
			local isdir = vim.api.nvim_call_function("isdirectory", { path })
			if isdir == 0 then
				table.insert(files, path)
			end
		end
	end
	local num_files = 0
	for _,file in ipairs(files) do
		vim.api.nvim_command("args " .. file)
		num_files = num_files + 1 
	end
	print("Opened " .. num_files .. " files.")
end


local function undo(buf)
	if undosp[buf] == 0 then
		print("Already at oldest change.")
		return
	end
	local ops = undostack[buf][undosp[buf]]
	local rev_ops = {}
	for i=#ops,1,-1 do
	  table.insert(rev_ops, ops[i])
	end
	ops = rev_ops

	-- quick hack to avoid bug when first line is
	-- restored. The newlines are stored at
	-- the beginning. Because the undo will reverse
	-- the inserted character, it can happen that
	-- character are entered before any newline
	-- which will error. To avoid the last op is 
	-- swapped with first
	local lowest = nil
	local firstpid = allpids[buf][2][1]
	for i,op in ipairs(ops) do
	  if op[1] == OP_TYPE.INS and isLowerOrEqual(op[3], firstpid) then
	    lowest = i
	    break
	  end
	end

	if lowest then
	  ops[lowest], ops[1] = ops[1], ops[lowest]
	end

	undosp[buf] = undosp[buf] - 1


	disable_undo = true
	local other_rem, other_agent = loc2rem[buf], agent
	local lastPID
	for _, op in ipairs(ops) do
		if op[1] == OP_TYPE.INS then
			op = { OP_TYPE.DEL, op[3], op[2] }

		elseif op[1] == OP_TYPE.DEL then
			op = { OP_TYPE.INS, op[3], op[2] }

		end

		local opline = 0
		local opcol = 0

		local ag, bufid = unpack(other_rem)
		buf = rem2loc[ag][bufid]

		prev = allprev[buf]
		pids = allpids[buf]

		local tick = vim.api.nvim_buf_get_changedtick(buf)+1
		ignores[buf][tick] = true

		if op[1] == OP_TYPE.INS then
			lastPID = op[3]

			local x, y = findCharPositionBefore(op[3])

			if op[2] == "\n" then
				opline = y-1
			else
				opline = y-2
			end
			opcol = x

			if op[2] == "\n" then 
				local py, py1 = splitArray(pids[y], x+1)
				pids[y] = py
				table.insert(py1, 1, op[3])
				table.insert(pids, y+1, py1)
			else table.insert(pids[y], x+1, op[3] ) end

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


		elseif op[1] == OP_TYPE.DEL then
			lastPID = findPIDBefore(op[2])

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
		local aut = id2author[other_agent]

		if lastPID and other_agent ~= agent then
			local x, y = findCharPositionExact(lastPID)

			if old_namespace[aut] then
				if attached[old_namespace[aut].buf] then
					vim.api.nvim_buf_clear_namespace(
						old_namespace[aut].buf, old_namespace[aut].id,
						0, -1)
				end
				old_namespace[aut] = nil
			end

			if cursors[aut] then
				if attached[cursors[aut].buf] then
					vim.api.nvim_buf_clear_namespace(
						cursors[aut].buf, cursors[aut].id,
						0, -1)
				end
				cursors[aut] = nil
			end

			if x then
				if x == 1 then x = 2 end
				old_namespace[aut] = {
					id = vim.api.nvim_buf_set_virtual_text(
						buf, 0, 
						math.max(y-2, 0), 
						{{ aut, vtextGroup[client_hl_group[other_agent]] }}, 
						{}),
					buf = buf
				}

				if prev[y-1] and x-2 >= 0 and x-2 <= utf8len(prev[y-1]) then
					local bx = vim.str_byteindex(prev[y-1], x-2)
					cursors[aut] = {
						id = vim.api.nvim_buf_add_highlight(buf,
							0, cursorGroup[client_hl_group[other_agent]], y-2, bx, bx+1),
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
			if follow and follow_aut == aut then
				local curbuf = vim.api.nvim_get_current_buf()
				if curbuf ~= buf then
					vim.api.nvim_set_current_buf(buf)
				end

				vim.api.nvim_command("normal " .. (y-1) .. "gg")
			end


			for _, o in pairs(api_attach) do
				if o.on_change then
					o.on_change(aut, buf, y-2)
				end
			end

		end
		-- @check_if_pid_match_with_prev

		SendOp(buf, op)

	end
	disable_undo = false
	if lastPID then
		local x, y = findCharPositionExact(lastPID)

		if prev[y-1] and x-2 >= 0 and x-2 <= utf8len(prev[y-1]) then
			local bx = vim.str_byteindex(prev[y-1], x-2)
			vim.api.nvim_call_function("cursor", { y-1, bx+1 })
		end
	end

end

local function redo(buf)
	if undosp[buf] == #undostack[buf] then
		print("Already at newest change")
		return
	end

	undosp[buf] = undosp[buf]+1

	if undosp[buf] == 0 then
		print("Already at oldest change.")
		return
	end
	local ops = undostack[buf][undosp[buf]]
	local rev_ops = {}
	for i=#ops,1,-1 do
	  table.insert(rev_ops, ops[i])
	end
	ops = rev_ops

	-- quick hack to avoid bug when first line is
	-- restored. The newlines are stored at
	-- the beginning. Because the undo will reverse
	-- the inserted character, it can happen that
	-- character are entered before any newline
	-- which will error. To avoid the last op is 
	-- swapped with first
	local lowest = nil
	local firstpid = allpids[buf][2][1]
	for i,op in ipairs(ops) do
	  if op[1] == OP_TYPE.INS and isLowerOrEqual(op[3], firstpid) then
	    lowest = i
	    break
	  end
	end

	if lowest then
	  ops[lowest], ops[1] = ops[1], ops[lowest]
	end

	local other_rem, other_agent = loc2rem[buf], agent
	disable_undo = true
	local lastPID
	for _, op in ipairs(ops) do
		local opline = 0
		local opcol = 0

		local ag, bufid = unpack(other_rem)
		buf = rem2loc[ag][bufid]

		prev = allprev[buf]
		pids = allpids[buf]

		local tick = vim.api.nvim_buf_get_changedtick(buf)+1
		ignores[buf][tick] = true

		if op[1] == OP_TYPE.INS then
			lastPID = op[3]

			local x, y = findCharPositionBefore(op[3])

			if op[2] == "\n" then
				opline = y-1
			else
				opline = y-2
			end
			opcol = x

			if op[2] == "\n" then 
				local py, py1 = splitArray(pids[y], x+1)
				pids[y] = py
				table.insert(py1, 1, op[3])
				table.insert(pids, y+1, py1)
			else table.insert(pids[y], x+1, op[3] ) end

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


		elseif op[1] == OP_TYPE.DEL then
			lastPID = findPIDBefore(op[2])

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
		local aut = id2author[other_agent]

		if lastPID and other_agent ~= agent then
			local x, y = findCharPositionExact(lastPID)

			if old_namespace[aut] then
				if attached[old_namespace[aut].buf] then
					vim.api.nvim_buf_clear_namespace(
						old_namespace[aut].buf, old_namespace[aut].id,
						0, -1)
				end
				old_namespace[aut] = nil
			end

			if cursors[aut] then
				if attached[cursors[aut].buf] then
					vim.api.nvim_buf_clear_namespace(
						cursors[aut].buf, cursors[aut].id,
						0, -1)
				end
				cursors[aut] = nil
			end

			if x then
				if x == 1 then x = 2 end
				old_namespace[aut] = {
					id = vim.api.nvim_buf_set_virtual_text(
						buf, 0, 
						math.max(y-2, 0), 
						{{ aut, vtextGroup[client_hl_group[other_agent]] }}, 
						{}),
					buf = buf
				}

				if prev[y-1] and x-2 >= 0 and x-2 <= utf8len(prev[y-1]) then
					local bx = vim.str_byteindex(prev[y-1], x-2)
					cursors[aut] = {
						id = vim.api.nvim_buf_add_highlight(buf,
							0, cursorGroup[client_hl_group[other_agent]], y-2, bx, bx+1),
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
			if follow and follow_aut == aut then
				local curbuf = vim.api.nvim_get_current_buf()
				if curbuf ~= buf then
					vim.api.nvim_set_current_buf(buf)
				end

				vim.api.nvim_command("normal " .. (y-1) .. "gg")
			end


			for _, o in pairs(api_attach) do
				if o.on_change then
					o.on_change(aut, buf, y-2)
				end
			end

		end
		-- @check_if_pid_match_with_prev

		SendOp(buf, op)

	end
	disable_undo = false
	if lastPID then
		local x, y = findCharPositionExact(lastPID)

		if prev[y-1] and x-2 >= 0 and x-2 <= utf8len(prev[y-1]) then
			local bx = vim.str_byteindex(prev[y-1], x-2)
			vim.api.nvim_call_function("cursor", { y-1, bx+1 })
		end
	end

end


local function attach(callbacks)
	local o = {}
	for name, fn in pairs(callbacks) do
		if name == "on_connect" then
			o.on_connect = callbacks.on_connect

		elseif name == "on_disconnect" then
			o.on_disconnect = callbacks.on_disconnect

		elseif name == "on_change" then
			o.on_change = callbacks.on_change

		elseif name == "on_clientconnected" then
			o.on_clientconnected = callbacks.on_clientconnected

		elseif name == "on_clientdisconnected" then
			o.on_clientdisconnected = callbacks.on_clientdisconnected

		elseif name == "on_data" then
			o.on_data = callbacks.on_data

		else 
			error("[instant.nvim] Unknown callback " .. name)
		end
	end
	api_attach[api_attach_id] = o
	api_attach_id = api_attach_id + 1
	return api_attach_id
end

local function detach(id)
	if not api_attach[id] then
		error("[instant.nvim] Could not detach (already detached?")
	end
	api_attach[id] = nil
end

local function get_connected_list()
	local connected = {}
	for _, aut in pairs(id2author) do
		table.insert(connected, aut)
	end
	return connected
end

local function send_data(data)
	local obj = {
		MSG_TYPE.DATA,
		data
	}

local encoded = vim.api.nvim_call_function("json_encode", { obj })
	ws_client:send_text(encoded)

end

local function get_connected_buf_list()
	local bufs = {}
	for buf, _ in pairs(loc2rem) do
		table.insert(bufs, buf)
	end
	return bufs
end


return {
attach = attach,

detach = detach,

get_connected_list = get_connected_list,

send_data = send_data,

get_connected_buf_list = get_connected_buf_list,
StartFollow = StartFollow,
StopFollow = StopFollow,

Start = Start,
Join = Join,
Stop = Stop,

StartSession = StartSession,
JoinSession = JoinSession,

undo = undo,

redo = redo,

leave_insert = leave_insert,

MarkRange = MarkRange,

MarkClear = MarkClear,

SaveBuffers = SaveBuffers,

OpenBuffers = OpenBuffers,

Status = Status,

}

