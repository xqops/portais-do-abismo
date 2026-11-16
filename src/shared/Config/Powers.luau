--[[
	Poderes. Cada poder tem 4 níveis (tiers):
	  1, 2, 3  -> habilidades que disparam SOZINHAS quando a recarga acaba (estilo 20 Minutes Till Dawn)
	  4        -> ULTIMATE, ativada pelo jogador com a tecla do slot (1-4)

	Cada pegar do mesmo poder no level up libera o próximo tier. Os tiers anteriores continuam ativos.

	`kind` define o comportamento (implementado em PowerService):
	  projectile  damage, count, spread, speed, range, size, pierce, homing, burst, burstGap, jitter, explode, slow, slowTime
	  nova        damage, radius, knockback, pull, slow, slowTime, freeze, lifesteal, atTarget
	  strike      damage, radius, count, delay, interval, area   (cai do céu com aviso no chão)
	  zone        dps, radius, duration, follow, pull, slow
	  orbit       damage, count, radius, duration, spin
	  line        damage, length, width
	  beam        dps, length, width, duration
	  chain       damage, jumps, range
	  summon      damage, count, duration, speed, explode, explodeRadius
	  shield      absorb, duration, reflect, knockback, radius
	  heal        amount, regen, duration, invuln
	  buff        damageMult, duration, auraDps, radius
	`cd` = recarga em segundos.
]]

local Powers = {}

