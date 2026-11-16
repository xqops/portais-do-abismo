-- Inimigos: criação do modelo, IA, dano, status (lento/congelado/empurrão) e habilidades de chefe.
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Effects = require(script.Parent.Effects)
local Projectiles = require(script.Parent.Projectiles)
local Registry = require(script.Parent.Registry)

local EnemyService = {}

local AI_STEP = 0.1
local DANGER = Color3.fromRGB(255, 50, 40)
local ENEMY_SHOT = Color3.fromRGB(255, 80, 60)
local ICE = Color3.fromRGB(170, 230, 255)
local REFLECT = Color3.fromRGB(90, 200, 255)

local active = {} -- [enemy] = true (todas as runs)

local function makePart(name, size, cframe, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function weld(a, b)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = a
	constraint.Part1 = b
	constraint.Parent = a
end

local function visualPart(part)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Anchored = false
end

-- procura um modelo importado em ReplicatedStorage.Assets.Monsters
local function findMonsterAsset(name)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Monsters")
	return folder and name and folder:FindFirstChild(name)
end

-- Visual a partir de um modelo importado (Toolbox, Blender, 3D Importer...).
-- Ele é escalado para a altura do inimigo, posto no chão e preso ao root.
-- Se o monstro andar de costas, coloque no modelo o atributo Yaw = 180.
local function assetVisual(asset, root, def, model)
	local visual = asset:Clone()
	visual.Name = "Visual"
	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") then
			visualPart(descendant)
		elseif descendant:IsA("Humanoid") or descendant:IsA("BaseScript") or descendant:IsA("AnimationController") then
			descendant:Destroy()
		end
	end
	local primary = visual.PrimaryPart or visual:FindFirstChildWhichIsA("BasePart", true)
	if not primary then
		visual:Destroy()
		return nil
	end

	local yaw = math.rad(asset:GetAttribute("Yaw") or 0)
	visual:PivotTo(CFrame.new(visual:GetPivot().Position) * root.CFrame.Rotation * CFrame.Angles(0, yaw, 0))
	local _, extents = visual:GetBoundingBox()
	local targetHeight = def.size.Y * (asset:GetAttribute("HeightScale") or 1.35)
	if extents.Y > 0.01 then
		visual:ScaleTo(visual:GetScale() * targetHeight / extents.Y)
	end
	local box, size = visual:GetBoundingBox()
	local floorY = root.Position.Y - def.size.Y / 2 - 0.3
	visual:PivotTo(visual:GetPivot() + (Vector3.new(root.Position.X, floorY + size.Y / 2, root.Position.Z) - box.Position))

	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= primary then
			weld(primary, descendant)
		end
	end
	visual.Parent = model
	return primary
end

-- Visual padrão feito de blocos (corpo, cabeça, braços, olhos brilhando)
local function blockVisual(root, def, model)
	local size = def.size
	local rootCf = root.CFrame
	local body = makePart("Body", size, rootCf, def.color, nil, model)
	visualPart(body)

	local headSize = Vector3.new(size.X * 0.8, size.X * 0.7, size.Z * 0.9)
	local headCf = rootCf * CFrame.new(0, size.Y / 2 + headSize.Y / 2, 0)
	local head = makePart("Head", headSize, headCf, def.color:Lerp(Color3.new(1, 1, 1), 0.15), nil, model)
	visualPart(head)
	weld(body, head)

	for _, side in { -1, 1 } do
		local eyeCf = headCf * CFrame.new(side * headSize.X * 0.22, headSize.Y * 0.1, -headSize.Z / 2 - 0.05)
		local eye = makePart("Eye", Vector3.new(headSize.X * 0.18, headSize.Y * 0.18, 0.1), eyeCf, def.eyeColor or DANGER, Enum.Material.Neon, model)
		visualPart(eye)
		weld(head, eye)
		local armSize = Vector3.new(size.X * 0.28, size.Y * 0.7, size.Z * 0.5)
		local armCf = rootCf * CFrame.new(side * (size.X / 2 + armSize.X / 2), size.Y * 0.1, 0)
		local arm = makePart("Arm", armSize, armCf, def.color:Lerp(Color3.new(0, 0, 0), 0.15), nil, model)
		visualPart(arm)
		weld(body, arm)
	end
	return body
end

local function buildModel(def, position)
	local model = Instance.new("Model")
	model.Name = def.name

	-- o root é a "caixa de colisão" invisível; o visual fica preso a ele por um Motor6D
	-- chamado "Visual", que o cliente anima (balanço ao andar, investida, recuo ao levar dano)
	local size = def.size
	local rootCf = CFrame.new(position + Vector3.new(0, size.Y / 2 + 0.3, 0))
	local root = makePart("HumanoidRootPart", size, rootCf, def.color, nil, model)
	root.Transparency = 1

	local asset = findMonsterAsset(def.model) or findMonsterAsset(def.name)
	local visualRoot = asset and assetVisual(asset, root, def, model)
	if not visualRoot then
		visualRoot = blockVisual(root, def, model)
	end
	local joint = Instance.new("Motor6D")
	joint.Name = "Visual"
	joint.Part0 = root
	joint.Part1 = visualRoot
	joint.C0 = root.CFrame:ToObjectSpace(visualRoot.CFrame)
	joint.Parent = root

	-- cabeça invisível para o nome e a barra de vida aparecerem
	if not model:FindFirstChild("Head") then
		local anchorHead = makePart("Head", Vector3.one, rootCf * CFrame.new(0, size.Y / 2 + 1.5, 0), def.color, nil, model)
		anchorHead.Transparency = 1
		visualPart(anchorHead)
		weld(root, anchorHead)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 0.3
	humanoid.MaxHealth = def.hp
	humanoid.Health = def.hp
	humanoid.WalkSpeed = def.speed
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.NameDisplayDistance = def.boss and 200 or 40
	humanoid.HealthDisplayDistance = def.boss and 200 or 60
	humanoid.HealthDisplayType = def.boss and Enum.HumanoidHealthDisplayType.AlwaysOn or Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid.Parent = model

	model.PrimaryPart = root
	return model, root, humanoid
end

local function flatDistance(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function playersNear(run, pos, radius)
	local list = {}
	for player, state in run.players do
		if state.active then
			local root = Registry.GetRoot(player)
			if root and flatDistance(root.Position, pos) <= radius + 1.5 and math.abs(root.Position.Y - pos.Y) < 10 then
				table.insert(list, player)
			end
		end
	end
	return list
end

local function nearestPlayer(enemy)
	local best, bestRoot, bestDist = nil, nil, math.huge
	local pos = enemy.root.Position
	for player, state in enemy.run.players do
		if state.active then
			local root, humanoid = Registry.GetRoot(player)
			if root and humanoid and humanoid.Health > 0 then
				local dist = (root.Position - pos).Magnitude
				if dist < bestDist then
					best, bestRoot, bestDist = player, root, dist
				end
			end
		end
	end
	return best, bestRoot, bestDist
end

local function ground(enemy, pos)
	return Vector3.new(pos.X, enemy.run.floorY, pos.Z)
end

-- contador lido pelo cliente para disparar animações (investida, recuo...)
local function bump(enemy, attribute)
	enemy.model:SetAttribute(attribute, (enemy.model:GetAttribute(attribute) or 0) + 1)
end

local function hitPlayer(enemy, player, amount)
	bump(enemy, "Attack")
	local dealt = Registry.DamagePlayer(player, amount)
	local state = Registry.ByPlayer[player]
	if state and state.reflect > 0 and os.clock() < state.reflectUntil and not enemy.dead then
		EnemyService.Damage(enemy, amount * state.reflect, player, REFLECT)
	end
	return dealt
end

local function shoot(enemy, targetRoot)
	local run = enemy.run
	local origin = enemy.root.Position + Vector3.new(0, enemy.def.size.Y * 0.3, 0)
	local dir = targetRoot.Position - origin
	bump(enemy, "Attack")
	Projectiles.Fire({
		origin = origin,
		direction = Vector3.new(dir.X, 0, dir.Z),
		speed = enemy.def.projectileSpeed or 45,
		range = (enemy.def.range or 40) + 15,
		size = 1,
		color = ENEMY_SHOT,
		visual = "enemy",
		hitTest = function(pos, radius)
			return playersNear(run, pos, radius)
		end,
		onHit = function(player)
			hitPlayer(enemy, player, enemy.def.damage)
		end,
	})
end

-- Habilidades de chefe ------------------------------------------------------

local BossSkills = {}

function BossSkills.slam(enemy)
	local radius = enemy.radius * 2 + 10
	local center = ground(enemy, enemy.root.Position)
	enemy.castingUntil = os.clock() + 1.3
	Effects.Telegraph(center, radius, 1.2, DANGER)
	task.delay(1.2, function()
		if enemy.dead then
			return
		end
		bump(enemy, "Attack")
		Effects.Burst(center, radius, enemy.def.color, 0.4)
		Effects.Ring(center, radius * 1.2, DANGER, 0.5)
		Effects.Shake(center, 0.7, 70)
		for _, player in playersNear(enemy.run, center, radius) do
			hitPlayer(enemy, player, enemy.def.damage * 1.6)
		end
	end)
end

function BossSkills.volley(enemy)
	for player, state in enemy.run.players do
		local root = state.active and Registry.GetRoot(player)
		if root then
			local center = ground(enemy, root.Position)
			Effects.Strike(center, 7, 1.3, DANGER, "meteor")
			task.delay(1.3, function()
				if enemy.dead then
					return
				end
				for _, hit in playersNear(enemy.run, center, 7) do
					hitPlayer(enemy, hit, enemy.def.damage)
				end
			end)
		end
	end
end

function BossSkills.ring(enemy)
	enemy.castingUntil = os.clock() + 1.6
	for wave = 0, 2 do
		if enemy.dead then
			return
		end
		local origin = enemy.root.Position
		for i = 0, 15 do
			local angle = (i / 16) * math.pi * 2 + wave * math.rad(11.25)
			local run = enemy.run
			Projectiles.Fire({
				origin = origin,
				direction = Vector3.new(math.cos(angle), 0, math.sin(angle)),
				speed = 35,
				range = 90,
				size = 1.6,
				color = ENEMY_SHOT,
				visual = "enemy",
				hitTest = function(pos, radius)
					return playersNear(run, pos, radius)
				end,
				onHit = function(player)
					hitPlayer(enemy, player, enemy.def.damage * 0.7)
				end,
			})
		end
		task.wait(0.5)
	end
end

function BossSkills.summon(enemy)
	local run = enemy.run
	enemy.castingUntil = os.clock() + 1
	Effects.Burst(enemy.root.Position, 14, enemy.def.color, 0.6)
	local count = 3 + run:PlayerCount()
	for _ = 1, count do
		local offset = Vector3.new(math.random(-12, 12), 0, math.random(-12, 12))
		run:SpawnMob("chaser", run.def.waves, ground(enemy, enemy.root.Position + offset))
	end
end

function BossSkills.charge(enemy, _, targetRoot)
	local from = ground(enemy, enemy.root.Position)
	local to = ground(enemy, targetRoot.Position)
	local dir = to - from
	if dir.Magnitude < 1 then
		return
	end
	local finish = from + dir.Unit * math.min(dir.Magnitude + 15, 80)
	enemy.castingUntil = os.clock() + 0.8
	Effects.Beam(from + Vector3.new(0, 0.2, 0), finish + Vector3.new(0, 0.2, 0), enemy.radius * 2, DANGER, 0.8)
	task.delay(0.8, function()
		if enemy.dead then
			return
		end
		enemy.chargeUntil = os.clock() + 1
		enemy.humanoid:MoveTo(finish)
	end)
end

-- IA -------------------------------------------------------------------------

local function stepEnemy(enemy, now)
	local root, humanoid, def = enemy.root, enemy.humanoid, enemy.def
	if not root.Parent or root.Position.Y < enemy.run.floorY - 30 then
		EnemyService.Kill(enemy, true)
		return
	end

	if now < enemy.frozenUntil or now < enemy.castingUntil then
		humanoid.WalkSpeed = 0
		return
	end

	local player, targetRoot, dist = nearestPlayer(enemy)

	if now < enemy.chargeUntil then
		humanoid.WalkSpeed = def.speed * 5
		if player and dist <= enemy.radius + 4 and now - enemy.lastAttack >= def.attackCd then
			enemy.lastAttack = now
			hitPlayer(enemy, player, def.damage * 1.5)
		end
		return
	end

	local speedMult = now < enemy.slowUntil and enemy.slowMult or 1
	humanoid.WalkSpeed = def.speed * speedMult

	if not player then
		humanoid:MoveTo(root.Position)
		return
	end

	if def.boss and now - enemy.lastSkill >= def.skillCd then
		enemy.lastSkill = now
		local skill = BossSkills[def.skills[math.random(#def.skills)]]
		if skill then
			task.defer(skill, enemy, player, targetRoot)
		end
	end

	if def.ranged then
		if dist > def.range * 0.8 then
			humanoid:MoveTo(targetRoot.Position)
		else
			humanoid:MoveTo(root.Position)
			root.CFrame = CFrame.lookAt(root.Position, Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z))
		end
		if dist <= def.range and now - enemy.lastAttack >= def.attackCd then
			enemy.lastAttack = now
			shoot(enemy, targetRoot)
		end
	else
		humanoid:MoveTo(targetRoot.Position)
		local reach = (def.reach or 2) + enemy.radius + 1.5
		if dist <= reach and now - enemy.lastAttack >= def.attackCd then
			enemy.lastAttack = now
			hitPlayer(enemy, player, def.damage)
		end
	end
end

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < AI_STEP then
		return
	end
	accumulator = 0
	local now = os.clock()
	-- cópia, porque inimigos podem morrer/nascer durante o passo
	local list = {}
	for enemy in active do
		table.insert(list, enemy)
	end
	for _, enemy in list do
		if not enemy.dead then
			local ok, err = pcall(stepEnemy, enemy, now)
			if not ok then
				warn("[EnemyService] " .. tostring(err))
			end
		end
	end
end)

-- API --------------------------------------------------------------------------

function EnemyService.Spawn(run, def, position)
	local model, root, humanoid = buildModel(def, position)
	local enemy = {
		def = def,
		run = run,
		model = model,
		root = root,
		humanoid = humanoid,
		radius = math.max(def.size.X, def.size.Z) / 2,
		dead = false,
		lastAttack = 0,
		lastSkill = os.clock(),
		slowUntil = 0,
		slowMult = 1,
		frozenUntil = 0,
		castingUntil = 0,
		chargeUntil = 0,
		lastHitBy = nil,
	}
	model:SetAttribute("Boss", def.boss == true)
	model.Parent = run.enemyFolder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	CollectionService:AddTag(model, "Enemy")
	run.enemies[enemy] = true
	active[enemy] = true
	Effects.Send("spawn", { pos = position, size = def.size.X, color = run.def.theme.accent, boss = def.boss == true })
	return enemy
end

function EnemyService.Damage(enemy, amount, player, color)
	if enemy.dead then
		return 0
	end
	amount = math.max(1, math.floor(amount + 0.5))
	local humanoid = enemy.humanoid
	humanoid.Health = math.max(0, humanoid.Health - amount)
	if player then
		enemy.lastHitBy = player
	end
	bump(enemy, "Hit")
	enemy.run:DamageNumber(enemy.root.Position + Vector3.new(0, enemy.def.size.Y / 2, 0), amount, color)
	if humanoid.Health <= 0 then
		EnemyService.Kill(enemy)
	end
	return amount
end

-- silent = true: remove sem dar XP/recompensa (fim da run, caiu do mapa...)
function EnemyService.Kill(enemy, silent)
	if enemy.dead then
		return
	end
	enemy.dead = true
	active[enemy] = nil
	enemy.run.enemies[enemy] = nil
	if not silent then
		enemy.run:OnEnemyKilled(enemy)
	end
	local model = enemy.model
	if model.Parent then
		if not silent then
			Effects.Kill(enemy.root.Position, enemy.radius, enemy.def.color, enemy.lastHitBy, enemy.def.boss == true)
		end
		-- o cliente faz a animação de queda; aqui só desliga a colisão e some depois
		model:SetAttribute("Dead", true)
		enemy.root.Anchored = true
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanQuery = false
			end
		end
		Debris:AddItem(model, 0.7)
	end
end

function EnemyService.Slow(enemy, mult, duration)
	if enemy.dead then
		return
	end
	local now = os.clock()
	local current = now < enemy.slowUntil and enemy.slowMult or 1
	enemy.slowMult = math.min(current, mult)
	enemy.slowUntil = math.max(enemy.slowUntil, now + duration)
end

function EnemyService.Freeze(enemy, duration)
	if enemy.dead then
		return
	end
	if enemy.def.boss then
		duration *= 0.3
	end
	enemy.frozenUntil = math.max(enemy.frozenUntil, os.clock() + duration)
	local ice = Effects.Part(Enum.PartType.Block, enemy.def.size + Vector3.one * 0.8, enemy.root.CFrame, ICE, 0.5, "ice")
	ice.Material = Enum.Material.Ice
	Debris:AddItem(ice, duration)
end

-- força positiva empurra para longe de `fromPos`, negativa puxa para ele
function EnemyService.Push(enemy, fromPos, force)
	if enemy.dead then
		return
	end
	if enemy.def.boss then
		force *= 0.15
	end
	local delta = Vector3.new(enemy.root.Position.X - fromPos.X, 0, enemy.root.Position.Z - fromPos.Z)
	if delta.Magnitude < 1 then
		return
	end
	enemy.root.AssemblyLinearVelocity = delta.Unit * force + Vector3.new(0, math.abs(force) * 0.15, 0)
end

function EnemyService.GetInRadius(run, pos, radius)
	local list = {}
	if not run then
		return list
	end
	for enemy in run.enemies do
		if not enemy.dead then
			local p = enemy.root.Position
			if flatDistance(p, pos) <= radius + enemy.radius and math.abs(p.Y - pos.Y) <= 15 then
				table.insert(list, enemy)
			end
		end
	end
	return list
end

function EnemyService.Nearest(run, pos, maxDist)
	local best, bestDist = nil, maxDist
	if not run then
		return nil
	end
	for enemy in run.enemies do
		if not enemy.dead then
			local dist = flatDistance(enemy.root.Position, pos)
			if dist <= bestDist then
				best, bestDist = enemy, dist
			end
		end
	end
	return best
end

return EnemyService
