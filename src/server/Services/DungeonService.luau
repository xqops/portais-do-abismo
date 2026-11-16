-- Runs de masmorra: arena, ondas, chefe, XP da run, level up com cartas e recompensas.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.Game)
local Dungeons = require(Shared.Config.Dungeons)
local Archetypes = require(Shared.Config.Enemies)
local Powers = require(Shared.Config.Powers)
local Progression = require(Shared.Config.Progression)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)
local Effects = require(script.Parent.Effects)
local EnemyService = require(script.Parent.EnemyService)
local PowerService = require(script.Parent.PowerService)
local WorldBuilder = require(script.Parent.WorldBuilder)
local DataService = require(script.Parent.DataService)

local DungeonService = {}

local Run = {}
Run.__index = Run

local usedSlots = {}
local nextRunId = 0

local XP_SMALL = Color3.fromRGB(90, 230, 255)
local XP_BIG = Color3.fromRGB(255, 200, 60)

-- utilidades -------------------------------------------------------------------

local function weightedPick(pool)
	local total = 0
	for _, option in pool do
		total += option.weight
	end
	local roll = math.random() * total
	for i, option in pool do
		roll -= option.weight
		if roll <= 0 then
			return table.remove(pool, i)
		end
	end
	return table.remove(pool)
end

local function waveWeights(wave)
	return {
		{ id = "chaser", weight = 5 },
		{ id = "runner", weight = wave >= 2 and 3 or 0 },
		{ id = "archer", weight = wave >= 3 and 2 or 0 },
		{ id = "brute", weight = wave >= 6 and 2 or (wave >= 4 and 1 or 0) },
	}
end

local function pickArchetype(wave)
	local pool = {}
	for _, option in waveWeights(wave) do
		if option.weight > 0 then
			table.insert(pool, option)
		end
	end
	return weightedPick(pool).id
end

-- descrição de uma carta para o cliente
local function describe(option)
	if option.type == "stat" then
		local card = Progression.StatCardsById[option.id]
		return { kind = "stat", title = card.name, ability = "Atributo", desc = card.desc, color = card.color, tier = 0 }
	end
	local power = Powers.ById[option.id]
	local t = power.tiers[option.tier]
	return {
		kind = option.tier == 4 and "ultimate" or option.type,
		title = power.name,
		ability = t.name,
		desc = t.desc,
		color = power.color,
		tier = option.tier,
		cd = t.cd,
	}
end

-- ciclo de vida da run -------------------------------------------------------------

function DungeonService.StartRun(dungeonIndex, players)
	local def = Dungeons[dungeonIndex]
	local slot = 1
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true
	nextRunId += 1

	local arena = WorldBuilder.BuildArena(def, Vector3.new(GameConfig.ArenaSpacing * slot, 0, 0))
	local self = setmetatable({
		id = nextRunId,
		slot = slot,
		index = dungeonIndex,
		def = def,
		arena = arena,
		floorY = arena.floorY,
		players = {}, -- [Player] = estado
		enemies = {}, -- [enemy] = true
		orbs = {},
		wave = 0,
		bossEnemy = nil,
		kills = 0,
		gold = 0,
		startTime = os.clock(),
		lastState = 0,
		ended = false,
		connections = {},
	}, Run)

	self.enemyFolder = Instance.new("Folder")
	self.enemyFolder.Name = "Enemies"
	self.enemyFolder.Parent = arena.model

	for i, player in players do
		self:AddPlayer(player, i)
	end
	if not next(self.players) then
		self:End(false)
		return nil
	end

	table.insert(
		self.connections,
		RunService.Heartbeat:Connect(function(dt)
			self:Update(dt)
		end)
	)
	task.spawn(function()
		self:Loop()
	end)
	return self
end

