@*=
@requres
@script_variables
@copy_files

@copy_files+=
local plugvim = io.open("plugin/instant.vim", "w")
for line in io.lines("src/tangle/instant.vim") do
	plugvim:write(line .. '\n')
end
plugvim:close()

local pluglua = io.open("lua/instant.lua", "w")
for line in io.lines("src/tangle/instant.lua") do
	pluglua:write(line .. '\n')
end
pluglua:close()

local plugjs = io.open("server/ws_server.js", "w")
for line in io.lines("src/tangle/ws_server.js") do
	plugjs:write(line .. '\n')
end
plugjs:close()
