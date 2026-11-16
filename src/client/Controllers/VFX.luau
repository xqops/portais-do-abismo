--[[
	Desenha todos os efeitos visuais no cliente.

	- Efeitos instantâneos chegam pelo remote "Fx" (explosão, golpe do céu, raio, morte...).
	- Objetos que duram (projéteis, lâminas, zonas, orbes) são Parts do servidor em workspace.FX
	  com o atributo "Fx"; aqui eles ganham rastro, brilho, partículas e forma (espada, lança...).

	Quer trocar um efeito por um pack baixado (Toolbox/Creator Store)?
	Coloque o modelo em ReplicatedStorage.Assets.VFX com um destes nomes:
	  Explosion, Hit, Death, Spawn, LevelUp, Strike_sword, Strike_meteor, Strike_lightning,
	  Strike_orbital, Strike_void, Strike_pillar
	Todo ParticleEmitter dentro dele é disparado (atributo EmitCount = quantidade, padrão 25),
	escalado pelo raio do efeito. Os efeitos padrão abaixo continuam sendo usados se não houver modelo.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local player = Players.LocalPlayer

local VFX = {}

-- texturas que já vêm com o Roblox (não precisam de upload)
local TEX = {
	spark = "rbxasset://textures/particles/sparkles_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
	fireSpark = "rbxasset://textures/particles/fire_sparks_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	core = "rbxasset://textures/particles/explosion01_core_main.dds",
	shock = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	implode = "rbxasset://textures/particles/explosion01_implosion_main.dds",
	glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
}
local SOUND = {
	slash = "rbxasset://sounds/swordslash.wav",
	lunge = "rbxasset://sounds/swordlunge.wav",
	ping = "rbxasset://sounds/electronicpingshort.wav",
}
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 210, 90)

local fxFolder = Instance.new("Folder")
fxFolder.Name = "ClientFX"
fxFolder.Parent = workspace

-- utilidades ----------------------------------------------------------------------

local function tween(instance, time, props, style, direction)
	local t = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function neon(shape, size, cframe, color, transparency)
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = fxFolder
	return part
end

local function holder(cframe, size)
	local part = neon(Enum.PartType.Block, size or Vector3.one, cframe, WHITE, 1)
	return part
end

local function particles(parent, props)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Texture = TEX.spark
	for key, value in props do
		emitter[key] = value
	end
	emitter.Parent = parent
	return emitter
end

local function pointLight(parent, color, range, brightness, time)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = math.min(range, 60)
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
	if time then
		tween(light, time, { Brightness = 0 })
	end
	return light
end

local function trail(part, offsetA, offsetB, color, lifetime)
	local a0 = Instance.new("Attachment")
	a0.Position = offsetA
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = offsetB
	a1.Parent = part
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Color = ColorSequence.new(WHITE, color)
	t.Transparency = NumberSequence.new(0.1, 1)
	t.WidthScale = NumberSequence.new(1, 0.2)
	t.Lifetime = lifetime or 0.25
	t.LightEmission = 1
	t.LightInfluence = 0
	t.Parent = part
	return t
end

local function playSound(id, position, volume, speed)
	local h = holder(CFrame.new(position))
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = (speed or 1) * (0.9 + math.random() * 0.2)
	sound.RollOffMaxDistance = 120
	sound.Parent = h
	sound:Play()
	Debris:AddItem(h, 2)
end
VFX.PlaySound = playSound
VFX.Sounds = SOUND

-- modelo de efeito baixado (ReplicatedStorage.Assets.VFX)
local function playTemplate(name, position, radius)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("VFX")
	local template = folder and folder:FindFirstChild(name)
	if not template then
		return false
	end
	local clone = template:Clone()
	if clone:IsA("Model") then
		clone:PivotTo(CFrame.new(position))
	elseif clone:IsA("BasePart") then
		clone.CFrame = CFrame.new(position)
	end
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
		end
	end
	clone.Parent = fxFolder
	local scale = math.max(0.3, (radius or 5) / 5)
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			if scale ~= 1 then
				local points = {}
				for _, point in descendant.Size.Keypoints do
					table.insert(points, NumberSequenceKeypoint.new(point.Time, point.Value * scale, point.Envelope * scale))
				end
				descendant.Size = NumberSequence.new(points)
			end
			descendant:Emit(descendant:GetAttribute("EmitCount") or 25)
		end
	end
	Debris:AddItem(clone, 4)
	return true
end

-- tremor de câmera -------------------------------------------------------------------

local trauma = 0

function VFX.Shake(intensity)
	trauma = math.min(1, trauma + intensity)
end

local function shakeNear(pos, intensity, radius)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local dist = (root.Position - pos).Magnitude
	if dist < radius then
		VFX.Shake(intensity * (1 - dist / radius))
	end
end

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if trauma > 0 then
		local power = trauma * trauma * 1.4
		humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * power, (math.random() - 0.5) * power, (math.random() - 0.5) * power)
		trauma = math.max(0, trauma - dt * 2.2)
	elseif humanoid.CameraOffset ~= Vector3.zero then
		humanoid.CameraOffset = Vector3.zero
	end