function Run:AddPlayer(player, index)
	local root, humanoid = Registry.GetRoot(player)
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local state = {
		player = player,
		run = self,
		active = true,
		level = 1,
		xp = 0,
		pending = 0,
		offer = nil,
		powers = {}, -- { {id, tier} } na ordem dos slots
		cooldowns = {},
		stats = { damageMult = 1, cooldownMult = 1, magnet = 14 },
		shield = 0,
		shieldUntil = 0,
		reflect = 0,
		reflectUntil = 0,
		invulnUntil = 0,
		buffMult = 1,
		buffUntil = 0,
		regen = 0,
		regenUntil = 0,
		lastBasic = 0,
		combo = 0,
		kills = 0,
	}
	self.players[player] = state
	Registry.ByPlayer[player] = state

	humanoid.MaxHealth = 100
	humanoid.Health = 100
	player.Character:PivotTo(CFrame.new(self.arena.playerSpawn + Vector3.new((index - 1) * 4 - 6, 3, 0)))
	state.diedConnection = humanoid.Died:Connect(function()
		self:PlayerDied(player)
	end)

	-- todo mundo começa escolhendo o primeiro poder
	state.pending = 1
	self:SendOffer(state)
end

function Run:Loop()
	self:NotifyAll(self.def.name, "Escolha seu primeiro poder e prepare-se!")
	task.wait(5)
	for wave = 1, self.def.waves do
		if self.ended then
			return
		end
		self.wave = wave
		self:NotifyAll("Onda " .. wave .. "/" .. self.def.waves, nil)
		self:SpawnWave(wave)
		while not self.ended and next(self.enemies) do
			task.wait(0.5)
		end
		if self.ended then
			return
		end
		task.wait(2)
	end
	self.wave = self.def.waves + 1
	self:NotifyAll(self.def.boss.name .. " apareceu!", "Derrote o chefe para concluir a masmorra")
	task.wait(1.5)
	if not self.ended then
		self:SpawnBoss()
	end
end

function Run:PlayerCount()
	local count = 0
	for _, state in self.players do
		if state.active then
			count += 1
		end
	end
	return count
end

function Run:EnemyCount()
	local count = 0
	for _ in self.enemies do
		count += 1
	end
	return count
end

-- inimigos ---------------------------------------------------------------------------

function Run:SpawnWave(wave)
	local players = math.max(1, self:PlayerCount())
	local total = math.floor((12 + wave * 7) * (1 + 0.5 * (players - 1)))
	local spawned = 0
	while spawned < total and not self.ended do
		while self:EnemyCount() >= GameConfig.MaxAliveEnemies and not self.ended do
			task.wait(0.5)
		end
		for _ = 1, math.min(GameConfig.SpawnGroupSize, total - spawned) do
			self:SpawnMob(pickArchetype(wave), wave)
			spawned += 1
		end
		task.wait(GameConfig.SpawnGroupInterval)
	end
end

function Run:MakeDef(archetypeId, wave)
	local base = Archetypes[archetypeId]
	local look = self.def.mobs[archetypeId]
	local players = math.max(1, self:PlayerCount())
	local scale = self.def.hpMult * (1 + 0.1 * (wave - 1)) * (1 + 0.35 * (players - 1))
	local def = table.clone(base)
	def.name = look.name
	def.model = look.model
	def.color = look.color
	def.eyeColor = self.def.theme.accent
	def.hp = math.floor(base.hp * scale)
	def.damage = base.damage * self.def.dmgMult
	return def
end

