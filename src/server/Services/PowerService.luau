-- Executa os poderes (tiers 1-3 automáticos, tier 4 = ultimate manual) e o ataque básico.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Powers = require(ReplicatedStorage.Shared.Config.Powers)
local GameConfig = require(ReplicatedStorage.Shared.Config.Game)
local Effects = require(script.Parent.Effects)
local Projectiles = require(script.Parent.Projectiles)
local EnemyService = require(script.Parent.EnemyService)
local Registry = require(script.Parent.Registry)

local PowerService = {}

local COMBAT_RANGE = 60 -- só dispara habilidades se houver inimigo até essa distância
local VERTICAL = Effects.VERTICAL
local FEET_OFFSET = CFrame.new(0, -2.9, 0) -- do HumanoidRootPart até o chão (R15 padrão)

-- utilidades -----------------------------------------------------------------

local function flat(v)
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return f.Unit
end

local function ground(state, pos)
	return Vector3.new(pos.X, state.run.floorY, pos.Z)
end

local function aimPoint(root, target)
	if target and not target.dead then
		return target.root.Position
	end
	return root.Position + root.CFrame.LookVector * 25
end

local function damageMult(state)
	local mult = state.stats.damageMult
	if os.clock() < state.buffUntil then
		mult *= state.buffMult
	end
	return mult
end

local function hitEnemy(state, enemy, amount, color, t)
	if enemy.dead or not amount then
		return
	end
	local dealt = EnemyService.Damage(enemy, amount * damageMult(state), state.player, color)
	if t.lifesteal and dealt > 0 then
		Registry.HealPlayer(state.player, dealt * t.lifesteal)
	end
	if t.slow then
		EnemyService.Slow(enemy, t.slow, t.slowTime or 2)
	end
	if t.freeze then
		EnemyService.Freeze(enemy, t.freeze)
	end
end

local function aoe(state, center, radius, damage, color, t)
	for _, enemy in EnemyService.GetInRadius(state.run, center, radius) do
		hitEnemy(state, enemy, damage, color, t)
	end
end

-- direções em leque (spread em graus; 360 = círculo completo)
local function fan(baseDir, count, spreadDeg)
	if count <= 1 then
		return { baseDir }
	end
	local full = spreadDeg >= 360
	local spread = math.rad(math.min(spreadDeg, 360))
	local step = full and spread / count or spread / (count - 1)
	local start = full and 0 or -spread / 2
	local dirs = {}
	for i = 0, count - 1 do
		table.insert(dirs, CFrame.fromAxisAngle(Vector3.yAxis, start + step * i) * baseDir)
	end
	return dirs
end

local function lineHit(state, t, color, origin, dir, length, width, damage)
	Effects.Beam(origin, origin + dir * length, width, color, 0.3)
	for _, enemy in EnemyService.GetInRadius(state.run, origin + dir * (length / 2), length / 2 + width) do
		local rel = enemy.root.Position - origin
		local along = rel:Dot(dir)
		if along >= -enemy.radius and along <= length + enemy.radius then
			local perp = rel - dir * along
			if Vector3.new(perp.X, 0, perp.Z).Magnitude <= width + enemy.radius then
				hitEnemy(state, enemy, damage, color, t)
			end
		end
	end
end

-- tipos de habilidade ----------------------------------------------------------

local Kinds = {}

function Kinds.projectile(state, t, color, root, target)
	local run = state.run
	local function fireOne(origin, dir)
		Projectiles.Fire({
			origin = origin,
			direction = dir,
			speed = t.speed or 90,
			range = t.range or 70,
			size = t.size or 1.2,
			color = color,
			visual = t.visual,
			pierce = t.explode and 0 or (t.pierce or 0),
			homing = t.homing and function(pos)
				local enemy = EnemyService.Nearest(run, pos, 40)
				return enemy and enemy.root.Position
			end or nil,
			hitTest = function(pos, radius)
				return EnemyService.GetInRadius(run, pos, radius)
			end,
			onHit = function(enemy, pos)
				if t.explode then
					Effects.Burst(pos, t.explode, color)
					aoe(state, pos, t.explode, t.damage, color, t)
				else
					hitEnemy(state, enemy, t.damage, color, t)
				end
			end,
		})
	end

	task.spawn(function()
		for shot = 1, t.burst or 1 do
			if not state.active or not root.Parent then
				return
			end
			if shot > 1 then
				target = EnemyService.Nearest(run, root.Position, COMBAT_RANGE) or target
			end
			local origin = root.Position + Vector3.new(0, 0.5, 0)
			local baseDir = flat(aimPoint(root, target) - origin)
			if t.jitter then
				baseDir = CFrame.fromAxisAngle(Vector3.yAxis, math.rad((math.random() - 0.5) * t.jitter)) * baseDir
			end
			for _, dir in fan(baseDir, t.count or 1, t.spread or 25) do
				fireOne(origin, dir)
			end
			task.wait(t.burstGap or 0.1)
		end
	end)
