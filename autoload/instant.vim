function instant#StartSingleWrapper(...)
	if a:0 == 0 || a:0 > 2
		echoerr "ARGUMENTS: [host] [port (default: 80)]"
		return
	endif

	if a:0 == 1
		call luaeval('require("instant").Start("' .. a:1 .. '")')
	else
		call luaeval('require("instant").Start("' .. a:1 .. '", ' .. a:2 .. ')')
	endif
endfunction

function instant#JoinSingleWrapper(...)
	if a:0 == 0 || a:0 > 2
		echoerr "ARGUMENTS: [host] [port (default: 80)]"
		return
	endif

	if a:0 == 1
		call luaeval('require("instant").Join("' .. a:1 .. '")')
	else
		call luaeval('require("instant").Join("' .. a:1 .. '", ' .. a:2 .. ')')
	endif
endfunction
