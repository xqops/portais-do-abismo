-- Ponto de entrada do cliente
local Controllers = script:WaitForChild("Controllers")

local VFX = require(Controllers:WaitForChild("VFX"))
VFX.Init()
require(Controllers:WaitForChild("Animator")).Init(VFX)
require(Controllers:WaitForChild("Feedback")).Init(VFX)
require(Controllers:WaitForChild("UI")).Init()
require(Controllers:WaitForChild("Input")).Init()