end

function Kinds.nova(state, t, color, root, target)
	local center = (t.atTarget and target and not target.dead) and target.root.Position or root.Position
	Effects.Burst(center, t.radius, color)
	Effects.Ring(ground(state, center), t.radius, color)
	if t.radius >= 14 then
		Effects.Shake(center, math.min(0.8, t.radius / 40), t.radius * 3)
	end
	for _, enemy in EnemyService.GetInRadius(state.run, center, t.radius) do
		hitEnemy(state, enemy, t.damage, color, t)
		if t.knockback then
			EnemyService.Push(enemy, center, t.knockback)
		end
		if t.pull then
			EnemyService.Push(enemy, center, -t.pull)
		end
	end
end

local function strikeAt(state, t, color, center)
	local delay = t.delay or 0.5
	Effects.Strike(center, t.radius, delay, color, t.visual)
	task.delay(delay, function()
		if not state.active then
			return
		end
		if t.radius >= 12 then
			Effects.Shake(center, math.min(1, t.radius / 30), t.radius * 4)
		end
		aoe(state, center, t.radius, t.damage, color, t)
	end)
end

function Kinds.strike(state, t, color, root, target)
	local count = t.count or 1
	local area = t.area or 45
	task.spawn(function()
		for _ = 1, count do
			if not state.active or not root.Parent then
				return
			end
			local pos
			if count == 1 and target and not target.dead then
				pos = target.root.Position
			else
				local nearby = EnemyService.GetInRadius(state.run, root.Position, area)
				if #nearby > 0 and math.random() < 0.75 then
					pos = nearby[math.random(#nearby)].root.Position
				else
					local angle, dist = math.random() * math.pi * 2, math.random() * area
					pos = root.Position + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
				end
			end
			strikeAt(state, t, color, ground(state, pos))
			if t.interval then
				task.wait(t.interval)
			end
		end
	end)
end

function Kinds.zone(state, t, color, root, target)
	local center = ground(state, aimPoint(root, target))
	local size = Vector3.new(0.3, t.radius * 2, t.radius * 2)
	local disc = Effects.Part(Enum.PartType.Cylinder, size, CFrame.new(center) * VERTICAL, color, 0.65, t.pull and "vortex" or "zone")
	if t.follow then
		Effects.Attach(disc, root, FEET_OFFSET * VERTICAL)
	end
	Debris:AddItem(disc, t.duration + 1)
	task.spawn(function()
		local tick, elapsed = 0.5, 0
		while elapsed < t.duration and state.active and root.Parent do
			local c = t.follow and ground(state, root.Position) or center
			for _, enemy in EnemyService.GetInRadius(state.run, c, t.radius) do
				hitEnemy(state, enemy, t.dps * tick, color, t)
				if t.pull then
					EnemyService.Push(enemy, c, -t.pull)
				end
			end
			task.wait(tick)
			elapsed += tick
		end
		disc:Destroy()
	end)
end

function Kinds.orbit(state, t, color, root)
	local blades = {}
	for i = 1, t.count do
		blades[i] = Effects.Part(Enum.PartType.Block, Vector3.new(0.6, 0.6, 3), root.CFrame, color, 0, "blade")
	end
	local start = os.clock()
	local lastHit = {}
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - start > t.duration or not state.active or not root.Parent then
			connection:Disconnect()
			for _, blade in blades do
				blade:Destroy()
			end
			return
		end
		local center = root.Position
		for i, blade in blades do
			local angle = now * (t.spin or 3) + (i / t.count) * math.pi * 2
			local p = center + Vector3.new(math.cos(angle) * t.radius, 0, math.sin(angle) * t.radius)
			blade.CFrame = CFrame.lookAt(p, p + Vector3.new(-math.sin(angle), 0, math.cos(angle)))
			for _, enemy in EnemyService.GetInRadius(state.run, p, 2.5) do
				if not lastHit[enemy] or now - lastHit[enemy] >= 0.5 then
					lastHit[enemy] = now
					hitEnemy(state, enemy, t.damage, color, t)
				end
			end
		end
	end)
end

function Kinds.line(state, t, color, root, target)
	local origin = root.Position
	lineHit(state, t, color, origin, flat(aimPoint(root, target) - origin), t.length, t.width, t.damage)
end

function Kinds.beam(state, t, color, root, target)
	task.spawn(function()
		local tick, elapsed = 0.2, 0
		while elapsed < t.duration and state.active and root.Parent do
			local current = EnemyService.Nearest(state.run, root.Position, t.length) or target
			local origin = root.Position
			lineHit(state, t, color, origin, flat(aimPoint(root, current) - origin), t.length, t.width, t.dps * tick)
			task.wait(tick)
			elapsed += tick
		end
	end)
end

function Kinds.chain(state, t, color, root, target)
	local from = root.Position
	local current = target
	local hit = {}
	for _ = 1, t.jumps do
		if not current then
			break
		end
		hit[current] = true
		local pos = current.root.Position
		Effects.Bolt(from, pos, color)
		hitEnemy(state, current, t.damage, color, t)
		from = pos
		local nextTarget, bestDist = nil, t.range or 25
		for _, enemy in EnemyService.GetInRadius(state.run, pos, t.range or 25) do
			local dist = (enemy.root.Position - pos).Magnitude
			if not hit[enemy] and dist <= bestDist then
				nextTarget, bestDist = enemy, dist
			end
		end
		current = nextTarget
	end
end

function Kinds.summon(state, t, color, root)
	local run = state.run
	for _ = 1, t.count do
		local pos = ground(state, root.Position + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))) + Vector3.new(0, 1.5, 0)
		local body = Effects.Part(Enum.PartType.Block, Vector3.new(2, 3, 2), CFrame.new(pos), color, 0.25, "summon")
		Effects.Burst(pos, 4, color, 0.4)
		local start, lastHit = os.clock(), 0
		local connection
		connection = RunService.Heartbeat:Connect(function(dt)
			local now = os.clock()
			if now - start > t.duration or not state.active or not root.Parent then
				connection:Disconnect()
				if t.explode and state.active then
					Effects.Burst(pos, t.explodeRadius or 10, color)
					aoe(state, pos, t.explodeRadius or 10, t.explode, color, t)
				end
				body:Destroy()
				return
			end
			local enemy = EnemyService.Nearest(run, pos, 60)
			local goal = enemy and enemy.root.Position or root.Position
			local delta = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
			local stopAt = enemy and (enemy.radius + 2) or 6
			if delta.Magnitude > stopAt then
				pos += delta.Unit * math.min(delta.Magnitude - stopAt, (t.speed or 22) * dt)
			elseif enemy and now - lastHit > 0.6 then
				lastHit = now
				hitEnemy(state, enemy, t.damage, color, t)
			end
			body.CFrame = CFrame.lookAt(pos, pos + (delta.Magnitude > 0.1 and delta.Unit or Vector3.new(0, 0, -1)))
				* CFrame.new(0, math.sin(now * 8) * 0.2, 0)
		end)
	end
