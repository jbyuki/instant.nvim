haha = {}
detach = false
vim.api.nvim_buf_attach(59, false, {
	on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
		table.insert(haha, changedtick .. " " .. firstline .. " " .. lastline)
		if detach then
			return true
		end
	end
})
