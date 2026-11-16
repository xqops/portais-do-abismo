-- Fila dos portais: quem fica em cima da plataforma entra junto na masmorra (party de até 4).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.Game)
local Dungeons = require(ReplicatedStorage.Shared.Config.Dungeons)
local Net = require(ReplicatedStorage.Shared.Net)

local Registry = require(script.Parent.Registry)
local DataService = require(script.Parent.DataService)
local DungeonService = require(script.Parent.DungeonService)

local LobbyService = {}

local TICK = 0.25

local queues = {} -- [pad] = { countdownEnd, label }
local lastLockedWarning = {}

local function makeLabel(pad)
	local gui = Instance.new("BillboardGui")
	gui.Name = "QueueInfo"
	gui.Size = UDim2.fromOffset(300, 50)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	gui.MaxDistance = 120
	gui.Parent = pad
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	return label
end

local function register(pad)
	if queues[pad] then
		return
	end
	queues[pad] = { countdownEnd = nil, label = makeLabel(pad) }
end

local function warnLocked(player, index)
	local now = os.clock()
	if lastLockedWarning[player] and now - lastLockedWarning[player] < 3 then
		return
	end
	lastLockedWarning[player] = now
	Net.Notify:FireClient(player, "Portal bloqueado", "Derrote o chefe de " .. Dungeons[index - 1].name .. " primeiro")
end

local function playersOnPad(pad, index)
	local radius = pad:GetAttribute("Radius") or 8
	local inside = {}
	for _, player in Players:GetPlayers() do
		if not Registry.ByPlayer[player] then
			local root, humanoid = Registry.GetRoot(player)
			if root and humanoid and humanoid.Health > 0 then
				local offset = root.Position - pad.Position
				if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius and math.abs(offset.Y) < 8 then
					if DataService.GetCleared(player) >= index - 1 then
						if #inside < GameConfig.MaxPartySize then
							table.insert(inside, player)
						end
					else
						warnLocked(player, index)
					end
				end
			end
		end
	end
	return inside
end

local function step()
	local now = os.clock()
	for pad, queue in queues do
		if not pad.Parent then
			queues[pad] = nil
			continue
		end
		local index = pad:GetAttribute("DungeonIndex")
		local def = Dungeons[index]
		if not def then
			continue
		end
		local inside = playersOnPad(pad, index)
		local requirement = index > 1 and ("Requer: vencer " .. Dungeons[index - 1].name) or "Aberto para todos"

		if #inside == 0 then
			queue.countdownEnd = nil
			queue.label.Text = def.name .. "\n" .. requirement
		else
			queue.countdownEnd = queue.countdownEnd or (now + GameConfig.QueueCountdown)
			local left = math.max(0, math.ceil(queue.countdownEnd - now))
			queue.label.Text = string.format("%s\n%d/%d jogadores · começa em %ds", def.name, #inside, GameConfig.MaxPartySize, left)
			if now >= queue.countdownEnd then
				queue.countdownEnd = nil
				task.spawn(DungeonService.StartRun, index, inside)
			end
		end
	end
end

function LobbyService.Init()
	for _, pad in CollectionService:GetTagged("DungeonPad") do
		register(pad)
	end
	CollectionService:GetInstanceAddedSignal("DungeonPad"):Connect(register)
	Players.PlayerRemoving:Connect(function(player)
		lastLockedWarning[player] = nil
	end)

	task.spawn(function()
		while true do
			local ok, err = pcall(step)
			if not ok then
				warn("[LobbyService] " .. tostring(err))
			end
			task.wait(TICK)
		end
	end)
end

return LobbyService