end

function Kinds.shield(state, t, color, root)
	local now = os.clock()
	if now >= state.shieldUntil then
		state.shield = 0
	end
	state.shield = math.max(state.shield, t.absorb)
	state.shieldUntil = math.max(state.shieldUntil, now + t.duration)
	if t.reflect then
		state.reflect = t.reflect
		state.reflectUntil = now + t.duration
	end
	local bubble = Effects.Part(Enum.PartType.Ball, Vector3.one * 8, root.CFrame, color, 0.8, "shield")
	Effects.Attach(bubble, root)
	Debris:AddItem(bubble, t.duration)
	if t.knockback then
		Kinds.nova(state, { radius = t.radius or 10, knockback = t.knockback }, color, root, nil)
	end
end

function Kinds.heal(state, t, color, root)
	local now = os.clock()
	if t.amount then
		Registry.HealPlayer(state.player, t.amount)
	end
	if t.regen then
		state.regen = t.regen
		state.regenUntil = now + t.duration
	end
	if t.invuln then
		state.invulnUntil = math.max(state.invulnUntil, now + t.duration)
		Effects.Glow(root.Parent, color, t.duration)
	end
	Effects.Burst(root.Position, 6, color, 0.5)
end

function Kinds.buff(state, t, color, root)
	state.buffMult = t.damageMult or 1
	state.buffUntil = os.clock() + t.duration
	Effects.Glow(root.Parent, color, t.duration)
	if t.auraDps then
		Kinds.zone(state, { dps = t.auraDps, radius = t.radius or 12, duration = t.duration, follow = true }, color, root, nil)
	end
