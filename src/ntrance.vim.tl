@*=
@header
@save_line_continuation
@plugin_load_guard
@script_variables
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
