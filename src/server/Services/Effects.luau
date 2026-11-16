-- Efeitos visuais.
-- Efeitos instantâneos (explosões, raios, golpes...) são só um aviso para os clientes:
-- quem desenha de verdade é o client/Controllers/VFX.luau (partículas, luz, tremor de câmera).
-- Objetos que duram (projéteis, lâminas orbitando, zonas, orbes) são Parts criadas aqui
-- com o atributo "Fx"; o cliente as "decora" com rastro, brilho e partículas.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Effects = {}

local fxFolder = Instance.new("Folder")
fxFolder.Name = "FX"
fxFolder.Parent = workspace

-- deita o cilindro (o eixo do cilindro é X; isso o coloca em Y, como um disco no chão)
Effects.VERTICAL = CFrame.Angles(0, 0, math.rad(90))

local function send(kind, data)
	Net.Fx:FireAllClients(kind, data)
end
Effects.Send = send

-- Part persistente. `fx` diz ao cliente como decorá-la (ver VFX.luau).
function Effects.Part(shape, size, cframe, color, transparency, fx)
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
	if fx then
		part:SetAttribute("Fx", fx)
	end
	part.Parent = fxFolder
	return part
end

function Effects.Tween(instance, time, props, style)
	local tween = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

-- explosão
function Effects.Burst(pos, radius, color, time)
	send("burst", { pos = pos, radius = radius, color = color, time = time or 0.35 })
end

-- onda de choque no chão
function Effects.Ring(groundPos, radius, color, time)
	send("ring", { pos = groundPos, radius = radius, color = color, time = time or 0.45 })
end

-- aviso no chão: o círculo enche até o golpe cair
function Effects.Telegraph(groundPos, radius, delay, color)
	send("telegraph", { pos = groundPos, radius = radius, delay = delay, color = color })
end

-- golpe que cai do céu (aviso + objeto caindo + explosão), tudo sincronizado com `delay`
-- visual: "pillar" (padrão), "sword", "meteor", "lightning", "orbital"
function Effects.Strike(groundPos, radius, delay, color, visual)
	send("strike", { pos = groundPos, radius = radius, delay = delay, color = color, visual = visual or "pillar" })
end

function Effects.Beam(from, to, width, color, time)
	if (to - from).Magnitude < 0.1 then
		return
	end
	send("beam", { from = from, to = to, width = width, color = color, time = time or 0.25 })
end

function Effects.Bolt(from, to, color)
	send("bolt", { from = from, to = to, color = color })
end

-- golpe de arma do jogador (o cliente anima o braço e desenha o rastro)
function Effects.Swing(player, combo, origin, direction, range, color)
	send("swing", { player = player, combo = combo, pos = origin, dir = direction, range = range, color = color })
end

function Effects.Kill(pos, size, color, killer, isBoss)
	send("kill", { pos = pos, size = size, color = color, killer = killer, boss = isBoss })
end

function Effects.LevelUp(player)
	send("levelup", { player = player })
end

-- tremor de câmera para quem estiver perto de `pos`
function Effects.Shake(pos, intensity, radius)
	send("shake", { pos = pos, intensity = intensity, radius = radius or 60 })
end

-- prende uma part de efeito no personagem (ela acompanha o movimento)
function Effects.Attach(part, root, offset)
	part.CFrame = root.CFrame * (offset or CFrame.identity)
	part.Anchored = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	return part
end

function Effects.Glow(model, color, duration)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = 0.6
	highlight.Parent = model
	Debris:AddItem(highlight, duration)
end

return Effects
