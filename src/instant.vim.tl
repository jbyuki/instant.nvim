@../plugin/instant.vim=
@header
@save_line_continuation
@plugin_load_guard
@requires
@register_commands
@restore_line_continuation

@header+=
" Vim global plugin for remote collaborative editing
" Creation Date: 2020 Sep 3
" Maintainer:  jbyuki
" License:     MIT

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

@register_commands+=
command! -nargs=* InstantStartSingle call instant#StartSingleWrapper(<f-args>)

@register_commands+=
command! -nargs=* InstantJoinSingle call instant#JoinSingleWrapper(<f-args>)

@register_commands+=
command! InstantStatus call luaeval('require("instant").Status()')

@register_commands+=
command! -nargs=* InstantStop call luaeval('require("instant").Stop()')

@register_commands+=
command! -nargs=* InstantStartSession call instant#StartSessionWrapper(<f-args>)

@register_commands+=
command! -nargs=* InstantJoinSession call instant#JoinSessionWrapper(<f-args>)

@register_commands+=
command! -nargs=* InstantFollow call instant#StartFollowWrapper(<f-args>)

@register_commands+=
command! InstantStopFollow call instant#StopFollowWrapper()
