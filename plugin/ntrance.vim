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
let &cpo = s:save_cpo
unlet s:save_cpo


