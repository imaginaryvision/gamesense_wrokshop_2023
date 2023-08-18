local ffi = require("ffi")

local function clamp(x, min, max)
	if x < min then return min end
	if x > max then return max end

	return x
end

local function color_clamp(r, g, b, a)
	return clamp(r, 0, 255), clamp(g, 0, 255), clamp(b, 0, 255), clamp(a, 0, 255)
end

local function color_round(num)
	return (num + 0.5) - ((num + 0.5) % 1)
end

local function set_default_color_values(r, g, b, a, fraction)
	local val = fraction and 1 or 255
	if r == nil then
		r, g, b, a = val, val, val, val
	elseif g == nil then
		g, b, a = r, r, val
	elseif b == nil then
		g, b, a = r, r, g
	elseif a == nil then
		a = val
	end

	if fraction then
		r, g, b, a = r * 255, g * 255, b * 255, a * 255
	end

	return color_clamp(color_round(r), color_round(g), color_round(b), color_round(a))
end

local function hex_to_rgba(hex)
	if hex:sub(1, 1) == "#" then
		hex = hex:sub(2)
	end

	local r = tonumber(hex:sub(1, 2), 16)
	local g = tonumber(hex:sub(3, 4), 16)
	local b = tonumber(hex:sub(5, 6), 16)
	local a = tonumber(hex:sub(7, 8), 16)

	return r, g, b, a
end

local function hue2rgb(p, q, t)
	if t < 0 then t = t + 1 end
	if t > 1 then t = t - 1 end
	if t < 1 / 6 then return p + (q - p) * 6 * t end
	if t < 1 / 2 then return q end
	if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
	return p
end

local function hsl_to_rgba(h, s, l, a)
	local r, g, b

	if s == 0 then
		r, g, b = l, l, l
	else
		local q = (l < 0.5) and (l * (1 + s)) or (l + s - l * s)
		local p = 2 * l - q

		r = hue2rgb(p, q, h + 1 / 3)
		g = hue2rgb(p, q, h)
		b = hue2rgb(p, q, h - 1 / 3)
	end

	return r * 255, g * 255, b * 255, a
end

local function hsv_to_rgba(h, s, v, a)
	local r, g, b

	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)

	i = i % 6

	if i == 0 then
		r, g, b = v, t, p
	elseif i == 1 then
		r, g, b = q, v, p
	elseif i == 2 then
		r, g, b = p, v, t
	elseif i == 3 then
		r, g, b = p, q, v
	elseif i == 4 then
		r, g, b = t, p, v
	elseif i == 5 then
		r, g, b = v, p, q
	end

	return r * 255, g * 255, b * 255, a
end

local function rgba_to_hex(r, g, b, a)
	return string.format("%02x%02x%02x%02x", r, g, b, a)
end

local function rgba_to_hsl(r, g, b, a)
	r, g, b = r / 255, g / 255, b / 255
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local h, s, l = (max + min) / 2, 0, (max + min) / 2

	if max ~= min then
		local d = max - min
		s = l > 0.5 and d / (2 - max - min) or d / (max + min)
		if max == r then
			h = (g - b) / d + (g < b and 6 or 0)
		elseif max == g then
			h = (b - r) / d + 2
		elseif max == b then
			h = (r - g) / d + 4
		end
		h = h / 6
	end

	return h, s, l, a
end

local function rgba_to_hsv(r, g, b, a)
	r, g, b = r / 255, g / 255, b / 255
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local h, s, v = max, max == 0 and 0 or (max - min) / max, max

	if max ~= min then
		local d = max - min
		if max == r then
			h = (g - b) / d + (g < b and 6 or 0)
		elseif max == g then
			h = (b - r) / d + 2
		elseif max == b then
			h = (r - g) / d + 4
		end
		h = h / 6
	end

	return h, s, v, a
end

