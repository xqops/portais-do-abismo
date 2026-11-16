-- Curvas de XP e cartas de atributo
local Progression = {}

-- XP para ir do nível `level` ao próximo DENTRO de uma run (reseta a cada masmorra)
function Progression.RunXpToNext(level)
	return math.floor(5 + level * 5 + level ^ 1.5)
end

-- XP de conta (persistente) para o próximo nível
function Progression.AccountXpToNext(level)
	return math.floor(100 * level ^ 1.35)
end

-- Cartas que aparecem misturadas com os poderes no level up
Progression.StatCards = {
	{ id = "vitality", name = "Vitalidade", desc = "+25 de vida máxima.", color = Color3.fromRGB(90, 220, 110) },
	{ id = "power", name = "Fúria", desc = "+12% de dano em tudo.", color = Color3.fromRGB(255, 110, 80) },
	{ id = "haste", name = "Foco", desc = "-10% de recarga das habilidades.", color = Color3.fromRGB(120, 170, 255) },
	{ id = "swift", name = "Agilidade", desc = "+2 de velocidade de movimento.", color = Color3.fromRGB(240, 240, 140) },
	{ id = "magnet", name = "Ímã", desc = "Coleta orbes de XP de mais longe.", color = Color3.fromRGB(90, 230, 255) },
}

Progression.StatCardsById = {}
for _, card in Progression.StatCards do
	Progression.StatCardsById[card.id] = card
end

return Progression
