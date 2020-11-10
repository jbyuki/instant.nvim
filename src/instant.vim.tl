@*=
@header
@save_line_continuation
@plugin_load_guard
@requires
@script_variables
@functions
@register_commands
@restore_line_continuation

@header+=
" Vim global plugin for remote collaborative editing
" Creation Date: 2020 Sep 3
" Maintainer:  jbyuki
" License:     This file is placed in the public domain 

@save_line_continuation+=
let s:save_cpo = &cpo
set cpo&vim

@restore_line_continuation+=
let &cpo = s:save_cpo
unlet s:save_cpo

@plugin_load_guard+=
if exists("g:loaded_instant")
	finish
endif
let g:loaded_instant = 1

@requires+=
lua instant = require("instant")

@functions+=
function! StartSingleWrapper(...)
	if a:0 == 0 || a:0 > 2
		echoerr "ARGUMENTS: [host] [port (default: 80)]"
		return
	endif

	if a:0 == 1
		call execute('lua instant.Start(true, true, "' .. a:1 .. '")')
	else
		call execute('lua instant.Start(true, true, "' .. a:1 .. '", ' .. a:2 .. ')')
	endif
endfunction

@register_commands+=
command! -nargs=* InstantStartSingle call StartSingleWrapper(<f-args>)

@functions+=
function! JoinSingleWrapper(...)
	if a:0 == 0 || a:0 > 2
		echoerr "ARGUMENTS: [host] [port (default: 80)]"
		return
	endif

	if a:0 == 1
		call execute('lua instant.Start(false, true, "' .. a:1 .. '")')
	else
		call execute('lua instant.Start(false, true, "' .. a:1 .. '", ' .. a:2 .. ')')
	endif
endfunction

@register_commands+=
command! -nargs=* InstantJoinSingle call JoinSingleWrapper(<f-args>)

@register_commands+=
command! InstantStatus call execute('lua instant.Status()', "")

@register_commands+=
command! -nargs=* InstantStopSingle  call execute('lua instant.Stop()', "")
