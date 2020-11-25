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

command! -nargs=* InstantStop call luaeval('require("instant").Stop()')

command! -nargs=* InstantStartSession call instant#StartSessionWrapper(<f-args>)

command! -nargs=* InstantJoinSession call instant#JoinSessionWrapper(<f-args>)

command! -nargs=* InstantFollow call instant#StartFollowWrapper(<f-args>)

command! InstantStopFollow call instant#StopFollowWrapper()

command! -bang InstantSaveAll call instant#SaveAllWrapper(<bang>0)

command! InstantOpenAll call luaeval('require("instant").OpenBuffers()')

command! InstantStartServer call luaeval('require("instant").StartServer()')
let &cpo = s:save_cpo
unlet s:save_cpo


