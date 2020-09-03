local plugvim = io.open("plugin/ntrance.vim", "w")
for line in io.lines("src/tangle/ntrance.vim") do
	plugvim:write(line .. '\n')
end

