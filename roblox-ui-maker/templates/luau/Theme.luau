--!strict
-- Theme: the style tokens in Roblox units (the Luau side of styles/stud.css + style.css).
-- Generated screens get their look from the HTML export; use Theme only for the rare runtime bits
-- that cannot be a template (a tint swap, a highlight colour, a stroke on a billboard). Keep it in
-- sync with the CSS tokens: same names, see STYLE.md "Token table". Values below = the stud preset.
local Theme = {}

local function rgb(hex: string): Color3
	return Color3.fromHex(hex)
end

Theme.ink = rgb("#070a0e")                       -- --ink: every outline
Theme.glass = { color = rgb("#080e16"), transparency = 0.24 } -- --glass rgba(8,14,22,.76) -> 1 - .76
Theme.glassCard = { color = rgb("#080e16"), transparency = 0.20 }
Theme.panel = { stroke = 7, corner = 30 }        -- --panel-bw, --panel-rad (design px; UIStroke scales with UIScale)
Theme.plate = { stroke = 6, corner = 20 }        -- --plate-ow, --plate-rad
Theme.stud = { tile = 112, studsPerTile = 4 }    -- --stud: ImageLabel ScaleType Tile, TileSize = 112 design px
Theme.font = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
Theme.font2 = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold)
Theme.text = { outline = rgb("#121212"), strokeTitle = 4.5, strokeBody = 3.5, strokeSmall = 2 } -- CSS --sw / 2
Theme.sel = rgb("#fff35a")
Theme.gold = rgb("#ffd23a")

-- colour ramps (CSS .c-*): face gradient top/mid/bottom, lip, outline. Face = UIGradient Rotation 90.
Theme.ramp = {
	blue = { top = rgb("#7adcef"), mid = rgb("#57c6e8"), bot = rgb("#3cc6fb"), lip = rgb("#127aa5"), ol = rgb("#04161d") },
	green = { top = rgb("#80ee5a"), mid = rgb("#4ced41"), bot = rgb("#20f633"), lip = rgb("#0aa31a"), ol = rgb("#031a06") },
	red = { top = rgb("#ef747c"), mid = rgb("#e24b51"), bot = rgb("#f9505a"), lip = rgb("#9c1b1f"), ol = rgb("#1c0204") },
	yellow = { top = rgb("#ffe47a"), mid = rgb("#ffc935"), bot = rgb("#ffbd0a"), lip = rgb("#b87400"), ol = rgb("#241500") },
	purple = { top = rgb("#cf8fff"), mid = rgb("#a95cf2"), bot = rgb("#9b45f7"), lip = rgb("#5c1d9c"), ol = rgb("#14041f") },
	grey = { top = rgb("#c3cad0"), mid = rgb("#9aa2a9"), bot = rgb("#8c959d"), lip = rgb("#4f575e"), ol = rgb("#101316") },
	gold = { top = rgb("#fff07a"), mid = rgb("#ffd23a"), bot = rgb("#ffbf1c"), lip = rgb("#c27a00"), ol = rgb("#2a1700") },
}

function Theme.faceGradient(r: { top: Color3, mid: Color3, bot: Color3 }): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, r.top), ColorSequenceKeypoint.new(0.48, r.mid), ColorSequenceKeypoint.new(1, r.bot),
	})
end

-- button motion (same numbers as the HTML .st-hover / .st-press previews)
Theme.motion = { hoverScale = 1.06, hoverLift = -3, pressScale = 0.92, pressSink = 4, openFrom = 0.4 }

return Theme
