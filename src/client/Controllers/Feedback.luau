-- Números de dano flutuantes + faísca no ponto do acerto.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Feedback = {}

local LIFETIME = 0.75
local VFX -- injetado no Init

local function showNumber(position, amount, color)
	VFX.HitSpark(position, color or Color3.new(1, 1, 1))

	-- Attachment no Terrain = ponto fixo no mundo para prender o BillboardGui
	local anchor = Instance.new("Attachment")
	anchor.Position = position
	anchor.Parent = workspace.Terrain

	-- golpes fortes aparecem maiores
	local big = amount >= 100
	local size = big and 110 or (amount >= 40 and 80 or 60)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size, size * 0.4)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	gui.StudsOffsetWorldSpace = Vector3.new((math.random() - 0.5) * 2.5, 1, (math.random() - 0.5) * 2.5)
	gui.Adornee = anchor
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = big and (tostring(amount) .. "!") or tostring(amount)
	label.TextColor3 = big and Color3.fromRGB(255, 220, 90) or (color or Color3.new(1, 1, 1))
	label.TextStrokeTransparency = 0
	label.Parent = gui

	-- "pula" e depois sobe sumindo
	local scale = Instance.new("UIScale")
	scale.Scale = 1.6
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local info = TweenInfo.new(LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(gui, TweenInfo.new(LIFETIME), { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 3.5, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, LIFETIME + 0.1)
end

function Feedback.Init(vfx)
	VFX = vfx
	Net.DamageNumber.OnClientEvent:Connect(showNumber)
end

return Feedback
