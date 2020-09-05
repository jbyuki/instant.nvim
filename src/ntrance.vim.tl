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
if exists("g:loaded_ntrance")
	finish
endif
let g:loaded_ntrance = 1

@requires+=
lua ntrance = require("ntrance")

@functions+=
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

@register_commands+=
command! -nargs=* NTranceStart call StartWrapper(<f-args>)
command! NTranceStop lua ntrance.Stop()

@functions+=
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

@register_commands+=
command! -nargs=* NTranceJoin call JoinWrapper(<f-args>)

@register_commands+=
command! NTranceRefresh lua ntrance.Refresh()

@register_commands+=
augroup ntrance
	autocmd!
	autocmd BufReadPost,BufWritePost * lua ntrance.AttachToBuffer()
	autocmd ExitPre * lua ntrance.Stop()
augroup END

