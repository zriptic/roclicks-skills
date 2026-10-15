--!strict
-- LoadingScreen (LocalScript in ReplicatedFirst). Runs before anything else replicates.
-- Shows the game's own title card instead of Roblox's default, follows a REAL load stage set by
-- the main client script, and always gets out of the way (safety timeout) so a client error can't
-- trap the player behind it.
--
-- Contract with the main client script:
--   Players.LocalPlayer:SetAttribute("LoadStage", 0..1)   -- as each boot step finishes
--   Players.LocalPlayer:SetAttribute("ClientReady", true) -- when the HUD is live
--   Players.LocalPlayer:SetAttribute("IntroWillPlay", true) -- optional: first join, intro next

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SAFETY_TIMEOUT = 75

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local gui = script:WaitForChild("LoadingGui"):Clone() :: ScreenGui -- approved title card, built from HTML
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- LoadingGui: a ScreenGui you make once in Studio holding a clone of the "Loading" template (design it as
-- grp('Loading', ..., 'TL') on templates.html with a bar named LoadBar (fill child F) and a label Status),
-- plus a UIScale. Generated bars size F in Offset px (UIKit.bar contract), so remember the full width.
local fill = gui:FindFirstChild("F", true) :: Frame
local status = gui:FindFirstChild("Status", true) :: TextLabel?
local fullW = fill.Size.X.Offset

local function setStage(v: number)
	local y = fill.Size.Y
	TweenService:Create(fill, TweenInfo.new(0.3), { Size = UDim2.new(0, fullW * math.clamp(v, 0.05, 1), y.Scale, y.Offset) }):Play()
end

player:GetAttributeChangedSignal("LoadStage"):Connect(function()
	setStage(player:GetAttribute("LoadStage") or 0)
end)
setStage(player:GetAttribute("LoadStage") or 0)
if status then status.Text = "Loading..." end

local closed = false
local function close()
	if closed then return end
	closed = true
	setStage(1)
	task.wait(0.25)
	if player:GetAttribute("IntroWillPlay") then
		-- the intro starts on this same title card: hand over without a fade, no flash between them
		gui:Destroy()
		return
	end
	for _, d in gui:GetDescendants() do
		if d:IsA("GuiObject") then
			TweenService:Create(d, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		end
		if d:IsA("TextLabel") then
			TweenService:Create(d, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		elseif d:IsA("ImageLabel") then
			TweenService:Create(d, TweenInfo.new(0.5), { ImageTransparency = 1 }):Play()
		end
	end
	task.delay(0.55, function() gui:Destroy() end)
end

if player:GetAttribute("ClientReady") then
	close()
else
	player:GetAttributeChangedSignal("ClientReady"):Connect(function()
		if player:GetAttribute("ClientReady") then close() end
	end)
end
task.delay(SAFETY_TIMEOUT, function()
	if not closed then
		warn("LoadingScreen: safety timeout, ClientReady never arrived")
		close()
	end
end)
