-- Quem está em qual run, e dano/cura em jogadores (considera escudo e invencibilidade).
local Registry = {
	ByPlayer = {}, -- [Player] = estado do jogador na run (criado em DungeonService)
}

function Registry.GetRoot(player)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart"), character:FindFirstChildOfClass("Humanoid")
end

function Registry.DamagePlayer(player, amount)
	local _, humanoid = Registry.GetRoot(player)
	if not humanoid or humanoid.Health <= 0 then
		return 0
	end
	local state = Registry.ByPlayer[player]
	if state then
		local now = os.clock()
		if now < state.invulnUntil then
			return 0
		end
		if state.shield > 0 and now < state.shieldUntil then
			local absorbed = math.min(state.shield, amount)
			state.shield -= absorbed
			amount -= absorbed
		end
	end
	if amount > 0 then
		humanoid:TakeDamage(amount)
	end
	return amount
end

function Registry.HealPlayer(player, amount)
	local _, humanoid = Registry.GetRoot(player)
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	end
end

return Registry
