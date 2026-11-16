-- Coloca a arma na mão direita de todo personagem que nasce.
-- A arma fica presa por um Motor6D "WeaponGrip" na RightHand: o cliente gira essa junta
-- durante os golpes (client/Controllers/Animator.luau).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.Game)

local WeaponService = {}

local BLADE = Color3.fromRGB(205, 212, 225)
local GOLD = Color3.fromRGB(230, 180, 70)
local LEATHER = Color3.fromRGB(70, 40, 30)
local GLOW = Color3.fromRGB(140, 210, 255)

local function weaponPart(model, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.Parent = model
	return part
end

-- Espada feita de Parts. Origem = centro do cabo; a lâmina sobe no eixo +Y.
local function buildDefaultSword()
	local model = Instance.new("Model")
	model.Name = "Weapon"
	local length = GameConfig.Weapon.Length
	local origin = CFrame.new()

	local handle = weaponPart(model, "Handle", Vector3.new(0.28, 1.1, 0.28), origin, LEATHER, Enum.Material.Fabric)
	weaponPart(model, "Pommel", Vector3.new(0.42, 0.42, 0.42), origin * CFrame.new(0, -0.65, 0), GOLD, Enum.Material.Metal).Shape = Enum.PartType.Ball
	weaponPart(model, "Guard", Vector3.new(1.5, 0.22, 0.32), origin * CFrame.new(0, 0.62, 0), GOLD, Enum.Material.Metal)
	local bladeLength = length - 1.4
	local blade = weaponPart(model, "Blade", Vector3.new(0.5, bladeLength, 0.1), origin * CFrame.new(0, 0.73 + bladeLength / 2, 0), BLADE, Enum.Material.Metal)
	blade.Reflectance = 0.25
	weaponPart(model, "Fuller", Vector3.new(0.12, bladeLength * 0.85, 0.12), blade.CFrame * CFrame.new(0, -bladeLength * 0.05, 0), GLOW, Enum.Material.Neon)
	weaponPart(model, "Tip", Vector3.new(0.354, 0.354, 0.1), origin * CFrame.new(0, 0.73 + bladeLength, 0) * CFrame.Angles(0, 0, math.rad(45)), BLADE, Enum.Material.Metal)

	model.PrimaryPart = handle
	return model
end

-- Modelo importado: escala para o comprimento configurado; o pivô do modelo vira o ponto da empunhadura.
local function buildImportedSword(asset)
	local model = asset:Clone()
	model.Name = "Weapon"
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		elseif descendant:IsA("BaseScript") then
			descendant:Destroy()
		end
	end
	local _, size = model:GetBoundingBox()
	local longest = math.max(size.X, size.Y, size.Z)
	if longest > 0.01 then
		model:ScaleTo(model:GetScale() * GameConfig.Weapon.Length / longest)
	end
	local handle = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not handle then
		model:Destroy()
		return nil
	end
	-- o "Handle" fica no pivô do modelo para a junta usar esse ponto
	local pivot = model:GetPivot()
	local gripPart = weaponPart(model, "Handle", Vector3.new(0.2, 0.2, 0.2), pivot, BLADE, Enum.Material.SmoothPlastic)
	gripPart.Transparency = 1
	model.PrimaryPart = gripPart
	return model
end

local function weld(a, b)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = a
	constraint.Part1 = b
	constraint.Parent = a
end

local function equip(character)
	local hand = character:WaitForChild("RightHand", 10)
	if not hand or character:FindFirstChild("Weapon") then
		return
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local weapons = assets and assets:FindFirstChild("Weapons")
	local asset = weapons and weapons:FindFirstChild(GameConfig.Weapon.Model)
	local model = asset and buildImportedSword(asset) or buildDefaultSword()
	local handle = model.PrimaryPart

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= handle then
			weld(handle, descendant)
		end
	end

	-- lâmina apontando para a frente com o braço solto
	local grip = Instance.new("Motor6D")
	grip.Name = "WeaponGrip"
	grip.Part0 = hand
	grip.Part1 = handle
	grip.C0 = CFrame.new(0, -0.2, 0) * CFrame.Angles(math.rad(-90), 0, 0) * GameConfig.Weapon.GripOffset
	grip.Parent = hand

	model.Parent = character
end

function WeaponService.Init()
	local function onPlayer(player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(equip, character)
		end)
		if player.Character then
			task.spawn(equip, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return WeaponService
