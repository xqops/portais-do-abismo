--[[
	Animações feitas por código (não precisam de upload de Animation):
	- Golpes de espada dos jogadores: gira ombro, tronco e a junta da arma (WeaponGrip) + rastro do corte.
	- Monstros: balanço ao andar, investida ao atacar, recuo e piscada branca ao levar dano,
	  surgir do chão e cair ao morrer. Funciona com o boneco de blocos e com modelos importados.
	Depois dá para trocar por Animations de verdade (Animation Editor / Moon Animator) mantendo isto como reserva.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Animator = {}

local player = Players.LocalPlayer
local VFX -- injetado no Init

local WHITE = Color3.new(1, 1, 1)

-- golpes do combo: ombro (yaw = esquerda/direita, pitch = levantar), giro do tronco e
-- `blade` = quanto a lâmina gira para ficar alinhada com o braço (0 = apontando para a frente)
local SWINGS = {
	{ from = { yaw = -80, pitch = 95, waist = -30, blade = 1 }, to = { yaw = 70, pitch = 75, waist = 35, blade = 1 }, time = 0.15, arc = { -85, 85 } },
	{ from = { yaw = 60, pitch = 80, waist = 30, blade = 1 }, to = { yaw = -85, pitch = 95, waist = -35, blade = 1 }, time = 0.15, arc = { 85, -85 } },
	{ from = { yaw = -15, pitch = 200, waist = 0, blade = 0.7 }, to = { yaw = -15, pitch = 30, waist = 0, blade = 0.7 }, time = 0.18, arc = { 110, -15 }, vertical = true },
}
local REST = { yaw = 0, pitch = 0, waist = 0, blade = 0 }

local bases = setmetatable({}, { __mode = "k" }) -- C0 original de cada junta
local playing = setmetatable({}, { __mode = "k" }) -- personagem -> token da animação atual

local function base(motor)
	if not bases[motor] then
		bases[motor] = motor.C0
	end
	return bases[motor]
end

local function getRig(character)
	local arm = character:FindFirstChild("RightUpperArm")
	local torso = character:FindFirstChild("UpperTorso")
	local hand = character:FindFirstChild("RightHand")
	local shoulder = arm and arm:FindFirstChild("RightShoulder")
	if not shoulder then
		return nil -- só R15
	end
	return {
		shoulder = shoulder,
		waist = torso and torso:FindFirstChild("Waist"),
		grip = hand and hand:FindFirstChild("WeaponGrip"),
	}
end

local function lerpPose(a, b, t)
	return {
		yaw = a.yaw + (b.yaw - a.yaw) * t,
		pitch = a.pitch + (b.pitch - a.pitch) * t,
		waist = a.waist + (b.waist - a.waist) * t,
		blade = a.blade + (b.blade - a.blade) * t,
	}
end

local function applyPose(rig, pose)
	rig.shoulder.C0 = base(rig.shoulder) * CFrame.Angles(0, math.rad(pose.yaw), 0) * CFrame.Angles(math.rad(pose.pitch), 0, 0)
	if rig.waist then
		rig.waist.C0 = base(rig.waist) * CFrame.Angles(0, math.rad(pose.waist), 0)
	end
	if rig.grip then
		rig.grip.C0 = base(rig.grip) * CFrame.Angles(math.rad(-90 * pose.blade), 0, 0)
	end
end

local function easeOut(t)
	return 1 - (1 - t) ^ 3
end

-- rastro brilhante que acompanha o arco do golpe
local function slashTrail(root, swing, dir, range, color)
	local tracer = Instance.new("Part")
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CanTouch = false
	tracer.Transparency = 1
	tracer.Size = Vector3.one * 0.2
	tracer.Parent = workspace

	local width = 1.3
	local side = dir:Cross(Vector3.yAxis)
	local a0 = Instance.new("Attachment")
	local a1 = Instance.new("Attachment")
	a0.Parent = tracer
	a1.Parent = tracer
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(WHITE, color)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new(1, 0.3)
	trail.Lifetime = 0.16
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.MinLength = 0
	trail.Parent = tracer

	local radius = range * 0.7
	local fromAngle, toAngle = math.rad(swing.arc[1]), math.rad(swing.arc[2])
	local function place(alpha)
		local angle = fromAngle + (toAngle - fromAngle) * easeOut(alpha)
		local center = root.Position + Vector3.new(0, 0.6, 0)
		local point
		if swing.vertical then
			point = center + (dir * math.cos(angle) + Vector3.yAxis * math.sin(angle)) * radius
			a0.Position = side * width
			a1.Position = -side * width
		else
			point = center + (CFrame.fromAxisAngle(Vector3.yAxis, angle) * dir) * radius
			a0.Position = Vector3.new(0, width, 0)
			a1.Position = Vector3.new(0, -width, 0)
		end
		tracer.CFrame = CFrame.new(point)
	end

	place(0)
	trail:Clear()
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local alpha = math.min(1, (os.clock() - start) / swing.time)
		place(alpha)
		if alpha >= 1 then
			connection:Disconnect()
			Debris:AddItem(tracer, trail.Lifetime + 0.05)
		end
	end)
end

function Animator.Swing(data)
	local swinger = data.player
	local character = swinger and swinger.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local swing = SWINGS[data.combo]
	if not root or not swing then
		return
	end
	local dir = Vector3.new(data.dir.X, 0, data.dir.Z)
	if dir.Magnitude < 0.01 then
		return
	end
	dir = dir.Unit

	if swinger == player then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	end
	slashTrail(root, swing, dir, data.range, data.color)
	VFX.PlaySound(data.combo == 3 and VFX.Sounds.lunge or VFX.Sounds.slash, root.Position, 0.45, data.combo == 3 and 0.85 or 1)

	local rig = getRig(character)
	if not rig then
		return
	end
	local token = {}
	playing[character] = token
	local windup, hold, recover = 0.05, 0.05, 0.14
	local total = windup + swing.time + hold + recover
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if playing[character] ~= token or not character.Parent then
			connection:Disconnect()
			return
		end
		local t = os.clock() - start
		local pose
		if t < windup then
			pose = lerpPose(REST, swing.from, t / windup)
		elseif t < windup + swing.time then
			pose = lerpPose(swing.from, swing.to, easeOut((t - windup) / swing.time))
		elseif t < windup + swing.time + hold then
			pose = swing.to
		else
			pose = lerpPose(swing.to, REST, math.min(1, (t - windup - swing.time - hold) / recover))
		end
		applyPose(rig, pose)
		if t >= total then
			applyPose(rig, REST)
			playing[character] = nil
			connection:Disconnect()
		end
	end)
