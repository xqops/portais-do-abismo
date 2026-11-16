-- Gera o lobby e as arenas das masmorras com Parts.
-- Se você montar o seu próprio lobby no Studio (um Model chamado "Lobby" no Workspace),
-- o gerado é ignorado: basta marcar as plataformas com a tag "DungeonPad"
-- e o atributo DungeonIndex (1, 2, 3...) e opcionalmente Radius.
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dungeons = require(ReplicatedStorage.Shared.Config.Dungeons)

local WorldBuilder = {}

local VERTICAL = CFrame.Angles(0, 0, math.rad(90))

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	p.Parent = parent
	return p
end

local function light(parent, color, range, brightness)
	local pointLight = Instance.new("PointLight")
	pointLight.Color = color
	pointLight.Range = range or 16
	pointLight.Brightness = brightness or 1.5
	pointLight.Parent = parent
end

local function billboard(adornee, lines, height)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(320, 26 * #lines)
	gui.StudsOffset = Vector3.new(0, height or 4, 0)
	gui.MaxDistance = 150
	gui.Parent = adornee
	for i, line in lines do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, 26)
		label.Position = UDim2.fromOffset(0, (i - 1) * 26)
		label.Font = Enum.Font.GothamBlack
		label.TextSize = line.size or 20
		label.TextColor3 = line.color or Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		label.Text = line.text
		label.Parent = gui
	end
	return gui
end

local function tree(parent, pos, scale, leafColor)
	part(parent, {
		Name = "Trunk",
		Size = Vector3.new(1.6, 8, 1.6) * scale,
		CFrame = CFrame.new(pos + Vector3.new(0, 4 * scale, 0)),
		Color = Color3.fromRGB(100, 70, 45),
		Material = Enum.Material.Wood,
	})
	part(parent, {
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 8 * scale,
		CFrame = CFrame.new(pos + Vector3.new(0, 9.5 * scale, 0)),
		Color = leafColor,
		Material = Enum.Material.Grass,
	})
end

