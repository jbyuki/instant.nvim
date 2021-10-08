-- Generated using ntangle.nvim
local bit = require("bit")

function from8to32(b1, b2, b3, b4)
	return bit.lshift(b1, 24) + bit.lshift(b2, 16)
		+ bit.lshift(b3, 8) + bit.lshift(b4, 0)
end

function S(n, X)
	return bit.bor(bit.lshift(X, n), bit.rshift(X, 32-n))
end

function f(t, B, C, D)
	if t >= 0 and t < 20 then
		return bit.bor(bit.band(B, C), bit.band(bit.bnot(B), D))
	elseif t >= 20 and t < 40 then
		return bit.bxor(B, bit.bxor(C, D))
	elseif t >= 40 and t < 60 then
		return bit.bor(bit.band(B, C), bit.bor(bit.band(B, D), bit.band(C, D)))
	elseif t >= 60 and t < 80 then
		return bit.bxor(B, bit.bxor(C, D))
	end
end

function K(t)
	if t >= 0 and t < 20 then return 0x5A827999
	elseif t >= 20 and t < 40 then return 0x6ED9EBA1
	elseif t >= 40 and t < 60 then return 0x8F1BBCDC
	elseif t >= 60 and t < 80 then return 0xCA62C1D6
	end
end


function sha1(bytes)
	local len = {}
	local bytes_len = #bytes*8

	for i=1,8 do
		table.insert(len, bit.band(bytes_len, 0xFF))
		bytes_len = bit.rshift(bytes_len, 8)
	end

	local remain = (64 - (#bytes % 64)) % 64
	for i=64-remain+1,64 do
		local byte = 0
		if i == 64-remain+1 then byte = 0x80 end
		if 64-i < 8 then
			byte = bit.bor(byte, len[64-i+1])
		end
		table.insert(bytes, byte)
	end

	local H = {
		0x67452301,
		0xEFCDAB89,
		0x98BADCFE,
		0x10325476,
		0xC3D2E1F0
	}

	local W = {}
	for i = 1,#bytes,64 do
		for j=0,15 do
			W[j] = from8to32(
				bytes[i+4*j+0], bytes[i+4*j+1], 
				bytes[i+4*j+2], bytes[i+4*j+3])
		end

		for t=16,79 do
			W[t] = S(1, bit.bxor(bit.bxor(W[t-3], W[t-9]), bit.bxor(W[t-14], W[t-16])))
		end

		local A, B, C, D, E = unpack(H)

		for t=0,79 do
			local TEMP = S(5, A) + f(t, B, C, D) + E + W[t] + K(t)
			E = D   D = C   C = S(30, B)   B = A    A = TEMP
		end

		H[1] = H[1]+A
		H[2] = H[2]+B
		H[3] = H[3]+C
		H[4] = H[4]+D
		H[5] = H[5]+E

	end

	local digest = {}
	for i=1,5 do
		table.insert(digest, bit.band(bit.rshift(H[i], 24), 0xFF))
		table.insert(digest, bit.band(bit.rshift(H[i], 16), 0xFF))
		table.insert(digest, bit.band(bit.rshift(H[i],  8), 0xFF))
		table.insert(digest, bit.band(bit.rshift(H[i],  0), 0xFF))
	end
	return digest
end


return sha1