end)

-- peças básicas de efeito -------------------------------------------------------------

local function groundRing(pos, radius, color, time, texture)
	local h = holder(CFrame.new(pos + Vector3.new(0, 0.15, 0)), Vector3.new(radius * 0.3, 0.05, radius * 0.3))
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	decal.Texture = texture or TEX.shock
	decal.Color3 = color
	decal.Parent = h
	tween(h, time, { Size = Vector3.new(radius * 2.6, 0.05, radius * 2.6) })
	tween(decal, time, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(h, time + 0.05)
end

function VFX.Burst(pos, radius, color, time)
	time = time or 0.35
	if playTemplate("Explosion", pos, radius) then
		return
	end
	local shell = neon(Enum.PartType.Ball, Vector3.one * radius * 0.4, CFrame.new(pos), color, 0.15)
	tween(shell, time, { Size = Vector3.one * radius * 2.2, Transparency = 1 })
	Debris:AddItem(shell, time + 0.05)
	local core = neon(Enum.PartType.Ball, Vector3.one * radius * 0.5, CFrame.new(pos), WHITE, 0)
	tween(core, time * 0.5, { Size = Vector3.one * radius * 1.1, Transparency = 1 })
	Debris:AddItem(core, time)

	local h = holder(CFrame.new(pos), Vector3.one * math.max(1, radius * 0.4))
	particles(h, {
		Texture = TEX.fireSpark,
		Color = ColorSequence.new(WHITE, color),
		Size = NumberSequence.new(math.min(3, radius * 0.12 + 0.4), 0),
		Lifetime = NumberRange.new(0.3, 0.7),
		Speed = NumberRange.new(radius * 2, radius * 5),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
		Acceleration = Vector3.new(0, -25, 0),
	}):Emit(math.clamp(math.floor(radius * 3), 8, 40))
	particles(h, {
		Texture = TEX.smoke,
		LightEmission = 0.15,
		Color = ColorSequence.new(color:Lerp(Color3.new(0, 0, 0), 0.5)),
		Size = NumberSequence.new(radius * 0.5, radius * 1.1),
		Transparency = NumberSequence.new(0.45, 1),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(radius * 0.8, radius * 1.6),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
	}):Emit(math.clamp(math.floor(radius / 2), 3, 10))
	particles(h, {
		Texture = TEX.core,
		Color = ColorSequence.new(color),
		Size = NumberSequence.new(radius * 1.4, radius * 2.2),
		Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.25),
		Speed = NumberRange.new(0),
	}):Emit(1)
	pointLight(h, color, radius * 3, 5, 0.45)
	Debris:AddItem(h, 1.2)
end

function VFX.Ring(pos, radius, color, time)
	groundRing(pos, radius, color, time or 0.45)
end