local function verify_color_table(colors)
	if type(colors[1]) ~= "table" then
		local stops = 1 / (#colors - 1)
		for k, v in ipairs(colors) do
			colors[k] = {v, (k - 1) * stops}
		end
	end

	if #colors < 2 then error("2 or more colors required!") end
	if colors[1][2] ~= 0 then error("First color must start at position 0!") end
	if colors[#colors][2] ~= 1 then
		error("Last color must end at position 1!")
	end

	local max = 0
	for k, v in ipairs(colors) do
		local stop = v[2]
		if not stop then error("Color doesn't have a stop property!") end
		if stop < 0 or stop > 1 then error("Color stop is out of boundaries!") end
		if stop >= max then
			max = stop
		else
			error("Color stops are out of order!")
		end
	end

	return colors
end

local color_t = ffi.typeof("struct { uint8_t r, g, b, a;}")
local color_mt = {}

color_mt.__index = color_mt
color_mt.__metatable = "Read only"
color_mt.color = true

local color = setmetatable({}, color_mt)

color_mt.__call = function(self, r, g, b, a, fraction)
	r, g, b, a = set_default_color_values(r, g, b, a, fraction)

	if not color_t then
		return setmetatable({
			r = r,
			g = g,
			b = b,
			a = a
		}, color_mt)
	end

	return color_t(r, g, b, a)
end

color_mt.fraction = function(r, g, b, a)
	return color(r, g, b, a, true)
end

color_mt.hex = function(hex)
	local r, g, b, a = hex_to_rgba(hex)
	return color(r, g, b, a)
end

color_mt.hsl = function(h, s, l, a)
	local r, g, b, a = hsl_to_rgba(h, s, l, a)
	return color(r, g, b, a)
end

color_mt.hsv = function(h, s, v, a)
	local r, g, b, a = hsv_to_rgba(h, s, v, a)
	return color(r, g, b, a)
end

function color_mt:to_hex()
	return rgba_to_hex(self.r, self.g, self.b, self.a)
end

function color_mt:to_hsl()
	return rgba_to_hsl(self.r, self.g, self.b, self.a)
end

function color_mt:to_hsv()
	return rgba_to_hsv(self.r, self.g, self.b, self.a)
end

function color_mt:__tostring()
	return string.format("color(%d, %d, %d, %d)", self.r, self.g, self.b, self.a)
end

function color_mt:__concat(other)
	return tostring(self) .. tostring(other)
end

function color_mt:__add(other)
	other = color.is_color(other) and other or color(other)
	return color(self.r + other.r, self.g + other.g, self.b + other.b, self.a + other.a)
end

function color_mt:__sub(other)
	other = color.is_color(other) and other or color(other)
	return color(self.r - other.r, self.g - other.g, self.b - other.b, self.a - other.a)
end

function color_mt:__mul(other)
	other = color.is_color(other) and other or color(other)
	return color(self.r * other.r, self.g * other.g, self.b * other.b, self.a * other.a)
end

function color_mt:__div(other)
	other = color.is_color(other) and other or color(other)
	return color(self.r / other.r, self.g / other.g, self.b / other.b, self.a / other.a)
end

function color_mt:__eq(other)
	other = color.is_color(other) and other or color(other)
	return self.r == other.r and self.g == other.g and self.b == other.b and self.a == other.a
end

function color_mt:lerp(other, t)
	other = color.is_color(other) and other or color(other)
	return color(
		self.r + (other.r - self.r) * t,
		self.g + (other.g - self.g) * t,
		self.b + (other.b - self.b) * t,
		self.a + (other.a - self.a) * t
	)
end

function color_mt:gamma_correct(gamma)
	return color(
		math.pow(self.r, gamma),
		math.pow(self.g, gamma),
		math.pow(self.b, gamma),
		self.a
	)
end

function color_mt:grayscale()
	local gray = (self.r + self.g + self.b) / 3
	return color(gray, gray, gray, self.a)
end

function color_mt:invert()
	return color(255 - self.r, 255 - self.g, 255 - self.b, self.a)
end

function color_mt:rotate(angle)
	local h, s, v = rgba_to_hsv(self.r, self.g, self.b, self.a)
	h = (h * 360 + angle) % 360
	local new_r, new_g, new_b = hsv_to_rgba(h / 360, s, v, self.a)
	return color(new_r, new_g, new_b, self.a)
end

function color_mt:alpha_modulate(alpha)
	return color(self.r, self.g, self.b, alpha)
end

function color_mt:unpack(strip)
	if strip then
		return self.r, self.g, self.b
	end

	return self.r, self.g, self.b, self.a
end

function color_mt:clone()
	return color(self.r, self.g, self.b, self.a)
end

function color.is_color(var)
	return (type(var) == "table" or type(var) == "cdata") and var.color
end

function color.linear_gradient(colors, value)
	colors = verify_color_table(colors)

	local color_index = 1
	while colors[color_index + 1][2] < value do
		color_index = color_index + 1
	end

	local remainder = value - colors[color_index][2]
	local stop_fraction = remainder / (colors[color_index + 1][2] - colors[color_index][2])

	return colors[color_index][1]:lerp(colors[color_index + 1][1], stop_fraction)
end


ffi.metatype(color_t, color_mt)

return color