end

-- API ---------------------------------------------------------------------------

function PowerService.Cast(state, power, t, root, target)
	local kind = Kinds[t.kind]
	if not kind then
		warn("[PowerService] tipo desconhecido: " .. tostring(t.kind))
		return false
	end
	if t.kind == "chain" and not target then
		return false
	end
	if t.kind == "heal" and not t.invuln and not t.regen then
		local _, humanoid = Registry.GetRoot(state.player)
		if humanoid and humanoid.Health >= humanoid.MaxHealth then
			return false
		end
	end
	local color = power.colors and power.colors[math.random(#power.colors)] or power.color
	kind(state, t, color, root, target)
	return true
end

-- chamado todo frame para cada jogador em run: dispara habilidades prontas
function PowerService.Tick(state, now)
	local root = Registry.GetRoot(state.player)
	if not root then
		return
	end
	local nearest, searched = nil, false
	for _, owned in state.powers do
		local power = Powers.ById[owned.id]
		for tierIndex = 1, math.min(owned.tier, 3) do
			local key = owned.id .. tierIndex
			if now >= (state.cooldowns[key] or 0) then
				if not searched then
					nearest = EnemyService.Nearest(state.run, root.Position, COMBAT_RANGE)
					searched = true
				end
				if not nearest then
					return
				end
				local t = power.tiers[tierIndex]
				if PowerService.Cast(state, power, t, root, nearest) then
					state.cooldowns[key] = now + t.cd * state.stats.cooldownMult
				end
			end
		end
	end
end

function PowerService.CastUltimate(state, slot)
	local owned = state.powers[slot]
	if not owned or owned.tier < 4 then
		return false
	end
	local key = owned.id .. "ult"
	local now = os.clock()
	if now < (state.cooldowns[key] or 0) then
		return false
	end
	local root = Registry.GetRoot(state.player)
	if not root then
		return false
	end
	local power = Powers.ById[owned.id]
	local t = power.tiers[4]
	local target = EnemyService.Nearest(state.run, root.Position, 90)
	if not PowerService.Cast(state, power, t, root, target) then
		return false
	end
	state.cooldowns[key] = now + t.cd * state.stats.cooldownMult
	Effects.Glow(root.Parent, power.color, 1.5)
	Effects.Burst(root.Position, 10, power.color, 0.5)
	Effects.Shake(root.Position, 0.5, 80)
	return true, t.name
end

-- Combo de 3 golpes: corte da direita, corte da esquerda, golpe por cima (mais forte, em área).
function PowerService.BasicAttack(state, direction)
	local config = GameConfig.BasicAttack
	local now = os.clock()
	if now - state.lastBasic < config.cooldown then
		return
	end
	if now - state.lastBasic > config.comboReset then
		state.combo = 0
	end
	state.lastBasic = now
	state.combo = (state.combo or 0) % #config.combo + 1
	local step = config.combo[state.combo]

	local root = Registry.GetRoot(state.player)
	if not root then
		return
	end
	local dir = flat(direction)
	local origin = root.Position
	local range = config.range * step.range
	Effects.Swing(state.player, state.combo, origin, dir, range, config.color)

	-- o dano entra no meio da animação do golpe
	task.delay(step.hitDelay, function()
		if not state.active or not root.Parent then
			return
		end
		local hitAny = false
		for _, enemy in EnemyService.GetInRadius(state.run, root.Position, range) do
			local toEnemy = enemy.root.Position - root.Position
			if flat(toEnemy):Dot(dir) > step.arc or toEnemy.Magnitude < enemy.radius + 3 then
				hitEnemy(state, enemy, config.damage * step.damage, config.color, {})
				EnemyService.Push(enemy, root.Position, step.knockback)
				hitAny = true
			end
		end
		if step.slam then
			local g = ground(state, root.Position + dir * 5)
			Effects.Ring(g, range, config.color, 0.35)
			Effects.Shake(g, 0.35, 30)
		elseif hitAny then
			Effects.Shake(root.Position, 0.12, 15)
		end
	end)
end

return PowerService
