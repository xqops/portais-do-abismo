-- Arquétipos de inimigos. Cada masmorra dá nome/cor própria a eles (ver Dungeons.luau)
-- e multiplica vida/dano.
return {
	chaser = { hp = 50, speed = 13, damage = 8, reach = 2, attackCd = 1, size = Vector3.new(2.5, 3.5, 2), xp = 2, gold = 1 },
	runner = { hp = 28, speed = 18, damage = 5, reach = 2, attackCd = 0.8, size = Vector3.new(2, 2.4, 3), xp = 1, gold = 1 },
	archer = {
		hp = 40,
		speed = 11,
		damage = 9,
		attackCd = 2.4,
		size = Vector3.new(2, 3.6, 1.6),
		ranged = true,
		range = 38,
		projectileSpeed = 45,
		xp = 3,
		gold = 2,
	},
	brute = { hp = 220, speed = 9, damage = 18, reach = 3, attackCd = 1.6, size = Vector3.new(4, 6, 3), xp = 8, gold = 4 },
	-- base de todos os chefes; vida, tamanho e habilidades vêm da masmorra
	boss = { hp = 4000, speed = 12, damage = 22, reach = 4, attackCd = 1.4, skillCd = 5, size = Vector3.new(7, 10, 6), xp = 0, gold = 50 },
}
