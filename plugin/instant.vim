" Vim global plugin for remote collaborative editing
" Creation Date: 2020 Sep 3
" Maintainer:  jbyuki
" License:     MIT

let s:save_cpo = &cpo
set cpo&vim

if exists("g:loaded_instant")
	finish
endif
let g:loaded_instant = 1

command! -nargs=* InstantStartSingle call instant#StartSingleWrapper(<f-args>)

command! -nargs=* InstantJoinSingle call instant#JoinSingleWrapper(<f-args>)

command! InstantStatus call luaeval('require("instant").Status()')

command! -nargs=* InstantStopSingle call luaeval('require("instant").Stop()')
let &cpo = s:save_cpo
unlet s:save_cpo


