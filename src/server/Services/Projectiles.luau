-- Projéteis simulados no servidor (usados por poderes e por inimigos).
local RunService = game:GetService("RunService")

local Effects = require(script.Parent.Effects)

local Projectiles = {}

--[[
	options:
	  origin, direction, speed, range, size, color
	  visual     como o cliente desenha: "orb" (padrão), "blade", "bullet", "lance", "wind", "fireball", "enemy"
	  pierce     quantos alvos extras atravessa (0 = some no primeiro)
	  homing     function(pos) -> Vector3? alvo para curvar
	  hitTest    function(pos, radius) -> lista de alvos perto
	  onHit      function(alvo, pos)
]]
function Projectiles.Fire(options)
	local direction = options.direction
	if direction.Magnitude < 0.01 then
		direction = Vector3.new(0, 0, -1)
	end
	local dir = direction.Unit
	local pos = options.origin
	local size = options.size or 1
	local part = Effects.Part(Enum.PartType.Ball, Vector3.one * size, CFrame.lookAt(pos, pos + dir), options.color, 0, options.visual or "orb")
	local traveled = 0
	local pierceLeft = options.pierce or 0
	local hits = {}

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if options.homing then
			local targetPos = options.homing(pos)
			if targetPos then
				local want = Vector3.new(targetPos.X - pos.X, 0, targetPos.Z - pos.Z)
				if want.Magnitude > 0.5 then
					local turned = dir:Lerp(want.Unit, math.clamp(dt * 6, 0, 1))
					if turned.Magnitude > 0.01 then
						dir = turned.Unit
					end
				end
			end
		end

		local step = options.speed * dt
		pos += dir * step
		traveled += step
		part.CFrame = CFrame.lookAt(pos, pos + dir) -- orientado: o cliente desenha lâminas/lanças apontando para a frente

		for _, target in options.hitTest(pos, size / 2 + 1.5) do
			if not hits[target] then
				hits[target] = true
				options.onHit(target, pos)
				pierceLeft -= 1
				if pierceLeft < 0 then
					traveled = math.huge
					break
				end
			end
		end

		if traveled >= options.range or not part.Parent then
			connection:Disconnect()
			part:Destroy()
		end
	end)
end

return Projectiles
