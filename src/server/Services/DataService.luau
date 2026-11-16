-- Dados persistentes da conta (DataStore).
-- No Studio: Game Settings > Security > "Enable Studio Access to API Services" para salvar de verdade.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local Dungeons = require(ReplicatedStorage.Shared.Config.Dungeons)
local Net = require(ReplicatedStorage.Shared.Net)

local DataService = {}

local STORE_NAME = "PortaisDoAbismo_v1"
local AUTOSAVE_INTERVAL = 120
local DEFAULT = {
	level = 1,
	xp = 0,
	gold = 0,
	cleared = 0, -- maior índice de masmorra concluída
}

local profiles = {}

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore indisponível, progresso não será salvo: " .. tostring(result))
	end
end

local function storeKey(player)
	return "player_" .. player.UserId
end

local function sync(player)
	local data = profiles[player]
	if not data then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats["Nível"].Value = data.level
		stats.Ouro.Value = data.gold
	end
	Net.Profile:FireClient(player, {
		level = data.level,
		xp = data.xp,
		xpNeed = Progression.AccountXpToNext(data.level),
		gold = data.gold,
		cleared = data.cleared,
		totalDungeons = #Dungeons,
	})
end

local function load(player)
	local data = table.clone(DEFAULT)
	if store then
		local ok, saved = pcall(function()
			return store:GetAsync(storeKey(player))
		end)
		if ok and type(saved) == "table" then
			for key, value in saved do
				data[key] = value
			end
		elseif not ok then
			warn("[DataService] falha ao carregar " .. player.Name .. ": " .. tostring(saved))
		end
	end
	if not player.Parent then
		return -- saiu durante o carregamento
	end
	profiles[player] = data

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Nível"
	level.Parent = stats
	local gold = Instance.new("IntValue")
	gold.Name = "Ouro"
	gold.Parent = stats
	stats.Parent = player

	sync(player)
end

local function save(player)
	local data = profiles[player]
	if not data or not store then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(storeKey(player), data)
	end)
	if not ok then
		warn("[DataService] falha ao salvar " .. player.Name .. ": " .. tostring(err))
	end
end

function DataService.Init()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		-- deferido para outras partes (ex.: recompensas da run) rodarem antes de salvar
		task.defer(function()
			save(player)
			profiles[player] = nil
		end)
	end)

	game:BindToClose(function()
		for player in profiles do
			save(player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(save, player)
			end
		end
	end)

	-- o cliente pede o perfil quando o HUD fica pronto
	Net.Profile.OnServerEvent:Connect(sync)
end

function DataService.Get(player)
	return profiles[player]
end

function DataService.GetCleared(player)
	local data = profiles[player]
	return data and data.cleared or 0
end

function DataService.AddGold(player, amount)
	local data = profiles[player]
	if not data then
		return
	end
	data.gold += amount
	sync(player)
end

function DataService.AddXp(player, amount)
	local data = profiles[player]
	if not data then
		return
	end
	data.xp += amount
	local need = Progression.AccountXpToNext(data.level)
	while data.xp >= need do
		data.xp -= need
		data.level += 1
		need = Progression.AccountXpToNext(data.level)
	end
	sync(player)
end

function DataService.MarkCleared(player, dungeonIndex)
	local data = profiles[player]
	if not data then
		return
	end
	data.cleared = math.max(data.cleared, dungeonIndex)
	sync(player)
end

return DataService
