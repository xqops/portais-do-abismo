-- Ponto de entrada do servidor
local Services = script:WaitForChild("Services")

local WorldBuilder = require(Services.WorldBuilder)
local DataService = require(Services.DataService)
local DungeonService = require(Services.DungeonService)
local LobbyService = require(Services.LobbyService)
local WeaponService = require(Services.WeaponService)

WorldBuilder.SetupLighting()
WorldBuilder.BuildLobby()
DataService.Init()
WeaponService.Init()
DungeonService.Init()
LobbyService.Init()

print("[Portais do Abismo] servidor pronto")
