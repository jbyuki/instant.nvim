-- Generated using ntangle.nvim

msgs = {}

function HasMessage(str)
	for _, msg in ipairs(msgs) do
		if msg == str then
			return true
		end
	end
	return false
end

function SendTestData()
	require("instant").send_data("hello")
end

function GetConnectedList()
	return require("instant").get_connected_list()
end

function GetConnectedBufList()
	return require("instant").get_connected_buf_list()
end

require("instant").attach {
	on_connect = function()
		table.insert(msgs, "connect")
	end,

	on_disconnect = function()
		table.insert(msgs, "disconnect")
	end,

	on_clientconnected = function(user)
		table.insert(msgs, "in " .. user)
	end,

	on_clientdisconnected = function(user)
		table.insert(msgs, "out " .. user)
	end,

	on_data = function(data)
		table.insert(msgs, "data " .. data)
	end,

	on_change = function(aut, buf, line)
		table.insert(msgs, "change " .. table.concat({aut, line}, " "))
	end,

}


