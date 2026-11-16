-- Configurações gerais do jogo
return {
	GameName = "Portais do Abismo", -- nome provisório, troque à vontade
	MaxPartySize = 4,
	QueueCountdown = 10, -- segundos no portal antes de entrar
	MaxPowerSlots = 4, -- quantos poderes diferentes cabem numa run
	MaxAliveEnemies = 60,
	SpawnGroupSize = 6, -- inimigos por leva dentro de uma onda
	SpawnGroupInterval = 1, -- segundos entre levas
	ArenaSpacing = 1000, -- distância entre arenas de runs simultâneas
	ReturnToLobbyDelay = 8,

	BasicAttack = {
		damage = 20,
		range = 11,
		cooldown = 0.3, -- intervalo mínimo entre golpes
		comboReset = 0.9, -- sem atacar por esse tempo, o combo volta ao 1º golpe
		color = Color3.fromRGB(255, 235, 190),
		-- cada golpe do combo: multiplicador de dano/alcance, abertura do cone (dot), empurrão, atraso do acerto
		combo = {
			{ damage = 1, range = 1, arc = 0.35, knockback = 15, hitDelay = 0.08 },
			{ damage = 1.1, range = 1, arc = 0.35, knockback = 15, hitDelay = 0.08 },
			{ damage = 1.9, range = 1.25, arc = -0.2, knockback = 45, hitDelay = 0.14, slam = true },
		},
	},

	-- Arma do jogador. Se existir ReplicatedStorage.Assets.Weapons[Model], ela é usada;
	-- senão o jogo monta uma espada com Parts.
	-- GripOffset ajusta a posição/rotação do modelo importado na mão (mexa aqui se ficar torta).
	Weapon = {
		Model = "Sword",
		Length = 4.5, -- o modelo importado é escalado para ter esse comprimento
		GripOffset = CFrame.Angles(0, 0, 0),
	},
}