Powers.List = {
	{
		id = "soul_swords",
		name = "Espadas Almas",
		color = Color3.fromRGB(80, 160, 255),
		tiers = {
			{ name = "Corte Fantasma", desc = "3 cortes espectrais em sequência.", kind = "projectile", visual = "blade", cd = 4, damage = 22, burst = 3, burstGap = 0.12, speed = 110, range = 60, size = 1.4, pierce = 1 },
			{ name = "Dança das Lâminas", desc = "7 espadas orbitam ao seu redor.", kind = "orbit", cd = 15, damage = 15, count = 7, radius = 9, duration = 8 },
			{ name = "Execução Celestial", desc = "Uma lâmina gigante cai sobre o alvo.", kind = "strike", visual = "sword", cd = 18, damage = 95, radius = 10, delay = 0.6 },
			{ name = "Trono das Mil Espadas", desc = "Chuva de espadas por toda a área.", kind = "strike", visual = "sword", cd = 50, damage = 60, radius = 9, count = 24, interval = 0.08, delay = 0.5, area = 60 },
		},
	},
	{
		id = "void",
		name = "Teleporte",
		color = Color3.fromRGB(170, 90, 255),
		tiers = {
			{ name = "Passo do Vazio", desc = "Abre uma fenda do vazio sob o inimigo.", kind = "strike", visual = "void", cd = 5, damage = 30, radius = 6, delay = 0.25 },
			{ name = "Troca Dimensional", desc = "Corte dimensional em linha reta.", kind = "line", cd = 10, damage = 45, length = 40, width = 3 },
			{ name = "Ruptura Espacial", desc = "Portal que suga e fere inimigos.", kind = "zone", cd = 17, dps = 40, radius = 10, duration = 4, pull = 18 },
			{ name = "Colapso das Dimensões", desc = "Rasga a realidade e engole tudo por perto.", kind = "zone", cd = 55, dps = 120, radius = 22, duration = 8, pull = 30 },
		},
	},
	{
		id = "demon_blast",
		name = "Explosão Demoníaca",
		color = Color3.fromRGB(255, 60, 50),
		tiers = {
			{ name = "Bastião Infernal", desc = "Explosão ao seu redor que empurra inimigos.", kind = "nova", cd = 6, damage = 40, radius = 12, knockback = 40 },
			{ name = "Onda de Choque", desc = "Onda em linha que atravessa tudo.", kind = "projectile", visual = "wind", cd = 14, damage = 70, size = 4, speed = 70, pierce = 99, range = 70 },
			{ name = "Detonação Total", desc = "Múltiplas explosões em sequência.", kind = "strike", visual = "meteor", cd = 18, damage = 120, radius = 8, count = 5, interval = 0.15, delay = 0.5, area = 40 },
			{ name = "Apocalipse", desc = "Um meteoro gigantesco devasta a arena.", kind = "strike", visual = "meteor", cd = 60, damage = 600, radius = 35, delay = 1.2 },
		},
	},
	{
		id = "demon_summon",
		name = "Invocação de Demônios",
		color = Color3.fromRGB(200, 20, 60),
		tiers = {
			{ name = "Laços do Inferno", desc = "3 projéteis de sangue teleguiados.", kind = "projectile", cd = 5, damage = 35, count = 3, spread = 40, speed = 60, homing = true },
			{ name = "Demônio Guardião", desc = "Invoca um demônio que luta por você.", kind = "summon", cd = 14, damage = 30, count = 1, duration = 14 },
			{ name = "Círculo Demoníaco", desc = "Círculo de sangue que fere quem pisar.", kind = "zone", cd = 18, dps = 80, radius = 12, duration = 4 },
			{ name = "Portal Abissal", desc = "Abre um portal e invoca 6 demônios.", kind = "summon", cd = 55, damage = 40, count = 6, duration = 15 },
		},
	},
	{
		id = "energy_shield",
		name = "Escudo de Energia",
		color = Color3.fromRGB(90, 200, 255),
		tiers = {
			{ name = "Barreira Energética", desc = "Escudo que absorve 40 de dano.", kind = "shield", cd = 6, absorb = 40, duration = 3 },
			{ name = "Reflexo", desc = "Escudo que devolve o dano recebido.", kind = "shield", cd = 12, absorb = 60, duration = 4, reflect = 1 },
			{ name = "Campo Protetor", desc = "Escudo forte que repele inimigos.", kind = "shield", cd = 18, absorb = 150, duration = 6, knockback = 50, radius = 12 },
			{ name = "Fortaleza Absoluta", desc = "Domo quase impenetrável por 10s.", kind = "shield", cd = 60, absorb = 1000, duration = 10, reflect = 2, knockback = 80, radius = 20 },
		},
	},
	{
		id = "meteor",
		name = "Meteoro",
		color = Color3.fromRGB(255, 130, 40),
		tiers = {
			{ name = "Chuva de Meteoros", desc = "3 pequenos meteoros caem perto.", kind = "strike", visual = "meteor", cd = 6, damage = 40, radius = 6, count = 3, interval = 0.25, area = 40 },
			{ name = "Meteoro Guiado", desc = "Meteoro teleguiado que explode.", kind = "projectile", visual = "fireball", cd = 14, damage = 70, size = 2.5, speed = 55, homing = true, explode = 8 },
			{ name = "Impacto Celeste", desc = "Um grande meteoro com área enorme.", kind = "strike", visual = "meteor", cd = 20, damage = 150, radius = 14, delay = 0.9 },
			{ name = "Tempestade Astral", desc = "Dezenas de meteoros caem na arena.", kind = "strike", visual = "meteor", cd = 60, damage = 90, radius = 9, count = 30, interval = 0.12, area = 60 },
		},
	},
	{
		id = "fire_body",
		name = "Corpo de Fogo",
		color = Color3.fromRGB(255, 90, 20),
		tiers = {
			{ name = "Aura Flamejante", desc = "Queima inimigos perto de você.", kind = "zone", cd = 6, dps = 20, radius = 9, duration = 6, follow = true },
			{ name = "Impulso Ígneo", desc = "Rajada de fogo em linha.", kind = "line", cd = 14, damage = 60, length = 35, width = 4 },
			{ name = "Explosão Corporal", desc = "Seu corpo explode em chamas.", kind = "nova", cd = 18, damage = 120, radius = 16, knockback = 60 },
			{ name = "Fênix Viva", desc = "Vira fogo puro: +50% dano e aura gigante.", kind = "buff", cd = 60, damageMult = 1.5, duration = 12, auraDps = 120, radius = 16 },
		},
	},
	{
		id = "plasma",
		name = "Raio de Plasma",
		color = Color3.fromRGB(190, 80, 255),
		tiers = {
			{ name = "Disparo de Plasma", desc = "Tiros rápidos de plasma.", kind = "projectile", visual = "bullet", cd = 5, damage = 30, speed = 140, burst = 2 },
			{ name = "Corrente Elétrica", desc = "Salta entre 5 inimigos.", kind = "chain", cd = 14, damage = 45, jumps = 5, range = 22 },
			{ name = "Feixe Contínuo", desc = "Feixe de plasma por 3 segundos.", kind = "beam", cd = 20, dps = 100, length = 50, width = 2.5, duration = 3 },
			{ name = "Aniquilação", desc = "Canhão orbital no alvo.", kind = "strike", visual = "orbital", cd = 55, damage = 800, radius = 18, delay = 1.5 },
		},
	},
	{
		id = "ice",
		name = "Congelamento",
		color = Color3.fromRGB(140, 220, 255),
		tiers = {
			{ name = "Estaca de Gelo", desc = "Projétil que atravessa e deixa lento.", kind = "projectile", visual = "lance", cd = 6, damage = 35, pierce = 2, slow = 0.5, slowTime = 2 },
			{ name = "Onda Fria", desc = "Onda de frio que deixa lento.", kind = "nova", cd = 16, damage = 60, radius = 15, slow = 0.4, slowTime = 3 },
			{ name = "Prisão Glacial", desc = "Congela inimigos por 3s.", kind = "nova", cd = 20, damage = 40, radius = 14, freeze = 3 },
			{ name = "Era do Gelo", desc = "Congela a arena inteira.", kind = "nova", cd = 60, damage = 250, radius = 45, freeze = 5 },
		},
	},
	{
		id = "gravity",
		name = "Gravidade",
		color = Color3.fromRGB(120, 60, 220),
		tiers = {
			{ name = "Puxão", desc = "Puxa inimigos para um ponto.", kind = "nova", cd = 6, damage = 10, radius = 20, pull = 50, atTarget = true },
			{ name = "Campo Gravitacional", desc = "Área de gravidade alta: inimigos lentos.", kind = "zone", cd = 15, dps = 15, radius = 14, duration = 6, slow = 0.4 },
			{ name = "Esmagamento", desc = "Esmaga o alvo contra o chão.", kind = "strike", visual = "void", cd = 18, damage = 100, radius = 10, delay = 0.4 },
			{ name = "Colapso Gravitacional", desc = "Cria um buraco negro.", kind = "zone", cd = 60, dps = 160, radius = 25, duration = 8, pull = 35 },
		},
	},
	{
		id = "bullets",
		name = "Rajada de Balas",
		color = Color3.fromRGB(255, 70, 70),
		tiers = {
			{ name = "Disparo Rápido", desc = "Rajada de 5 tiros.", kind = "projectile", visual = "bullet", cd = 6, damage = 12, burst = 5, burstGap = 0.08, speed = 150, size = 0.6 },
			{ name = "Balas Buscadoras", desc = "4 balas teleguiadas.", kind = "projectile", visual = "bullet", cd = 14, damage = 30, count = 4, spread = 60, speed = 80, homing = true },
			{ name = "Metralhadora", desc = "20 tiros seguidos.", kind = "projectile", visual = "bullet", cd = 18, damage = 10, burst = 20, burstGap = 0.08, speed = 160, size = 0.6, jitter = 12 },
			{ name = "Chuva de Projéteis", desc = "Projéteis em todas as direções.", kind = "projectile", visual = "bullet", cd = 50, damage = 40, count = 36, spread = 360, burst = 5, burstGap = 0.25, pierce = 3 },
		},
	},
	{
		id = "energy_lance",
		name = "Lança de Energia",
		color = Color3.fromRGB(60, 220, 255),
		tiers = {
			{ name = "Arremesso", desc = "Lança que atravessa 5 inimigos.", kind = "projectile", visual = "lance", cd = 6, damage = 50, pierce = 5, speed = 120, size = 1, range = 80 },
			{ name = "Investida", desc = "Golpe perfurante em linha.", kind = "line", cd = 14, damage = 80, length = 40, width = 3 },
			{ name = "Multiplicação", desc = "5 lanças em leque.", kind = "projectile", visual = "lance", cd = 20, damage = 60, count = 5, spread = 50, pierce = 3 },
			{ name = "Lança Dimensional", desc = "Uma lança colossal atravessa a arena.", kind = "line", cd = 50, damage = 500, length = 120, width = 8 },
		},
	},
	{
		id = "shadow_clones",
		name = "Clones Sombrios",
		color = Color3.fromRGB(110, 60, 170),
		tiers = {
			{ name = "Clone de Ataque", desc = "Um clone aliado ataca inimigos.", kind = "summon", cd = 8, damage = 25, count = 1, duration = 8 },
			{ name = "Clones Múltiplos", desc = "3 clones aliados.", kind = "summon", cd = 15, damage = 20, count = 3, duration = 8 },
			{ name = "Explosão Sombria", desc = "Clones que explodem ao sumir.", kind = "summon", cd = 18, damage = 20, count = 3, duration = 5, explode = 100, explodeRadius = 10 },
			{ name = "Exército de Sombras", desc = "Invoca 10 clones.", kind = "summon", cd = 55, damage = 30, count = 10, duration = 12 },
		},
	},
	{
		id = "wind",
		name = "Vento Cortante",
		color = Color3.fromRGB(220, 235, 255),
		tiers = {
			{ name = "Corte de Vento", desc = "Lâmina de vento que atravessa tudo.", kind = "projectile", visual = "wind", cd = 6, damage = 35, pierce = 99, size = 2, speed = 100 },
			{ name = "Redemoinho", desc = "Redemoinho que puxa inimigos.", kind = "zone", cd = 14, dps = 30, radius = 10, duration = 3, pull = 15 },
			{ name = "Lâminas Aéreas", desc = "8 lâminas em todas as direções.", kind = "projectile", visual = "wind", cd = 18, damage = 50, count = 8, spread = 360, pierce = 3 },
			{ name = "Fúria dos Ventos", desc = "Tempestade enorme ao seu redor.", kind = "zone", cd = 55, dps = 150, radius = 25, duration = 10, follow = true },
		},
	},
	{
		id = "regen",
		name = "Regeneração",
		color = Color3.fromRGB(80, 255, 120),
		tiers = {
			{ name = "Cura Rápida", desc = "Cura 30 de vida.", kind = "heal", cd = 6, amount = 30 },
			{ name = "Transferência", desc = "Rouba vida dos inimigos próximos.", kind = "nova", cd = 14, damage = 40, radius = 12, lifesteal = 0.5 },
			{ name = "Renovação", desc = "Regenera 5 de vida por segundo por 10s.", kind = "heal", cd = 18, regen = 5, duration = 10 },
			{ name = "Imortalidade", desc = "Cura total e invencível por 8s.", kind = "heal", cd = 70, amount = 9999, invuln = true, duration = 8 },
		},
	},
	{
		id = "thunder",
		name = "Trovão",
		color = Color3.fromRGB(255, 220, 60),
		tiers = {
			{ name = "Raios em Cadeia", desc = "Raio que pula entre 4 inimigos.", kind = "chain", cd = 6, damage = 40, jumps = 4, range = 20 },
			{ name = "Salto Elétrico", desc = "Raio que pula entre 8 inimigos.", kind = "chain", cd = 15, damage = 60, jumps = 8, range = 30 },
			{ name = "Pilar de Raios", desc = "Pilar de raios no alvo.", kind = "strike", visual = "lightning", cd = 20, damage = 150, radius = 8, delay = 0.3 },
			{ name = "Tempestade Divina", desc = "Raios caem por toda a arena.", kind = "strike", visual = "lightning", cd = 55, damage = 80, radius = 7, count = 40, interval = 0.1, delay = 0.3, area = 70 },
		},
	},
	{
		id = "darkness",
		name = "Escuridão",
		color = Color3.fromRGB(90, 40, 140),
		tiers = {
			{ name = "Nuvem Sombria", desc = "Nuvem de escuridão que fere.", kind = "zone", cd = 6, dps = 30, radius = 9, duration = 4 },
			{ name = "Cegueira", desc = "Inimigos ficam muito lentos.", kind = "nova", cd = 14, damage = 15, radius = 14, slow = 0.3, slowTime = 5, atTarget = true },
			{ name = "Devorar Almas", desc = "Dano em área que rouba vida.", kind = "nova", cd = 18, damage = 80, radius = 14, lifesteal = 0.3 },
			{ name = "Noite Eterna", desc = "Escuridão total ao seu redor.", kind = "zone", cd = 60, dps = 150, radius = 35, duration = 10, follow = true, slow = 0.5 },
		},
	},
	{
		id = "chaos_blades",
		name = "Lâminas do Caos",
		color = Color3.fromRGB(255, 60, 200),
		tiers = {
			{ name = "Órbita Caótica", desc = "3 lâminas orbitam você.", kind = "orbit", cd = 6, damage = 30, count = 3, radius = 7, duration = 6 },
			{ name = "Corte Telecinético", desc = "2 lâminas teleguiadas.", kind = "projectile", visual = "blade", cd = 15, damage = 70, count = 2, spread = 30, homing = true },
			{ name = "Espiral de Lâminas", desc = "12 lâminas em espiral.", kind = "projectile", visual = "blade", cd = 20, damage = 60, count = 12, spread = 360, pierce = 2 },
			{ name = "Dança do Caos", desc = "Centenas de lâminas giram ao seu redor.", kind = "orbit", cd = 55, damage = 80, count = 12, radius = 14, duration = 10, spin = 5 },
		},
	},
	{
		id = "elemental",
		name = "Domínio Elemental",
		color = Color3.fromRGB(255, 200, 80),
		colors = {
			Color3.fromRGB(255, 90, 40),
			Color3.fromRGB(90, 200, 255),
			Color3.fromRGB(90, 255, 120),
			Color3.fromRGB(255, 230, 80),
		},
		tiers = {
			{ name = "Fusão Elemental", desc = "3 projéteis elementais.", kind = "projectile", cd = 6, damage = 40, count = 3, spread = 30 },
			{ name = "Orbes Elementais", desc = "4 orbes orbitam você.", kind = "orbit", cd = 15, damage = 35, count = 4, radius = 10, duration = 8 },
			{ name = "Combo Elemental", desc = "3 explosões elementais.", kind = "strike", visual = "pillar", cd = 20, damage = 120, radius = 9, count = 3, interval = 0.3, area = 40 },
			{ name = "Cataclismo Elemental", desc = "Todos os elementos de uma vez.", kind = "strike", visual = "meteor", cd = 60, damage = 100, radius = 10, count = 25, interval = 0.1, area = 70 },
		},
	},
}

Powers.ById = {}
for _, power in Powers.List do
	Powers.ById[power.id] = power
end

return Powers
