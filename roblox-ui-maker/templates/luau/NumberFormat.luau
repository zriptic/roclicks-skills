--!strict
-- NumberFormat: the ONE formatter for every number the player sees (HUD, panels, toasts, billboards).
-- Two formatters in one game disagreed, and the buggy one showed 250,000 as "25K" (it stripped
-- trailing zeros from whole numbers). Use this module everywhere; delete the others.

local NumberFormat = {}

local SUFFIX = { "K", "M", "B", "T", "Qa", "Qi" }

NumberFormat.style = "short" -- "short" (1.36K) or "full" (1,360)

-- Commas: 1234567 -> "1,234,567"
function NumberFormat.full(n: number): string
	n = math.floor(n + 0.5)
	local s = tostring(math.abs(n))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	out = string.gsub(out, "^,", "")
	return (if n < 0 then "-" else "") .. out
end

-- Short: 1234 -> "1.23K", 250000 -> "250K", 1000000 -> "1M".
-- Truncates instead of rounding, so a player with 9,995 never sees "$10K" next to a $10K price.
function NumberFormat.short(n: number): string
	local a = math.abs(n)
	if a < 1000 then
		return NumberFormat.full(n)
	end
	local i = 0
	while a >= 1000 and i < #SUFFIX do
		a /= 1000
		i += 1
	end
	local s
	if a >= 100 then
		s = string.format("%d", math.floor(a))
	elseif a >= 10 then
		s = string.format("%.1f", math.floor(a * 10) / 10)
	else
		s = string.format("%.2f", math.floor(a * 100) / 100)
	end
	-- THE BUG FIX: only strip zeros after a decimal point. "250" must stay "250".
	if string.find(s, ".", 1, true) then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return (if n < 0 then "-" else "") .. s .. SUFFIX[i]
end

function NumberFormat.format(n: number): string
	if NumberFormat.style == "short" then
		return NumberFormat.short(n)
	end
	return NumberFormat.full(n)
end

function NumberFormat.cash(n: number): string
	local s = NumberFormat.format(n)
	if string.sub(s, 1, 1) == "-" then
		return "-$" .. string.sub(s, 2)
	end
	return "$" .. s
end

-- 0.9 -> "0.9/s", 1.35 -> "1.35/s", 12 -> "12/s"
function NumberFormat.rate(perSec: number): string
	if perSec >= 1000 then
		return NumberFormat.short(perSec) .. "/s"
	end
	local s = string.format("%.2f", perSec)
	s = string.gsub(string.gsub(s, "0+$", ""), "%.$", "")
	return s .. "/s"
end

-- 75 -> "1:15", 3725 -> "1:02:05"
function NumberFormat.time(sec: number): string
	sec = math.max(0, math.floor(sec))
	local h, m, s = sec // 3600, (sec // 60) % 60, sec % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

-- Run once in Studio (or from a test runner) after any change.
function NumberFormat._test()
	local cases = {
		{ 0, "0" }, { 999, "999" }, { 1000, "1K" }, { 1234, "1.23K" }, { 99999, "99.9K" },
		{ 100000, "100K" }, { 250000, "250K" }, { 300000, "300K" }, { 999600, "999K" },
		{ 1000000, "1M" }, { 1360000, "1.36M" }, { -2500, "-2.5K" },
	}
	for _, c in cases do
		local got = NumberFormat.short(c[1])
		assert(got == c[2], string.format("short(%s) = %s, want %s", tostring(c[1]), got, c[2]))
	end
	assert(NumberFormat.full(1234567) == "1,234,567")
	assert(NumberFormat.time(75) == "1:15")
	assert(NumberFormat.rate(1.35) == "1.35/s")
	return "NumberFormat ok"
end

return NumberFormat
