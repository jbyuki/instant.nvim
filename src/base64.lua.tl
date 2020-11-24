@../lua/instant/base64.lua=

@requires
@script_variables
@fill_base64_table
@functions

@encode
-- only encode, decode is not used

return {
	@export_symbols
}

@script_variables+=
local base64 = {}

@fill_base64_table+=
local b64 = 0
for i=string.byte('a'), string.byte('z') do base64[b64] = string.char(i) b64 = b64+1 end
for i=string.byte('A'), string.byte('Z') do base64[b64] = string.char(i) b64 = b64+1 end
for i=string.byte('0'), string.byte('9') do base64[b64] = string.char(i) b64 = b64+1 end
base64[b64] = '+' b64 = b64+1
base64[b64] = '/'

@export_symbols+=
encode = encode,

@functions+=
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

		str = str .. base64[c1]
		str = str .. base64[c2]
		str = str .. base64[c3]
		str = str .. base64[c4]
	end

	@add_padding_characters_to_24_multiple

	return str
end

@add_padding_characters_to_24_multiple+=
local rest = #array * 8 - #str * 6
if rest == 8 then
	local b1 = array[#array]

	local c1 = bit.rshift(b1, 2)
	local c2 = bit.lshift(bit.band(b1, 0x3), 4)

	str = str .. base64[c1]
	str = str .. base64[c2]
	str = str .. "="
	str = str .. "="

elseif rest == 16 then
	local b1 = array[#array-1]
	local b2 = array[#array]

	local c1 = bit.rshift(b1, 2)
	local c2 = bit.lshift(bit.band(b1, 0x3), 4)+bit.rshift(b2, 4)
	local c3 = bit.lshift(bit.band(b2, 0xF), 2)

	str = str .. base64[c1]
	str = str .. base64[c2]
	str = str .. base64[c3]
	str = str .. "="
end
