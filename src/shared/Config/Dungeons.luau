--[[
	Masmorras (mundos). A ordem da lista é a ordem de desbloqueio:
	para entrar na masmorra N é preciso ter vencido o chefe da N-1.

	Habilidades de chefe disponíveis (EnemyService): "slam", "volley", "ring", "summon", "charge"

	`model` (opcional) = nome do modelo 3D em ReplicatedStorage.Assets.Monsters.
	Sem ele, o jogo procura pelo `name`; se não achar nenhum, usa o boneco de blocos.
]]
return {
	{
		id = "floresta",
		name = "Floresta Assombrada",
		waves = 5,
		hpMult = 1,
		dmgMult = 1,
		theme = {
			floor = Color3.fromRGB(76, 140, 60),
			floorMaterial = Enum.Material.Grass,
			wall = Color3.fromRGB(95, 70, 45),
			wallMaterial = Enum.Material.Wood,
			accent = Color3.fromRGB(120, 255, 140),
		},
		mobs = {
			chaser = { name = "Esqueleto", model = "Skeleton_Minion", color = Color3.fromRGB(200, 200, 180) },
			runner = { name = "Esqueleto Ladino", model = "Skeleton_Rogue", color = Color3.fromRGB(150, 140, 120) },
			archer = { name = "Esqueleto Mago", model = "Skeleton_Mage", color = Color3.fromRGB(120, 140, 200) },
			brute = { name = "Esqueleto Guerreiro", model = "Skeleton_Warrior", color = Color3.fromRGB(170, 160, 140) },
		},
		boss = {
			name = "Rei Esqueleto",
			model = "Skeleton_Warrior",
			hp = 4000,
			color = Color3.fromRGB(160, 200, 60),
			size = Vector3.new(7, 10, 6),
			skills = { "slam", "volley", "summon" },
		},
		reward = { gold = 100, xp = 120 },
	},
	{
		id = "deserto",
		name = "Deserto de Cinzas",
		waves = 6,
		hpMult = 1.8,
		dmgMult = 1.4,
		theme = {
			floor = Color3.fromRGB(205, 175, 115),
			floorMaterial = Enum.Material.Sand,
			wall = Color3.fromRGB(170, 130, 80),
			wallMaterial = Enum.Material.Sandstone,
			accent = Color3.fromRGB(255, 190, 70),
		},
		mobs = {
			chaser = { name = "Escaravelho", color = Color3.fromRGB(60, 80, 90) },
			runner = { name = "Chacal", color = Color3.fromRGB(180, 140, 90) },
			archer = { name = "Múmia Arqueira", color = Color3.fromRGB(220, 210, 180) },
			brute = { name = "Golem de Areia", color = Color3.fromRGB(190, 160, 100) },
		},
		boss = {
			name = "Faraó Esquecido",
			hp = 8000,
			color = Color3.fromRGB(230, 190, 60),
			size = Vector3.new(7, 11, 6),
			skills = { "slam", "ring", "summon" },
		},
		reward = { gold = 200, xp = 250 },
	},
	{
		id = "tundra",
		name = "Tundra Congelada",
		waves = 7,
		hpMult = 3,
		dmgMult = 2,
		theme = {
			floor = Color3.fromRGB(225, 238, 248),
			floorMaterial = Enum.Material.Snow,
			wall = Color3.fromRGB(150, 190, 220),
			wallMaterial = Enum.Material.Glacier,
			accent = Color3.fromRGB(120, 220, 255),
		},
		mobs = {
			chaser = { name = "Diabrete de Gelo", color = Color3.fromRGB(150, 200, 240) },
			runner = { name = "Lobo Polar", color = Color3.fromRGB(235, 240, 245) },
			archer = { name = "Mago do Gelo", color = Color3.fromRGB(80, 120, 200) },
			brute = { name = "Yeti", color = Color3.fromRGB(240, 245, 250) },
		},
		boss = {
			name = "Wyrm Glacial",
			hp = 15000,
			color = Color3.fromRGB(110, 190, 255),
			size = Vector3.new(9, 9, 12),
			skills = { "ring", "volley", "slam", "charge" },
		},
		reward = { gold = 350, xp = 450 },
	},
	{
		id = "cidadela",
		name = "Cidadela Carmesim",
		waves = 8,
		hpMult = 5,
		dmgMult = 3,
		theme = {
			floor = Color3.fromRGB(60, 25, 30),
			floorMaterial = Enum.Material.Basalt,
			wall = Color3.fromRGB(90, 30, 35),
			wallMaterial = Enum.Material.Slate,
			accent = Color3.fromRGB(255, 50, 60),
		},
		mobs = {
			chaser = { name = "Diabrete", color = Color3.fromRGB(170, 40, 40) },
			runner = { name = "Cão Infernal", color = Color3.fromRGB(60, 20, 20) },
			archer = { name = "Bruxo Sombrio", color = Color3.fromRGB(80, 30, 110) },
			brute = { name = "Cavaleiro Demônio", color = Color3.fromRGB(40, 35, 40) },
		},
		boss = {
			name = "Senhor do Abismo",
			hp = 28000,
			color = Color3.fromRGB(150, 20, 30),
			size = Vector3.new(8, 13, 7),
			skills = { "slam", "volley", "ring", "summon", "charge" },
		},
		reward = { gold = 600, xp = 800 },
	},
}