function VFX.Telegraph(pos, radius, delay, color)
	local cf = CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local outer = neon(Enum.PartType.Cylinder, Vector3.new(0.12, radius * 2, radius * 2), cf, color, 0.8)
	local inner = neon(Enum.PartType.Cylinder, Vector3.new(0.16, 0.4, 0.4), cf, color, 0.4)
	tween(inner, delay, { Size = Vector3.new(0.16, radius * 2, radius * 2) }, Enum.EasingStyle.Linear)
	local h = holder(CFrame.new(pos + Vector3.new(0, 0.2, 0)), Vector3.new(radius * 2, 0.05, radius * 2))
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	decal.Texture = TEX.shock
	decal.Color3 = color
	decal.Transparency = 0.3
	decal.Parent = h
	Debris:AddItem(outer, delay)
	Debris:AddItem(inner, delay)
	Debris:AddItem(h, delay)
end

-- espada fantasma: ponta na origem, lâmina subindo no +Y do `cframe`
local function buildGhostSword(cframe, length, width, color, transparency, anchored)
	local parts = {}
	local function add(size, offset, partColor, shape)
		local part = neon(shape or Enum.PartType.Block, size, cframe * offset, partColor, transparency)
		part.Anchored = anchored
		table.insert(parts, part)
		return part
	end
	local blade = length * 0.72
	add(Vector3.new(width, blade, width * 0.2), CFrame.new(0, width * 0.35 + blade / 2, 0), color)
	add(Vector3.new(width * 0.25, blade * 0.92, width * 0.26), CFrame.new(0, width * 0.35 + blade / 2, 0), WHITE)
	add(Vector3.new(width * 0.71, width * 0.71, width * 0.2), CFrame.new(0, width * 0.35, 0) * CFrame.Angles(0, 0, math.rad(45)), color)
	add(Vector3.new(width * 3.2, width * 0.45, width * 0.5), CFrame.new(0, width * 0.35 + blade, 0), color:Lerp(WHITE, 0.4))
	add(Vector3.new(width * 0.45, length * 0.2, width * 0.45), CFrame.new(0, width * 0.35 + blade + length * 0.1 + width * 0.2, 0), color:Lerp(Color3.new(0, 0, 0), 0.3))
	add(Vector3.one * width * 0.8, CFrame.new(0, width * 0.35 + blade + length * 0.22, 0), color:Lerp(WHITE, 0.4), Enum.PartType.Ball)
	return parts
end

local function moveParts(parts, from, to)
	local offset = to * from:Inverse()
	for _, part in parts do
		part.CFrame = offset * part.CFrame
	end
end

local function fadeParts(parts, time)
	for _, part in parts do
		tween(part, time, { Transparency = 1 })
		Debris:AddItem(part, time + 0.05)
	end
end

-- animação por frame com alpha 0..1
local function animate(duration, step, done)
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local alpha = math.min(1, (os.clock() - start) / duration)
		step(alpha)
		if alpha >= 1 then
			connection:Disconnect()
			if done then
				done()
			end
		end
	end)
end

-- golpes que caem do céu -------------------------------------------------------------

local StrikeVisuals = {}

function StrikeVisuals.sword(pos, radius, delay, color)
	local length = math.clamp(radius * 1.8, 6, 40)
	local width = length * 0.12
	local high = CFrame.new(pos + Vector3.new(0, 70, 0))
	local parts = buildGhostSword(high, length, width, color, 0.15, true)
	local current = high
	animate(delay, function(alpha)
		local y = 70 * (1 - alpha * alpha) - length * 0.2 * alpha
		local target = CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, alpha * math.pi * 0.5, 0)
		moveParts(parts, current, target)
		current = target
	end, function()
		task.delay(0.35, function()
			fadeParts(parts, 0.3)
		end)
	end)
end

function StrikeVisuals.meteor(pos, radius, delay, color)
	local start = pos + Vector3.new(-30, 80, 25)
	local size = math.clamp(radius * 0.55, 1.5, 18)
	local ball = neon(Enum.PartType.Ball, Vector3.one * size, CFrame.new(start), color, 0)
	local fire = particles(ball, {
		Texture = TEX.fire,
		Enabled = true,
		Rate = 70,
		Color = ColorSequence.new(WHITE, color),
		Size = NumberSequence.new(size * 0.9, 0),
		Lifetime = NumberRange.new(0.25, 0.5),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top,
	})
	trail(ball, Vector3.new(size * 0.4, 0, 0), Vector3.new(-size * 0.4, 0, 0), color, 0.35)
	pointLight(ball, color, size * 4, 3)
	animate(delay, function(alpha)
		ball.CFrame = CFrame.new(start:Lerp(pos, alpha * alpha))
	end, function()
		fire.Enabled = false
		ball.Transparency = 1
		Debris:AddItem(ball, 0.6)
	end)
