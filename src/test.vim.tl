@*=
function! Init()
	let b:list = []
	let b:list = add(b:list, a:i)
	for el in b:list
		echo el
	endfor
endfunction
