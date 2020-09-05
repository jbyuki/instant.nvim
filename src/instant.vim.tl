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
" Last Change: 2020 Sep 3
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
function! StartWrapper(...)
	if a:0 == 0 || a:0 > 2
		echoerr "ARGUMENTS: [host] [port (default: 80)]"
		return
	endif

	if a:0 == 1
		call execute('lua instant.Start(true, "' .. a:1 .. '")')
	else
		call execute('lua instant.Start(true, "' .. a:1 .. '", ' .. a:2 .. ')')
	endif
endfunction

@register_commands+=
command! -nargs=* InstantStart call StartWrapper(<f-args>)
command! InstantStop lua instant.Stop()

@functions+=
function! JoinWrapper(...)
	if a:0 == 0 || a:0 > 2
		echoerr "ARGUMENTS: [host] [port (default: 80)]"
		return
	endif

	if a:0 == 1
		call execute('lua instant.Start(false, "' .. a:1 .. '")')
	else
		call execute('lua instant.Start(false, "' .. a:1 .. '", ' .. a:2 .. ')')
	endif
endfunction

@register_commands+=
command! -nargs=* InstantJoin call JoinWrapper(<f-args>)

@register_commands+=
command! InstantRefresh lua instant.Refresh()

@register_commands+=
augroup instant
	autocmd!
	autocmd BufReadPost,BufWritePost * lua instant.AttachToBuffer()
	autocmd ExitPre * lua instant.Stop()
augroup END

