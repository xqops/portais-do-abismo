-- Remotes compartilhados entre servidor e cliente.
-- O servidor cria; o cliente espera eles aparecerem.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTES = {
	"RunState", -- servidor -> cliente: estado da run para o HUD
	"LevelUpOffer", -- servidor -> cliente: cartas para escolher (nil fecha o painel)
	"ChooseCard", -- cliente -> servidor: índice da carta escolhida
	"CastUltimate", -- cliente -> servidor: slot da ultimate (1-4)
	"BasicAttack", -- cliente -> servidor: direção do ataque básico
	"DamageNumber", -- servidor -> cliente: número de dano flutuante
	"Notify", -- servidor -> cliente: aviso grande na tela
	"Profile", -- servidor <-> cliente: dados da conta (cliente pede ao iniciar)
	"Fx", -- servidor -> clientes: efeito visual para desenhar (tipo, dados)
}

local Net = {}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in REMOTES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

for _, name in REMOTES do
	Net[name] = folder:WaitForChild(name)
end

return Net