local function lamp(parent, pos)
	part(parent, {
		Name = "LampPost",
		Size = Vector3.new(0.8, 10, 0.8),
		CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)),
		Color = Color3.fromRGB(50, 45, 40),
		Material = Enum.Material.Metal,
	})
	local bulb = part(parent, {
		Name = "Lamp",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.8,
		CFrame = CFrame.new(pos + Vector3.new(0, 10.5, 0)),
		Color = Color3.fromRGB(255, 200, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	light(bulb, Color3.fromRGB(255, 200, 120), 24, 1.5)
end

local function portal(parent, def, index, cframe)
	local theme = def.theme
	local model = Instance.new("Model")
	model.Name = "Portal_" .. def.id
	model.Parent = parent

	part(model, { Name = "Base", Size = Vector3.new(20, 1.5, 8), CFrame = cframe * CFrame.new(0, 0.75, 0), Color = theme.wall, Material = theme.wallMaterial })
	for _, side in { -1, 1 } do
		part(model, { Name = "Pillar", Size = Vector3.new(2.5, 18, 2.5), CFrame = cframe * CFrame.new(side * 7.5, 10, 0), Color = theme.wall, Material = theme.wallMaterial })
	end
	local top = part(model, { Name = "Top", Size = Vector3.new(19, 3, 3), CFrame = cframe * CFrame.new(0, 20, 0), Color = theme.wall, Material = theme.wallMaterial })
	local surface = part(model, {
		Name = "PortalSurface",
		Size = Vector3.new(12.5, 16.5, 0.6),
		CFrame = cframe * CFrame.new(0, 10, 0),
		Color = theme.accent,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
	})
	light(surface, theme.accent, 30, 2)
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(theme.accent)
	particles.LightEmission = 1
	particles.Rate = 20
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Speed = NumberRange.new(1, 3)
	particles.Size = NumberSequence.new(0.4, 0)
	particles.Parent = surface

	billboard(top, {
		{ text = "W" .. index .. " · " .. def.name, size = 22, color = theme.accent },
		{ text = "Chefe: " .. def.boss.name, size = 16 },
	}, 4)

	-- plataforma da fila, na frente do portal
	local pad = part(model, {
		Name = "Pad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 16, 16),
		CFrame = cframe * CFrame.new(0, 0.3, -12) * VERTICAL,
		Color = theme.accent,
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		CanCollide = false,
	})
	pad:SetAttribute("DungeonIndex", index)
	pad:SetAttribute("Radius", 8)
	CollectionService:AddTag(pad, "DungeonPad")
end

function WorldBuilder.SetupLighting()
	Lighting.ClockTime = 16.8
	Lighting.Brightness = 2.2
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 130, 120)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Haze = 1
	atmosphere.Color = Color3.fromRGB(200, 180, 160)
	atmosphere.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 1
	bloom.Parent = Lighting

	local grading = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	grading.Saturation = 0.15
	grading.Contrast = 0.08
	grading.Parent = Lighting
end

function WorldBuilder.BuildLobby()
	if workspace:FindFirstChild("Lobby") then
		return -- lobby feito à mão no Studio
	end
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"

	part(lobby, { Name = "Ground", Size = Vector3.new(400, 4, 400), CFrame = CFrame.new(0, -2, 0), Color = Color3.fromRGB(86, 140, 70), Material = Enum.Material.Grass })
	part(lobby, {
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 100, 100),
		CFrame = CFrame.new(0, 0.2, 0) * VERTICAL,
		Color = Color3.fromRGB(150, 145, 135),
		Material = Enum.Material.Cobblestone,
	})
	part(lobby, {
		Name = "Path",
		Size = Vector3.new(14, 0.4, 70),
		CFrame = CFrame.new(0, 0.21, -60),
		Color = Color3.fromRGB(150, 145, 135),
		Material = Enum.Material.Cobblestone,
	})

	if not workspace:FindFirstChildOfClass("SpawnLocation") then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "LobbySpawn"
		spawn.Size = Vector3.new(10, 1, 10)
		spawn.CFrame = CFrame.new(0, 0.5, 20)
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Color = Color3.fromRGB(235, 190, 90)
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Parent = lobby
	end

	-- cristal central
	local crystal = part(lobby, {
		Name = "Crystal",
		Size = Vector3.new(4, 12, 4),
		CFrame = CFrame.new(0, 9, -8) * CFrame.Angles(0, math.rad(45), 0),
		Color = Color3.fromRGB(140, 200, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CanCollide = false,
	})
	part(lobby, { Name = "CrystalBase", Size = Vector3.new(8, 3, 8), CFrame = CFrame.new(0, 1.5, -8), Color = Color3.fromRGB(90, 85, 80), Material = Enum.Material.Slate })
	light(crystal, Color3.fromRGB(140, 200, 255), 40, 2)
	billboard(crystal, {
		{ text = "PORTAIS DO ABISMO", size = 28, color = Color3.fromRGB(235, 190, 90) },
		{ text = "Pise na plataforma de um portal para entrar", size = 16 },
	}, 9)

	-- portais em arco no lado norte
	local count = #Dungeons
	for i, def in Dungeons do
		local angle = count > 1 and math.rad(-60 + (i - 1) * 120 / (count - 1)) or 0
		local pos = Vector3.new(math.sin(angle) * 75, 0, -math.cos(angle) * 75)
		portal(lobby, def, i, CFrame.lookAt(pos, Vector3.new(0, 0, 0)))
	end

	-- decoração
	local rng = Random.new(42)
	for _ = 1, 45 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(100, 185)
		local pos = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		tree(lobby, pos, rng:NextNumber(0.9, 1.6), Color3.fromRGB(60 + rng:NextInteger(0, 30), 120 + rng:NextInteger(0, 40), 50))
	end
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2
		lamp(lobby, Vector3.new(math.cos(angle) * 52, 0, math.sin(angle) * 52))
	end

	-- paredes invisíveis
	for _, wall in {
		{ Vector3.new(400, 60, 2), Vector3.new(0, 30, 200) },
		{ Vector3.new(400, 60, 2), Vector3.new(0, 30, -200) },
		{ Vector3.new(2, 60, 400), Vector3.new(200, 30, 0) },
		{ Vector3.new(2, 60, 400), Vector3.new(-200, 30, 0) },
	} do
		part(lobby, { Name = "Boundary", Size = wall[1], CFrame = CFrame.new(wall[2]), Transparency = 1 })
	end

	lobby.Parent = workspace
end

-- Arena de uma run. Retorna dados usados pelo DungeonService.
function WorldBuilder.BuildArena(def, origin)
	local theme = def.theme
	local model = Instance.new("Model")
	model.Name = "Arena_" .. def.id

	local size, height = 220, 24
	part(model, { Name = "Floor", Size = Vector3.new(size, 4, size), CFrame = CFrame.new(origin - Vector3.new(0, 2, 0)), Color = theme.floor, Material = theme.floorMaterial })
	for _, wall in {
		{ Vector3.new(size, height, 4), Vector3.new(0, height / 2, size / 2) },
		{ Vector3.new(size, height, 4), Vector3.new(0, height / 2, -size / 2) },
		{ Vector3.new(4, height, size), Vector3.new(size / 2, height / 2, 0) },
		{ Vector3.new(4, height, size), Vector3.new(-size / 2, height / 2, 0) },
	} do
		part(model, { Name = "Wall", Size = wall[1], CFrame = CFrame.new(origin + wall[2]), Color = theme.wall, Material = theme.wallMaterial })
	end
	-- teto invisível para ninguém pular para fora
	part(model, { Name = "Ceiling", Size = Vector3.new(size, 2, size), CFrame = CFrame.new(origin + Vector3.new(0, 60, 0)), Transparency = 1 })

	-- colunas com tochas (deixa o centro livre para o chefe)
	local rng = Random.new()
	for _ = 1, 10 do
		local x, z = rng:NextNumber(-75, 75), rng:NextNumber(-75, 75)
		if math.abs(x) > 25 or math.abs(z) > 25 then
			local width, h = rng:NextNumber(4, 8), rng:NextNumber(6, 16)
			part(model, { Name = "Pillar", Size = Vector3.new(width, h, width), CFrame = CFrame.new(origin + Vector3.new(x, h / 2, z)), Color = theme.wall, Material = theme.wallMaterial })
			local torch = part(model, {
				Name = "Torch",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 1.6,
				CFrame = CFrame.new(origin + Vector3.new(x, h + 0.8, z)),
				Color = theme.accent,
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			light(torch, theme.accent, 30, 2)
		end
	end

	local spawnPoints = {}
	for i = 1, 16 do
		local angle = i / 16 * math.pi * 2
		table.insert(spawnPoints, origin + Vector3.new(math.cos(angle) * 92, 0, math.sin(angle) * 92))
	end

	model.Parent = workspace
	return {
		model = model,
		floorY = origin.Y,
		center = origin,
		playerSpawn = origin + Vector3.new(0, 0, 40),
		spawnPoints = spawnPoints,
	}
end

return WorldBuilder
