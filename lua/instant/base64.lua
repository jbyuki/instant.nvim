-- Generated using ntangle.nvim
local bit = require("bit")

local b64enc = {}

local b64dec = {}

local b64 = 0
for i=string.byte('A'), string.byte('Z') do b64enc[b64] = string.char(i) b64 = b64+1 end
for i=string.byte('a'), string.byte('z') do b64enc[b64] = string.char(i) b64 = b64+1 end
for i=string.byte('0'), string.byte('9') do b64enc[b64] = string.char(i) b64 = b64+1 end
b64enc[b64] = '+' b64 = b64+1
b64enc[b64] = '/'

local b64i = 0
for c=string.byte('A'),string.byte('Z') do 
	b64dec[string.char(c)]=b64i b64i = b64i+1 
end
for c=string.byte('a'),string.byte('z') do 
	b64dec[string.char(c)]=b64i b64i = b64i+1 
end
for c=string.byte('0'),string.byte('9') do 
	b64dec[string.char(c)]=b64i b64i = b64i+1 
end
b64dec['+'] = b64i b64i = b64i+1
b64dec['/'] = b64i

local function encode(array)
	local i
	local str = ""
	for i=0,#array-3,3 do
		local b1 = array[i+0+1]
		local b2 = array[i+1+1]
		local b3 = array[i+2+1]

		local c1 = bit.rshift(b1, 2)
		local c2 = bit.lshift(bit.band(b1, 0x3), 4)+bit.rshift(b2, 4)
		local c3 = bit.lshift(bit.band(b2, 0xF), 2)+bit.rshift(b3, 6)
		local c4 = bit.band(b3, 0x3F)

		str = str .. b64enc[c1]
		str = str .. b64enc[c2]
		str = str .. b64enc[c3]
		str = str .. b64enc[c4]
	end

	local rest = #array * 8 - #str * 6
	if rest == 8 then
		local b1 = array[#array]

		local c1 = bit.rshift(b1, 2)
		local c2 = bit.lshift(bit.band(b1, 0x3), 4)

		str = str .. b64enc[c1]
		str = str .. b64enc[c2]
		str = str .. "="
		str = str .. "="

	elseif rest == 16 then
		local b1 = array[#array-1]
		local b2 = array[#array]

		local c1 = bit.rshift(b1, 2)
		local c2 = bit.lshift(bit.band(b1, 0x3), 4)+bit.rshift(b2, 4)
		local c3 = bit.lshift(bit.band(b2, 0xF), 2)

		str = str .. b64enc[c1]
		str = str .. b64enc[c2]
		str = str .. b64enc[c3]
		str = str .. "="
	end


	return str
end


local function decode(str)
	local buffer = {}
	for j=1,string.len(str),4 do
		local new_data = {}
		local padding = 0

		for k=0,3 do
			local c = string.sub(str, j+k, j+k)
			if c ~= "=" then
				table.insert(new_data, b64dec[c])
			else
				padding = padding + 1
				table.insert(new_data, 0)
			end
		end


		table.insert(buffer, bit.bor(bit.lshift(new_data[1], 2), bit.band(bit.rshift(new_data[2], 4), 0x3)))

		if padding <= 1 then
			table.insert(buffer, bit.bor(bit.lshift(bit.band(new_data[2], 0xF), 4), bit.rshift(new_data[3], 2)))
		end

		if padding == 0 then
			table.insert(buffer, bit.bor(bit.lshift(bit.band(new_data[3], 0x3), 6), new_data[4]))
		end
	end
	return buffer
end


return {
	encode = encode,

	decode = decode,

}