end

local function lightning(from, to, color, thickness)
	local segments = 8
	local last = from
	local parts = {}
	for i = 1, segments do
		local point = from:Lerp(to, i / segments)
		if i < segments then
			point += Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * (from - to).Magnitude * 0.08
		end
		local dist = (point - last).Magnitude
		if dist > 0.05 then
			local cf = CFrame.lookAt((last + point) / 2, point)
			table.insert(parts, neon(Enum.PartType.Block, Vector3.new(thickness, thickness, dist), cf, color, 0))
			table.insert(parts, neon(Enum.PartType.Block, Vector3.new(thickness * 0.4, thickness * 0.4, dist), cf, WHITE, 0))
		end
		last = point
	end
	local h = holder(CFrame.new(to))
	pointLight(h, color, 50, 8, 0.3)
	Debris:AddItem(h, 0.4)
	-- piscada
	task.delay(0.06, function()
		for _, part in parts do
			part.Transparency = 0.7
		end
		task.wait(0.04)
		for _, part in parts do
			part.Transparency = 0
		end
		fadeParts(parts, 0.2)
	end)
end
VFX.Lightning = lightning

function StrikeVisuals.lightning(pos, radius, delay, color)
	task.delay(math.max(0, delay - 0.05), function()
		lightning(pos + Vector3.new(0, 80, 0), pos, color, math.clamp(radius * 0.08, 0.3, 1.5))
	end)
end

