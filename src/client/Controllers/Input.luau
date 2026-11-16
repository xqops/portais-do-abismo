-- Controles: clique = ataque básico (segurar repete), Q = esquiva, 1-4 = ultimates.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local Input = {}

local DASH_COOLDOWN = 2.5
local DASH_SPEED = 85
local DASH_TIME = 0.18
local ATTACK_INTERVAL = 0.32 -- precisa ser >= BasicAttack.cooldown (Config/Game.luau)

local ULTIMATE_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
}

local lastDash = 0
local attacking = false

local function getCharacter()
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart"), character:FindFirstChildOfClass("Humanoid")
end

local function attack()
	local root, humanoid = getCharacter()
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local direction = mouse.Hit.Position - root.Position
	if Vector3.new(direction.X, 0, direction.Z).Magnitude < 0.5 then
		direction = root.CFrame.LookVector
	end
	Net.BasicAttack:FireServer(direction)
end

local function dash()
	local root, humanoid = getCharacter()
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	if now - lastDash < DASH_COOLDOWN then
		return
	end
	lastDash = now

	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit

	local attachment = root:FindFirstChild("RootAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "RootAttachment"
		attachment.Parent = root
	end
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.MaxForce = math.huge
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VectorVelocity = direction * DASH_SPEED
	velocity.Parent = root
	task.delay(DASH_TIME, function()
		velocity:Destroy()
	end)
end

function Input.GetDashCooldown()
	return math.max(0, DASH_COOLDOWN - (os.clock() - lastDash)), DASH_COOLDOWN
end

function Input.Init()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if attacking then
				return
			end
			attacking = true
			task.spawn(function()
				while attacking do
					attack()
					task.wait(ATTACK_INTERVAL)
				end
			end)
		elseif input.KeyCode == Enum.KeyCode.Q then
			dash()
		elseif ULTIMATE_KEYS[input.KeyCode] then
			Net.CastUltimate:FireServer(ULTIMATE_KEYS[input.KeyCode])
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			attacking = false
		end
	end)
end

return Input
