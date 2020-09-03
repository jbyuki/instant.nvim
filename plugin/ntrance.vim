" Vim global plugin for remote collaborative editing
" Last Change: 2020 Sep 3
" Maintainer:  jbyuki
" License:     This file is placed in the public domain 

let s:save_cpo = &cpo
set cpo&vim

if exists("g:loaded_ntrance")
	finish
endif
let g:loaded_ntrance = 1

lua ntrance = require("ntrance")

function! StartWrapper(...)
	if a:0 == 0 || a:0 > 2
		echoerr "ARGUMENTS: [host] [port (default: 80)]"
		return
	endif

	if a:0 == 1
		call execute('lua ntrance.Start(true, "' .. a:1 .. '")')
	else
		call execute('lua ntrance.Start(true, "' .. a:1 .. '", ' .. a:2 .. ')')
	endif
endfunction

function! JoinWrapper(...)
	if a:0 == 0 || a:0 > 2
		echoerr "ARGUMENTS: [host] [port (default: 80)]"
		return
	endif

	if a:0 == 1
		call execute('lua ntrance.Start(false, "' .. a:1 .. '")')
	else
		call execute('lua ntrance.Start(false, "' .. a:1 .. '", ' .. a:2 .. ')')
	endif
endfunction

command! -nargs=* NTranceStart call StartWrapper(<f-args>)
command! NTranceStop lua ntrance.Stop()

command! -nargs=* NTranceJoin call JoinWrapper(<f-args>)
let &cpo = s:save_cpo
unlet s:save_cpo