function Run:RandomSpawnPoint()
	local points = self.arena.spawnPoints
	for _ = 1, 8 do
		local point = points[math.random(#points)] + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
		local clear = true
		for player in self.players do
			local root = Registry.GetRoot(player)
			if root and (root.Position - point).Magnitude < 25 then
				clear = false
				break
			end
		end
		if clear then
			return point
		end
	end
	return points[math.random(#points)]
end

function Run:SpawnMob(archetypeId, wave, position)
	if self.ended then
		return nil
	end
	return EnemyService.Spawn(self, self:MakeDef(archetypeId, wave), position or self:RandomSpawnPoint())
end

function Run:SpawnBoss()
	local boss = self.def.boss
	local players = math.max(1, self:PlayerCount())
	local def = table.clone(Archetypes.boss)
	def.name = boss.name
	def.model = boss.model
	def.color = boss.color
	def.size = boss.size
	def.skills = boss.skills
	def.eyeColor = self.def.theme.accent
	def.hp = math.floor(boss.hp * (1 + 0.6 * (players - 1)))
	def.damage = Archetypes.boss.damage * self.def.dmgMult
	def.boss = true
	self.bossEnemy = EnemyService.Spawn(self, def, self.arena.center + Vector3.new(0, 0, -50))
end

function Run:OnEnemyKilled(enemy)
	if self.ended then
		return
	end
	self.kills += 1
	self.gold += enemy.def.gold or 0
	local killer = enemy.lastHitBy
	if killer and self.players[killer] then
		self.players[killer].kills += 1
	end
	if enemy.def.boss then
		self:End(true)
		return
	end
	self:DropOrb(enemy.root.Position, enemy.def.xp or 1)
end

-- XP e level up ----------------------------------------------------------------------

function Run:DropOrb(pos, value)
	local big = value >= 5
	local orb = Effects.Part(Enum.PartType.Ball, Vector3.one * (big and 1.4 or 0.9), CFrame.new(pos.X, self.floorY + 1.2, pos.Z), big and XP_BIG or XP_SMALL, 0, "xp")
	orb.Parent = self.arena.model
	table.insert(self.orbs, { part = orb, value = value, target = nil })
end

-- XP é compartilhado: qualquer um que pegar um orbe dá XP para a party toda
function Run:GiveXp(amount)
	for player, state in self.players do
		if state.active then
			state.xp += amount
			local need = Progression.RunXpToNext(state.level)
			while state.xp >= need do
				state.xp -= need
				state.level += 1
				state.pending += 1
				need = Progression.RunXpToNext(state.level)
				state.invulnUntil = math.max(state.invulnUntil, os.clock() + 1)
				local _, humanoid = Registry.GetRoot(player)
				Effects.LevelUp(player)
				if humanoid then
					Registry.HealPlayer(player, humanoid.MaxHealth * 0.15)
				end
			end
			if state.pending > 0 and not state.offer then
				self:SendOffer(state)
			end
		end
	end
end

function Run:BuildOffer(state)
	local pool = {}
	local owned = {}
	for slot, power in state.powers do
		owned[power.id] = true
		if power.tier < 4 then
			table.insert(pool, { type = "upgrade", id = power.id, slot = slot, tier = power.tier + 1, weight = 3 })
		end
	end
	if #state.powers < GameConfig.MaxPowerSlots then
		local fresh = {}
		for _, power in Powers.List do
			if not owned[power.id] then
				table.insert(fresh, power.id)
			end
		end
		-- poderes novos dividem um peso total fixo, para upgrades não sumirem
		local weight = #state.powers == 0 and 1 or 4 / math.max(1, #fresh)
		for _, id in fresh do
			table.insert(pool, { type = "new", id = id, tier = 1, weight = weight })
		end
	end

	local options = {}
	while #options < 3 and #pool > 0 do
		table.insert(options, weightedPick(pool))
	end

	-- às vezes uma carta de atributo; sempre que faltar opção
	local stats = table.clone(Progression.StatCards)
	if #state.powers > 0 and #options == 3 and math.random() < 0.25 then
		table.remove(options)
	end
	while #options < 3 and #stats > 0 do
		local card = table.remove(stats, math.random(#stats))
		table.insert(options, { type = "stat", id = card.id })
	end
	return options
end

function Run:SendOffer(state)
	state.offer = self:BuildOffer(state)
	local cards = {}
	for i, option in state.offer do
		cards[i] = describe(option)
	end
	Net.LevelUpOffer:FireClient(state.player, cards, state.level)
end

function Run:ChooseCard(state, index)
	local offer = state.offer
	if not offer or type(index) ~= "number" then
		return
	end
	local option = offer[index]
	if not option then
		return
	end
	state.offer = nil
	state.pending -= 1
	local now = os.clock()

	if option.type == "new" then
		table.insert(state.powers, { id = option.id, tier = 1 })
		state.cooldowns[option.id .. 1] = now + 0.5
	elseif option.type == "upgrade" then
		local power = state.powers[option.slot]
		if power and power.id == option.id then
			power.tier = option.tier
			if power.tier <= 3 then
				state.cooldowns[power.id .. power.tier] = now + 0.5
			else
				local ultimate = Powers.ById[power.id].tiers[4]
				self:Notify(state.player, "ULTIMATE DESBLOQUEADA!", ultimate.name .. " — aperte " .. option.slot)
			end
		end
	else
		self:ApplyStat(state, option.id)
	end

	if state.pending > 0 then
		self:SendOffer(state)
	end
end

function Run:ApplyStat(state, id)
	local _, humanoid = Registry.GetRoot(state.player)
	if id == "vitality" then
		if humanoid then
			humanoid.MaxHealth += 25
			humanoid.Health += 25
		end
	elseif id == "power" then
		state.stats.damageMult += 0.12
	elseif id == "haste" then
		state.stats.cooldownMult *= 0.9
	elseif id == "swift" then
		if humanoid then
			humanoid.WalkSpeed += 2
		end
	elseif id == "magnet" then
		state.stats.magnet += 6
	end
end

-- loop por frame ------------------------------------------------------------------------

function Run:Update(dt)
	if self.ended then
		return
	end
	local now = os.clock()

	for player, state in self.players do
		if state.active then
			PowerService.Tick(state, now)
			if state.regen > 0 and now < state.regenUntil then
				Registry.HealPlayer(player, state.regen * dt)
			end
		end
	end
	if self.ended then
		return -- um poder pode ter matado o chefe
	end

	-- orbes de XP voam até quem chegar perto
	for i = #self.orbs, 1, -1 do
		local orb = self.orbs[i]
		local pos = orb.part.Position
		if not orb.target or not orb.target.Parent then
			orb.target = nil
			for player, state in self.players do
				local root = state.active and Registry.GetRoot(player)
				if root and (root.Position - pos).Magnitude <= state.stats.magnet then
					orb.target = root
					break
				end
			end
		end
		if orb.target then
			local toTarget = orb.target.Position - pos
			if toTarget.Magnitude < 2.5 then
				orb.part:Destroy()
				table.remove(self.orbs, i)
				self:GiveXp(orb.value)
			else
				orb.part.CFrame = CFrame.new(pos + toTarget.Unit * math.min(toTarget.Magnitude, 60 * dt))
			end
		end
	end

	if now - self.lastState >= 0.2 then
		self.lastState = now
		self:SendState()
	end
end

function Run:SendState()
	local now = os.clock()
	local boss = self.bossEnemy
	local bossInfo = nil
	if boss and not boss.dead then
		bossInfo = { name = boss.def.name, hp = boss.humanoid.Health, max = boss.humanoid.MaxHealth }
	end
	local enemyCount = self:EnemyCount()
	for player, state in self.players do
		local slots = {}
		for i, owned in state.powers do
			local power = Powers.ById[owned.id]
			slots[i] = {
				name = power.name,
				color = power.color,
				tier = owned.tier,
				ult = owned.tier >= 4 and power.tiers[4].name or nil,
				ultCd = math.max(0, (state.cooldowns[owned.id .. "ult"] or 0) - now),
				ultMax = power.tiers[4].cd,
			}
		end
		Net.RunState:FireClient(player, {
			inRun = true,
			dungeon = self.def.name,
			wave = self.wave,
			waves = self.def.waves,
			boss = bossInfo,
			level = state.level,
			xp = state.xp,
			xpNeed = Progression.RunXpToNext(state.level),
			shield = now < state.shieldUntil and state.shield or 0,
			kills = self.kills,
			gold = self.gold,
			time = now - self.startTime,
			enemies = enemyCount,
			slots = slots,
		})
	end
end

-- comunicação --------------------------------------------------------------------------

function Run:DamageNumber(pos, amount, color)
	for player in self.players do
		Net.DamageNumber:FireClient(player, pos, amount, color)
	end
end

function Run:Notify(player, title, subtitle)
	Net.Notify:FireClient(player, title, subtitle)
end

function Run:NotifyAll(title, subtitle)
	for player in self.players do
		self:Notify(player, title, subtitle)
	end
end

-- saída e fim ----------------------------------------------------------------------------

-- tira o jogador da run e entrega recompensas
function Run:Release(player, victory, leaving)
	local state = self.players[player]
	if not state then
		return
	end
	state.active = false
	if state.diedConnection then
		state.diedConnection:Disconnect()
	end
	self.players[player] = nil
	if Registry.ByPlayer[player] == state then
		Registry.ByPlayer[player] = nil
	end

	local gold = self.gold + (victory and self.def.reward.gold or 0)
	if not victory then
		gold = math.floor(gold * 0.5)
	end
	local xp = math.floor(self.kills * 1.5 + state.level * 5) + (victory and self.def.reward.xp or 0)
	DataService.AddGold(player, gold)
	DataService.AddXp(player, xp)
	if victory then
		DataService.MarkCleared(player, self.index)
	end

	if not leaving then
		Net.RunState:FireClient(player, { inRun = false })
		Net.LevelUpOffer:FireClient(player, nil)
		self:Notify(player, victory and "VITÓRIA!" or "Derrota...", string.format("+%d ouro  ·  +%d XP de conta", gold, xp))
	end
end

function Run:PlayerDied(player)
	local state = self.players[player]
	if not state or not state.active then
		return
	end
	self:Release(player, false)
	self:NotifyAll(player.DisplayName .. " caiu!", nil)
	if self:PlayerCount() == 0 then
		self:End(false)
	end
end

function Run:PlayerLeft(player)
	self:Release(player, false, true)
	if self:PlayerCount() == 0 then
		self:End(false)
	end
end

function Run:End(victory)
	if self.ended then
		return
	end
	self.ended = true
	for _, connection in self.connections do
		connection:Disconnect()
	end
	for enemy in self.enemies do
		EnemyService.Kill(enemy, true)
	end
	for _, orb in self.orbs do
		orb.part:Destroy()
	end
	self.orbs = {}

	local survivors = {}
	for player in self.players do
		table.insert(survivors, player)
	end
	for _, player in survivors do
		self:Release(player, victory)
	end

	if victory then
		for i = 1, 12 do
			task.delay(i * 0.25, function()
				local offset = Vector3.new(math.random(-40, 40), math.random(15, 35), math.random(-40, 40))
				Effects.Burst(self.arena.center + offset, math.random(5, 10), Color3.fromHSV(math.random(), 0.7, 1), 0.6)
			end)
		end
	end

	task.delay(victory and GameConfig.ReturnToLobbyDelay or 2, function()
		for _, player in survivors do
			if player.Parent then
				player:LoadCharacter() -- volta para o spawn do lobby
			end
		end
		self.arena.model:Destroy()
		usedSlots[self.slot] = nil
	end)
end

-- entrada ------------------------------------------------------------------------------------

function DungeonService.IsInRun(player)
	return Registry.ByPlayer[player] ~= nil
end

function DungeonService.Init()
	Net.ChooseCard.OnServerEvent:Connect(function(player, index)
		local state = Registry.ByPlayer[player]
		if state and state.active then
			state.run:ChooseCard(state, index)
		end
	end)

	Net.CastUltimate.OnServerEvent:Connect(function(player, slot)
		local state = Registry.ByPlayer[player]
		if not state or not state.active or type(slot) ~= "number" then
			return
		end
		local ok, name = PowerService.CastUltimate(state, slot)
		if ok then
			state.run:NotifyAll(player.DisplayName .. " usou " .. name .. "!", nil)
		end
	end)

	Net.BasicAttack.OnServerEvent:Connect(function(player, direction)
		local state = Registry.ByPlayer[player]
		if not state or not state.active or typeof(direction) ~= "Vector3" then
			return
		end
		if direction.X ~= direction.X or direction.Z ~= direction.Z then
			return -- NaN
		end
		PowerService.BasicAttack(state, direction)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local state = Registry.ByPlayer[player]
		if state then
			state.run:PlayerLeft(player)
		end
	end)
end

return DungeonService