local function pillar(pos, radius, color, width)
	local column = neon(Enum.PartType.Cylinder, Vector3.new(80, width, width), CFrame.new(pos + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, 0.1)
	tween(column, 0.35, { Size = Vector3.new(80, 0.1, 0.1), Transparency = 1 })
	Debris:AddItem(column, 0.4)
	local inner = neon(Enum.PartType.Cylinder, Vector3.new(80, width * 0.4, width * 0.4), column.CFrame, WHITE, 0)
	tween(inner, 0.25, { Size = Vector3.new(80, 0.1, 0.1), Transparency = 1 })
	Debris:AddItem(inner, 0.3)
end

function StrikeVisuals.pillar(pos, radius, delay, color)
	task.delay(math.max(0, delay - 0.08), function()
		pillar(pos, radius, color, math.max(1.5, radius * 0.4))
	end)
end

function StrikeVisuals.orbital(pos, radius, delay, color)
	local guide = neon(Enum.PartType.Cylinder, Vector3.new(80, 0.4, 0.4), CFrame.new(pos + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, 0.4)
	Debris:AddItem(guide, delay)
	task.delay(math.max(0, delay - 0.05), function()
		pillar(pos, radius, color, radius * 1.4)
	end)
end

function StrikeVisuals.void(pos, radius, delay, color)
	local h = holder(CFrame.new(pos + Vector3.new(0, 2, 0)), Vector3.one * radius)
	local implode = particles(h, {
		Texture = TEX.implode,
		Enabled = true,
		Rate = 20,
		Color = ColorSequence.new(color),
		Size = NumberSequence.new(radius * 1.5, 0),
		Transparency = NumberSequence.new(0.3, 1),
		Lifetime = NumberRange.new(0.4),
		Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-180, 180),
	})
	local orb = neon(Enum.PartType.Ball, Vector3.one * radius * 0.2, CFrame.new(pos + Vector3.new(0, 2, 0)), Color3.new(0.05, 0, 0.1), 0)
	tween(orb, delay, { Size = Vector3.one * radius * 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(orb, delay)
	task.delay(delay, function()
		implode.Enabled = false
		Debris:AddItem(h, 0.5)
	end)
end

function VFX.Strike(data)
	local pos, radius, delay, color, visual = data.pos, data.radius, data.delay, data.color, data.visual
	VFX.Telegraph(pos, radius, delay, color)
	if not playTemplate("Strike_" .. visual, pos, radius) then
		local draw = StrikeVisuals[visual] or StrikeVisuals.pillar
		draw(pos, radius, delay, color)
	end
	task.delay(delay, function()
		VFX.Burst(pos + Vector3.new(0, radius * 0.25, 0), radius, color)
		groundRing(pos, radius, color, 0.5)
	end)
end

-- impactos, morte, nascimento ---------------------------------------------------------

function VFX.HitSpark(pos, color)
	if playTemplate("Hit", pos, 2) then
		return
	end
	local h = holder(CFrame.new(pos))
	particles(h, {
		Color = ColorSequence.new(WHITE, color),
		Size = NumberSequence.new(0.6, 0),
		Lifetime = NumberRange.new(0.15, 0.3),
		Speed = NumberRange.new(15, 30),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 6,
	}):Emit(6)
	Debris:AddItem(h, 0.5)
end

-- contador de combo (abates seguidos do jogador local)
local comboLabel
local comboCount, comboToken = 0, 0
local function bumpCombo()
	if not comboLabel then
		local gui = Instance.new("ScreenGui")
		gui.Name = "Combo"
		gui.ResetOnSpawn = false
		gui.Parent = player:WaitForChild("PlayerGui")
		comboLabel = Instance.new("TextLabel")
		comboLabel.AnchorPoint = Vector2.new(1, 0.5)
		comboLabel.Position = UDim2.new(1, -30, 0.45, 0)
		comboLabel.Size = UDim2.fromOffset(260, 60)
		comboLabel.BackgroundTransparency = 1
		comboLabel.Font = Enum.Font.GothamBlack
		comboLabel.TextSize = 44
		comboLabel.TextXAlignment = Enum.TextXAlignment.Right
		comboLabel.TextColor3 = GOLD
		comboLabel.TextStrokeTransparency = 0.2
		comboLabel.TextTransparency = 1
		comboLabel.TextStrokeTransparency = 1
		comboLabel.Parent = gui
	end
	comboCount += 1
	comboToken += 1
	local token = comboToken
	comboLabel.Text = comboCount .. "x ABATES"
	comboLabel.TextTransparency = 0
	comboLabel.TextStrokeTransparency = 0.2
	comboLabel.TextSize = 54
	comboLabel.TextColor3 = comboCount >= 50 and Color3.fromRGB(255, 80, 80) or (comboCount >= 20 and Color3.fromRGB(255, 150, 60) or GOLD)
	tween(comboLabel, 0.15, { TextSize = 44 })
	task.delay(2.5, function()
		if token == comboToken then
			comboCount = 0
			tween(comboLabel, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

function VFX.Kill(data)
	local pos, size, color = data.pos, data.size, data.color
	if data.killer == player then
		bumpCombo()
	end
	if data.boss then
		VFX.Burst(pos, 30, color, 0.8)
		groundRing(pos - Vector3.new(0, 4, 0), 40, GOLD, 1)
		VFX.Shake(1)
		return
	end
	if playTemplate("Death", pos, size) then
		return
	end
	-- pedaços voando
	for _ = 1, 6 do
		local chunk = neon(Enum.PartType.Block, Vector3.one * (size * 0.3 + math.random() * 0.4), CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), color, 0)
		chunk.Material = Enum.Material.SmoothPlastic
		chunk.Anchored = false
		chunk.AssemblyLinearVelocity = Vector3.new(math.random(-20, 20), math.random(15, 30), math.random(-20, 20))
		chunk.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
		tween(chunk, 0.9, { Size = Vector3.one * 0.05 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(chunk, 0.9)
	end
	local h = holder(CFrame.new(pos))
	particles(h, {
		Texture = TEX.smoke,
		LightEmission = 0.2,
		Color = ColorSequence.new(color:Lerp(WHITE, 0.3)),
		Size = NumberSequence.new(size * 1.2, size * 2.2),
		Transparency = NumberSequence.new(0.3, 1),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(3, 8),
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360),
	}):Emit(5)
	particles(h, {
		Color = ColorSequence.new(WHITE, color),
		Size = NumberSequence.new(0.8, 0),
		Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(10, 25),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 5,
	}):Emit(12)
	Debris:AddItem(h, 1)
end

function VFX.Spawn(data)
	local pos, size, color = data.pos, data.size, data.color
	if playTemplate("Spawn", pos, size) then
		return
	end
	groundRing(pos, size * (data.boss and 4 or 1.6), color, data.boss and 1.2 or 0.6, TEX.vortex)
	local h = holder(CFrame.new(pos + Vector3.new(0, 1, 0)), Vector3.new(size, 0.2, size))
	particles(h, {
		Texture = TEX.spark,
		Color = ColorSequence.new(color),
		Size = NumberSequence.new(0.8, 0),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(6, 14),
		SpreadAngle = Vector2.new(15, 15),
		EmissionDirection = Enum.NormalId.Top,
	}):Emit(data.boss and 60 or 12)
	Debris:AddItem(h, 1)
	if data.boss then
		VFX.Shake(0.8)
	end
end

function VFX.LevelUp(data)
	local character = data.player and data.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if playTemplate("LevelUp", root.Position, 6) then
		return
	end
	local ground = root.Position - Vector3.new(0, 2.9, 0)
	pillar(ground, 6, GOLD, 5)
	groundRing(ground, 8, GOLD, 0.6)
	local h = holder(CFrame.new(ground), Vector3.new(4, 0.2, 4))
	particles(h, {
		Color = ColorSequence.new(WHITE, GOLD),
		Size = NumberSequence.new(0.7, 0),
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(10, 10),
		EmissionDirection = Enum.NormalId.Top,
	}):Emit(40)
	Debris:AddItem(h, 1.5)
	if data.player == player then
		playSound(SOUND.ping, root.Position, 0.6, 1.2)
	end
end

function VFX.Beam(data)
	local from, to, width, color, time = data.from, data.to, data.width, data.color, data.time
	local dist = (to - from).Magnitude
	local cf = CFrame.lookAt((from + to) / 2, to)
	local outer = neon(Enum.PartType.Block, Vector3.new(width, width, dist), cf, color, 0.15)
	local inner = neon(Enum.PartType.Block, Vector3.new(width * 0.35, width * 0.35, dist), cf, WHITE, 0)
	tween(outer, time, { Size = Vector3.new(width * 0.1, width * 0.1, dist), Transparency = 1 })
	tween(inner, time, { Size = Vector3.new(0.05, 0.05, dist), Transparency = 1 })
	Debris:AddItem(outer, time + 0.05)
	Debris:AddItem(inner, time + 0.05)
	local h = holder(CFrame.new(to))
	pointLight(h, color, width * 6, 3, time)
	Debris:AddItem(h, time + 0.05)
end

-- decoração dos objetos do servidor (workspace.FX) ----------------------------------------

local function hide(part)
	part.LocalTransparencyModifier = 1
end

local function attachTo(base, part)
	part.Anchored = false
	part.Massless = true
	part.Parent = base
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = part
	weld.Parent = part
end

local Decorators = {}

function Decorators.orb(part)
	local size = part.Size.X
	trail(part, Vector3.new(size * 0.4, 0, 0), Vector3.new(-size * 0.4, 0, 0), part.Color, 0.2)
	pointLight(part, part.Color, size * 6, 2)
	particles(part, {
		Enabled = true,
		Rate = 25,
		Color = ColorSequence.new(WHITE, part.Color),
		Size = NumberSequence.new(size * 0.4, 0),
		Lifetime = NumberRange.new(0.2, 0.35),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
	})
end

function Decorators.blade(part)
	hide(part)
	local length = math.max(part.Size.Z, part.Size.X * 2.5)
	-- ponta para a frente (-Z), lâmina para trás
	local origin = part.CFrame * CFrame.new(0, 0, -length / 2) * CFrame.Angles(math.rad(90), 0, 0)
	for _, piece in buildGhostSword(origin, length, length * 0.13, part.Color, 0.1, false) do
		attachTo(part, piece)
	end
	trail(part, Vector3.new(0, 0, -length / 2), Vector3.new(0, 0, length * 0.2), part.Color, 0.18)
	pointLight(part, part.Color, 10, 1.5)
end

function Decorators.bullet(part)
	hide(part)
	local cf = part.CFrame
	local tracer = neon(Enum.PartType.Block, Vector3.new(0.25, 0.25, 2.4), cf, part.Color, 0)
	attachTo(part, tracer)
	local core = neon(Enum.PartType.Block, Vector3.new(0.1, 0.1, 2.6), cf, WHITE, 0)
	attachTo(part, core)
	trail(part, Vector3.new(0.12, 0, 0), Vector3.new(-0.12, 0, 0), part.Color, 0.1)
	pointLight(part, part.Color, 6, 1.5)
end

function Decorators.lance(part)
	hide(part)
	local cf = part.CFrame
	attachTo(part, neon(Enum.PartType.Block, Vector3.new(0.35, 0.35, 5.5), cf * CFrame.new(0, 0, 1), part.Color, 0.05))
	attachTo(part, neon(Enum.PartType.Block, Vector3.new(0.6, 0.6, 1.2), cf * CFrame.new(0, 0, -2) * CFrame.Angles(0, 0, math.rad(45)), WHITE, 0))
	trail(part, Vector3.new(0.3, 0, 0), Vector3.new(-0.3, 0, 0), part.Color, 0.25)
	pointLight(part, part.Color, 12, 2)
end

function Decorators.wind(part)
	hide(part)
	local size = math.max(part.Size.X, 2) * 2.5
	local crescent = neon(Enum.PartType.Block, Vector3.new(size, 0.3, size * 0.35), part.CFrame, part.Color, 0.35)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = crescent
	attachTo(part, crescent)
	trail(part, Vector3.new(size / 2, 0, 0), Vector3.new(-size / 2, 0, 0), part.Color, 0.2)
end

function Decorators.fireball(part)
	local size = part.Size.X
	particles(part, {
		Texture = TEX.fire,
		Enabled = true,
		Rate = 60,
		Color = ColorSequence.new(WHITE, part.Color),
		Size = NumberSequence.new(size * 1.2, 0),
		Lifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(20, 20),
		EmissionDirection = Enum.NormalId.Back,
	})
	trail(part, Vector3.new(size * 0.4, 0, 0), Vector3.new(-size * 0.4, 0, 0), part.Color, 0.3)
	pointLight(part, part.Color, size * 6, 3)
end

function Decorators.enemy(part)
	part.Color = Color3.fromRGB(255, 70, 50)
	local size = part.Size.X
	trail(part, Vector3.new(size * 0.4, 0, 0), Vector3.new(-size * 0.4, 0, 0), part.Color, 0.2)
	pointLight(part, part.Color, 10, 2)
end

function Decorators.xp(part)
	pointLight(part, part.Color, 6, 1)
	particles(part, {
		Enabled = true,
		Rate = 6,
		Color = ColorSequence.new(part.Color),
		Size = NumberSequence.new(0.4, 0),
		Lifetime = NumberRange.new(0.4, 0.6),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
	})
	trail(part, Vector3.new(0.3, 0, 0), Vector3.new(-0.3, 0, 0), part.Color, 0.15)
end

function Decorators.summon(part)
	hide(part)
	local cf = part.CFrame
	local color = part.Color
	attachTo(part, neon(Enum.PartType.Block, Vector3.new(1.6, 1.8, 0.9), cf, color, 0.3))
	attachTo(part, neon(Enum.PartType.Ball, Vector3.one * 1.2, cf * CFrame.new(0, 1.5, 0), color, 0.3))
	for _, side in { -1, 1 } do
		attachTo(part, neon(Enum.PartType.Block, Vector3.new(0.45, 1.6, 0.45), cf * CFrame.new(side * 1.1, -0.1, 0), color, 0.4))
		attachTo(part, neon(Enum.PartType.Block, Vector3.new(0.18, 0.18, 0.05), cf * CFrame.new(side * 0.25, 1.6, -0.6), WHITE, 0))
	end
	particles(part, {
		Texture = TEX.smoke,
		Enabled = true,
		Rate = 12,
		LightEmission = 0.4,
		Color = ColorSequence.new(color),
		Size = NumberSequence.new(1.5, 2.5),
		Transparency = NumberSequence.new(0.6, 1),
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(0.5, 1.5),
	})
	pointLight(part, color, 12, 1.5)
end

local function zoneParticles(part, vortex)
	-- o disco é um cilindro deitado: o raio está em Size.Y/Z
	local radius = part.Size.Y / 2
	part.Transparency = 0.82
	local area = Instance.new("Part")
	area.Size = Vector3.new(radius * 1.6, 0.2, radius * 1.6)
	area.CFrame = CFrame.new(part.Position)
	area.Transparency = 1
	area.CanCollide = false
	area.CanQuery = false
	area.CanTouch = false
	attachTo(part, area)
	particles(area, {
		Texture = vortex and TEX.glow or TEX.spark,
		Enabled = true,
		Rate = math.clamp(radius * 4, 10, 80),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top,
		Color = ColorSequence.new(WHITE, part.Color),
		Size = NumberSequence.new(vortex and 1.2 or 0.7, 0),
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(3, 8),
		RotSpeed = NumberRange.new(-200, 200),
		Acceleration = vortex and Vector3.new(0, 10, 0) or Vector3.new(0, 4, 0),
	})
	local decalHolder = Instance.new("Part")
	decalHolder.Size = Vector3.new(radius * 2, 0.05, radius * 2)
	decalHolder.CFrame = CFrame.new(part.Position + Vector3.new(0, 0.1, 0))
	decalHolder.Transparency = 1
	decalHolder.CanCollide = false
	decalHolder.CanQuery = false
	decalHolder.CanTouch = false
	attachTo(part, decalHolder)
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	decal.Texture = vortex and TEX.vortex or TEX.shock
	decal.Color3 = part.Color
	decal.Transparency = 0.25
	decal.Parent = decalHolder
	pointLight(part, part.Color, radius * 2, 1.5)
end

function Decorators.zone(part)
	zoneParticles(part, false)
end

function Decorators.vortex(part)
	zoneParticles(part, true)
end

function Decorators.shield(part)
	part.Material = Enum.Material.ForceField
	part.Transparency = 0
	pointLight(part, part.Color, 14, 1)
end

function Decorators.ice(part)
	part.Material = Enum.Material.Glass
	part.Transparency = 0.35
	part.Reflectance = 0.3
	local h = holder(part.CFrame, part.Size)
	particles(h, {
		Color = ColorSequence.new(WHITE),
		Size = NumberSequence.new(0.5, 0),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(5, 12),
		SpreadAngle = Vector2.new(180, 180),
	}):Emit(15)
	Debris:AddItem(h, 1)
end

local function decorate(part)
	if not part:IsA("BasePart") then
		return
	end
	local kind = part:GetAttribute("Fx")
	local decorator = kind and Decorators[kind]
	if decorator then
		local ok, err = pcall(decorator, part)
		if not ok then
			warn("[VFX] " .. tostring(err))
		end
	end
end

-- entrada --------------------------------------------------------------------------------

local Handlers = {
	burst = function(d)
		VFX.Burst(d.pos, d.radius, d.color, d.time)
	end,
	ring = function(d)
		VFX.Ring(d.pos, d.radius, d.color, d.time)
	end,
	telegraph = function(d)
		VFX.Telegraph(d.pos, d.radius, d.delay, d.color)
	end,
	strike = VFX.Strike,
	beam = VFX.Beam,
	bolt = function(d)
		lightning(d.from, d.to, d.color, 0.35)
	end,
	kill = VFX.Kill,
	spawn = VFX.Spawn,
	levelup = VFX.LevelUp,
	shake = function(d)
		shakeNear(d.pos, d.intensity, d.radius)
	end,
}

function VFX.On(kind, handler)
	Handlers[kind] = handler
end

function VFX.Init()
	Net.Fx.OnClientEvent:Connect(function(kind, data)
		local handler = Handlers[kind]
		if handler then
			local ok, err = pcall(handler, data)
			if not ok then
				warn("[VFX] " .. kind .. ": " .. tostring(err))
			end
		end
	end)

	local serverFx = workspace:WaitForChild("FX")
	serverFx.ChildAdded:Connect(decorate)
	for _, child in serverFx:GetChildren() do
		decorate(child)
	end
end

return VFX