end

-- monstros ----------------------------------------------------------------------------------

local tracked = {}

local function track(model)
	if tracked[model] then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart", 5)
	local joint = root and root:WaitForChild("Visual", 5)
	if not joint then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = WHITE
	highlight.OutlineTransparency = 1
	highlight.FillTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = model
	tracked[model] = {
		root = root,
		joint = joint,
		base = joint.C0,
		height = root.Size.Y,
		scale = math.clamp(root.Size.Y / 3.5, 0.6, 3),
		walk = math.random() * 10,
		spawnT = os.clock(),
		hit = model:GetAttribute("Hit") or 0,
		hitT = 0,
		attack = model:GetAttribute("Attack") or 0,
		attackT = 0,
		deadT = nil,
		highlight = highlight,
	}
end

local function stepEnemies(dt)
	local now = os.clock()
	for model, d in tracked do
		if not model.Parent or not d.joint.Parent then
			tracked[model] = nil
			continue
		end

		local hit = model:GetAttribute("Hit") or 0
		if hit ~= d.hit then
			d.hit = hit
			d.hitT = now
		end
		local attack = model:GetAttribute("Attack") or 0
		if attack ~= d.attack then
			d.attack = attack
			d.attackT = now
		end
		if model:GetAttribute("Dead") and not d.deadT then
			d.deadT = now
		end

		-- piscada branca rápida ao levar dano
		d.highlight.Enabled = now - d.hitT < 0.07 and not d.deadT

		local cf
		if d.deadT then
			local t = math.min(1, (now - d.deadT) / 0.45)
			cf = CFrame.new(0, -t * d.height * 0.4, 0) * CFrame.Angles(math.rad(85) * easeOut(t), 0, 0)
		else
			local velocity = d.root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			local moving = math.min(speed / 8, 1)
			d.walk += dt * (6 + speed * 0.4) / d.scale
			local bob = math.abs(math.sin(d.walk)) * 0.35 * d.scale * moving
			local sway = math.sin(d.walk) * math.rad(9) * moving
			local breathe = math.sin(now * 2 + d.walk) * 0.05 * d.scale

			local lunge, tilt = 0, 0
			local attackT = (now - d.attackT) / 0.35
			if attackT < 1 then
				local curve = math.sin(attackT * math.pi)
				lunge = curve * 1.4 * d.scale
				tilt = curve * math.rad(18)
			end
			local recoil = math.max(0, 1 - (now - d.hitT) / 0.15)
			local rise = easeOut(math.min(1, (now - d.spawnT) / 0.45))

			cf = CFrame.new(0, bob + breathe - (1 - rise) * d.height, -lunge + recoil * 0.4 * d.scale)
				* CFrame.Angles(-tilt + recoil * math.rad(12), 0, sway)
		end
		d.joint.C0 = d.base * cf
	end
end

function Animator.Init(vfx)
	VFX = vfx
	VFX.On("swing", Animator.Swing)
	CollectionService:GetInstanceAddedSignal("Enemy"):Connect(function(model)
		task.spawn(track, model)
	end)
	for _, model in CollectionService:GetTagged("Enemy") do
		task.spawn(track, model)
	end
	RunService.RenderStepped:Connect(stepEnemies)
end

return Animator
