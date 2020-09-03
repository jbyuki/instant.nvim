local b

local function a()
	b()
	print("a")
end

local function b()
	print("b")
end

return {
	a = a
}
