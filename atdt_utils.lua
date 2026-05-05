--- @class ATDTUtils
local atdt_utils = {}

--- @param str string
--- @return number
function atdt_utils.hash_of(str)
	local hash = 0

	for i = 1, #str do
		local charCode = string.byte(str, i)
		hash = (hash * 739 + charCode) % 433494437
	end

	return hash
end

---@param a number
---@param b number
---@return number
function atdt_utils.hash_sum(a, b)
	return (a * 739 + b) % 433494437
end

--- @class RNG
--- @field x number
--- @field a number
--- @field b number
--- @field m number

--- @param seed number
--- @return RNG
function atdt_utils.new_rng(seed)
	return {
		x = seed,
		a = 16807,
		b = 1,
		m = 2 ^ 31 - 1,
	}
end

--- @param state RNG
--- @return number
function atdt_utils.next_rng(state)
	state.x = (state.x * state.a + state.b) % state.m
	return state.x / state.m
end

--- Return random float in range [min, max)
--- @param state RNG
--- @param min number
--- @param max number
--- @return number
function atdt_utils.next_rng_range(state, min, max)
	return min + (max - min) * atdt_utils.next_rng(state)
end

function atdt_utils.hsv2rgb(h, s, v)
	local C = v * s
	local m = v - C
	local r, g, b = m, m, m
	if h == h then
		local h_ = (h % 1.0) * 6
		local X = C * (1 - math.abs(h_ % 2 - 1))
		C, X = C + m, X + m
		if h_ < 1 then
			r, g, b = C, X, m
		elseif h_ < 2 then
			r, g, b = X, C, m
		elseif h_ < 3 then
			r, g, b = m, C, X
		elseif h_ < 4 then
			r, g, b = m, X, C
		elseif h_ < 5 then
			r, g, b = X, m, C
		else
			r, g, b = C, m, X
		end
	end
	return r, g, b
end

--- @generic T
--- @param items T[]|T[][]|T[][][]|T[][][][]
--- @return T[]
function atdt_utils.flatten(items)
	local stack = { table.unpack(items) }
	local res = {}
	while #stack > 0 do
		local elem = table.remove(stack, #stack)
		if elem ~= nil and #elem > 0 then
			for _, item in pairs(elem) do
				stack[#stack + 1] = item
			end
		else
			res[#res + 1] = elem
		end
	end
	return res
end

--- @generic T
--- @param vec {x: T, y: T} | [T, T]
--- @return T
--- @return T
function atdt_utils.vec_xy(vec)
	if vec.x ~= nil then
		return vec.x, vec.y
	else
		return vec[1], vec[2]
	end
end

function atdt_utils.round_to_nearest(num, step)
	return math.floor(num / step + 0.5) * step
end

return atdt_utils
