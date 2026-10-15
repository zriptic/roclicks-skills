-- Controller (LocalScript inside the ScreenGui; Builder copies it from the Client folder).
-- Boots the UI module + UIKit and enables the gui. The StarterGui copy stays Enabled = false on
-- purpose so the design-size HUD never covers the Studio edit viewport.
--
-- PREVIEW VALUES are opt-in: they are written ONLY when the ScreenGui has the attribute PreviewMode = true
-- (set it by hand for a UI-only preview place; never in the real game). A controller that always wrote demo
-- numbers raced the game's own client and a fresh save showed "$30,500 / 125 gems".
local gui = script.Parent
local UI = require(gui:WaitForChild("UI"))
local UIKit = require(gui:WaitForChild("UIKit"))
UIKit.init(gui:GetAttribute("TemplatesFolder"), gui:FindFirstChild("AssetIds"))
UI.init(gui)
gui.Enabled = true

if gui:GetAttribute("PreviewMode") == true then
	local NumberFormat = require(gui:WaitForChild("NumberFormat"))
	local hud = gui.Root:FindFirstChild("HUD")
	if hud then
		UI.setText(hud, "CashText", NumberFormat.cash(30500))
		UI.setText(hud, "GemsText", NumberFormat.format(125))
	end
end
