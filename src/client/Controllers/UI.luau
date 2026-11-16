-- HUD: perfil da conta, estado da run, slots de poder, barras de vida/XP,
-- painel de level up com 3 cartas e avisos na tela.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local player = Players.LocalPlayer

local UI = {}

local C = {
	panel = Color3.fromRGB(28, 22, 18),
	panelLight = Color3.fromRGB(58, 46, 36),
	gold = Color3.fromRGB(235, 190, 90),
	text = Color3.fromRGB(245, 235, 215),
	muted = Color3.fromRGB(170, 155, 135),
	hp = Color3.fromRGB(220, 60, 60),
	xp = Color3.fromRGB(90, 200, 255),
	shield = Color3.fromRGB(140, 220, 255),
	dark = Color3.fromRGB(16, 12, 10),
}
local FONT_TITLE = Enum.Font.GothamBlack
local FONT_BODY = Enum.Font.GothamBold

local KIND_BADGE = {
	new = "NOVO PODER",
	upgrade = "EVOLUÇÃO",
	ultimate = "ULTIMATE",
	stat = "ATRIBUTO",
}

-- helpers ----------------------------------------------------------------------

local function new(className, props, children)
	local instance = Instance.new(className)
	local parent = props.Parent
	props.Parent = nil
	for key, value in props do
		instance[key] = value
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	instance.Parent = parent
	return instance
end

local function corner(radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 6) })
end

local function stroke(color, thickness)
	return new("UIStroke", { Color = color, Thickness = thickness or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function text(props)
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or C.text
	props.Font = props.Font or FONT_BODY
	props.TextSize = props.TextSize or 14
	return new("TextLabel", props)
end

local function makeBar(parent, size, position, color)
	local back = new("Frame", {
		Parent = parent,
		Size = size,
		Position = position,
		BackgroundColor3 = C.dark,
		BorderSizePixel = 0,
	}, { corner(4), stroke(C.gold, 1) })
	local fill = new("Frame", { Parent = back, Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, { corner(4) })
	local label = text({ Parent = back, Size = UDim2.fromScale(1, 1), TextSize = 12, Text = "", ZIndex = 3 })
	return { back = back, fill = fill, label = label }
end

local function setBar(bar, ratio)
	bar.fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
end

local function formatTime(seconds)
	return string.format("%02d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

-- slot de poder ----------------------------------------------------------------

local function makeSlot(parent, index)
	local frame = new("Frame", {
		Parent = parent,
		Size = UDim2.fromOffset(120, 84),
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.1,
		LayoutOrder = index,
		ClipsDescendants = true,
	}, { corner(8) })
	local border = stroke(C.panelLight, 2)
	border.Parent = frame
	local strip = new("Frame", { Parent = frame, Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = C.panelLight, BorderSizePixel = 0 })
	local name = text({
		Parent = frame,
		Position = UDim2.fromOffset(8, 10),
		Size = UDim2.new(1, -30, 0, 18),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "Vazio",
		TextColor3 = C.muted,
	})
	text({
		Parent = frame,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 9),
		Size = UDim2.fromOffset(18, 18),
		Font = FONT_TITLE,
		TextSize = 15,
		Text = tostring(index),
		TextColor3 = C.muted,
	})
	local pips = {}
	for i = 1, 4 do
		pips[i] = new("Frame", {
			Parent = frame,
			Position = UDim2.fromOffset(8 + (i - 1) * 26, 32),
			Size = UDim2.fromOffset(22, 6),
			BackgroundColor3 = C.dark,
			BorderSizePixel = 0,
		}, { corner(2) })
	end
	local ult = text({
		Parent = frame,
		Position = UDim2.fromOffset(8, 44),
		Size = UDim2.new(1, -16, 0, 34),
		TextSize = 11,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		TextColor3 = C.muted,
	})
	local cooldown = new("Frame", {
		Parent = frame,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
	})
	return { frame = frame, border = border, strip = strip, name = name, pips = pips, ult = ult, cooldown = cooldown }
end

local function updateSlot(slot, data)
	if not data then
		slot.name.Text = "Vazio"
		slot.name.TextColor3 = C.muted
		slot.strip.BackgroundColor3 = C.panelLight
		slot.border.Color = C.panelLight
		slot.ult.Text = ""
		slot.cooldown.Size = UDim2.fromScale(1, 0)
		for _, pip in slot.pips do
			pip.BackgroundColor3 = C.dark
		end
		return
	end
	slot.name.Text = data.name
	slot.name.TextColor3 = C.text
	slot.strip.BackgroundColor3 = data.color
	for i, pip in slot.pips do
		if i <= data.tier then
			pip.BackgroundColor3 = i == 4 and C.gold or data.color
		else
			pip.BackgroundColor3 = C.dark
		end
	end
	if data.ult then
		if data.ultCd > 0 then
			slot.ult.Text = string.format("ULT em %ds", math.ceil(data.ultCd))
			slot.ult.TextColor3 = C.muted
			slot.border.Color = data.color
			slot.cooldown.Size = UDim2.fromScale(1, data.ultCd / data.ultMax)
		else
			slot.ult.Text = "ULT PRONTA!\n" .. data.ult
			slot.ult.TextColor3 = C.gold
			slot.border.Color = C.gold
			slot.cooldown.Size = UDim2.fromScale(1, 0)
		end
	else
		slot.ult.Text = "Nv " .. data.tier .. "/4"
		slot.ult.TextColor3 = C.muted
		slot.border.Color = data.color
		slot.cooldown.Size = UDim2.fromScale(1, 0)
	end
end

-- construção da interface ----------------------------------------------------------

function UI.Init()
	local gui = new("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- perfil (canto superior direito) ----------------------------------------------
	local profile = new("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(240, 74),
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.15,
	}, { corner(8), stroke(C.gold, 1.5) })
	local profileLevel = text({
		Parent = profile,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(0.5, -12, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = FONT_TITLE,
		TextSize = 16,
		TextColor3 = C.gold,
		Text = "NV 1",
	})
	local profileGold = text({
		Parent = profile,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.new(0.5, -12, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 15,
		Text = "0 ouro",
	})
	local accountBar = makeBar(profile, UDim2.new(1, -24, 0, 10), UDim2.fromOffset(12, 34), C.xp)
	local profileProgress = text({
		Parent = profile,
		Position = UDim2.fromOffset(12, 50),
		Size = UDim2.new(1, -24, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 12,
		TextColor3 = C.muted,
		Text = "Masmorras: 0",
	})

	-- dica do lobby ---------------------------------------------------------------
	local lobbyHint = text({
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(700, 24),
		TextSize = 15,
		TextStrokeTransparency = 0.4,
		Text = "Entre em um portal com seus amigos  ·  [Clique] atacar  ·  [Q] esquivar  ·  [1-4] ultimates",
	})

	-- HUD da run ------------------------------------------------------------------------
	local runFrame = new("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false })

	local top = new("Frame", {
		Parent = runFrame,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(520, 90),
		BackgroundTransparency = 1,
	})
	local dungeonLabel = text({
		Parent = top,
		Size = UDim2.new(1, 0, 0, 28),
		Font = FONT_TITLE,
		TextSize = 24,
		TextColor3 = C.gold,
		TextStrokeTransparency = 0.5,
	})
	local waveLabel = text({
		Parent = top,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 16,
		TextStrokeTransparency = 0.5,
	})
	local bossBar = makeBar(top, UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 56), C.hp)
	bossBar.back.Visible = false

	local statsPanel = new("Frame", {
		Parent = runFrame,
		Position = UDim2.fromOffset(16, 70),
		Size = UDim2.fromOffset(170, 88),
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.25,
	}, {
		corner(8),
		stroke(C.panelLight, 1.5),
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingTop = UDim.new(0, 8) }),
		new("UIListLayout", { Padding = UDim.new(0, 2) }),
	})
	local function statLine(order)
		return text({
			Parent = statsPanel,
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 14,
		})
	end
	local timeLabel = statLine(1)
	local killsLabel = statLine(2)
	local goldLabel = statLine(3)
	local enemiesLabel = statLine(4)

	local bottom = new("Frame", {
		Parent = runFrame,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(560, 146),
		BackgroundTransparency = 1,
	})
	local slotsRow = new("Frame", { Parent = bottom, Size = UDim2.new(1, 0, 0, 84), BackgroundTransparency = 1 }, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})
	local slots = {}
	for i = 1, 4 do
		slots[i] = makeSlot(slotsRow, i)
	end
	local hpBar = makeBar(bottom, UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 94), C.hp)
	local shieldFill = new("Frame", {
		Parent = hpBar.back,
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.shield,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, { corner(4) })
	local levelLabel = text({
		Parent = bottom,
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.fromOffset(64, 22),
		Font = FONT_TITLE,
		TextSize = 18,
		TextColor3 = C.gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "NV 1",
	})
	local xpBar = makeBar(bottom, UDim2.new(1, -70, 0, 14), UDim2.fromOffset(70, 124), C.xp)

	-- flash de dano -----------------------------------------------------------------
	local hurtFlash = new("Frame", {
		Parent = gui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.hp,
		BackgroundTransparency = 1,
		ZIndex = 5,
	})

	-- painel de level up ----------------------------------------------------------------
	local levelPanel = new("Frame", {
		Parent = gui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		Visible = false,
		ZIndex = 10,
	})
	local levelTitle = text({
		Parent = levelPanel,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.14, 0),
		Size = UDim2.fromOffset(700, 40),
		Font = FONT_TITLE,
		TextSize = 34,
		TextColor3 = C.gold,
		TextStrokeTransparency = 0.4,
		Text = "SUBIU DE NÍVEL!",
	})
	text({
		Parent = levelPanel,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.14, 44),
		Size = UDim2.fromOffset(700, 22),
		TextSize = 16,
		TextColor3 = C.muted,
		Text = "Escolha uma carta — o jogo continua rolando!",
	})
	local cardsRow = new("Frame", {
		Parent = levelPanel,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(760, 330),
		BackgroundTransparency = 1,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 20),
		}),
	})

	local function makeCard(index, card)
		local button = new("TextButton", {
			Parent = cardsRow,
			LayoutOrder = index,
			Size = UDim2.fromOffset(230, 320),
			BackgroundColor3 = C.panel,
			AutoButtonColor = true,
			Text = "",
		}, { corner(10), stroke(card.color, 2.5) })
		new("Frame", { Parent = button, Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = card.color, BorderSizePixel = 0 }, { corner(10) })
		text({
			Parent = button,
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, 0, 0, 18),
			TextSize = 13,
			TextColor3 = card.kind == "ultimate" and C.gold or card.color,
			Text = KIND_BADGE[card.kind] or "",
		})
		text({
			Parent = button,
			Position = UDim2.fromOffset(12, 48),
			Size = UDim2.new(1, -24, 0, 56),
			Font = FONT_TITLE,
			TextSize = 22,
			TextWrapped = true,
			Text = card.title,
		})
		text({
			Parent = button,
			Position = UDim2.fromOffset(12, 110),
			Size = UDim2.new(1, -24, 0, 22),
			TextSize = 16,
			TextColor3 = card.color,
			TextWrapped = true,
			Text = card.ability,
		})
		text({
			Parent = button,
			Position = UDim2.fromOffset(16, 142),
			Size = UDim2.new(1, -32, 0, 100),
			TextSize = 14,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = C.muted,
			Text = card.desc,
		})
		local footer = ""
		if card.kind == "ultimate" then
			footer = string.format("Manual · recarga %ds", card.cd)
		elseif card.cd then
			footer = string.format("Automática · recarga %ds", card.cd)
		end
		text({
			Parent = button,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -40),
			Size = UDim2.new(1, -24, 0, 18),
			TextSize = 12,
			TextColor3 = C.muted,
			Text = footer,
		})
		if card.tier > 0 then
			for i = 1, 4 do
				new("Frame", {
					Parent = button,
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, (i - 2.5) * 34, 1, -16),
					Size = UDim2.fromOffset(28, 8),
					BackgroundColor3 = i <= card.tier and (i == 4 and C.gold or card.color) or C.dark,
					BorderSizePixel = 0,
				}, { corner(2) })
			end
		end
		return button
	end

	local function showOffer(cards, level)
		for _, child in cardsRow:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if not cards then
			levelPanel.Visible = false
			return
		end
		levelTitle.Text = level == 1 and "ESCOLHA SEU PRIMEIRO PODER" or ("NÍVEL " .. tostring(level) .. "!")
		local chosen = false
		for i, card in cards do
			local button = makeCard(i, card)
			button.MouseButton1Click:Connect(function()
				if chosen then
					return
				end
				chosen = true
				levelPanel.Visible = false
				Net.ChooseCard:FireServer(i)
			end)
		end
		levelPanel.Visible = true
		cardsRow.Position = UDim2.fromScale(0.5, 0.62)
		TweenService:Create(cardsRow, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.55) }):Play()
	end

	-- avisos --------------------------------------------------------------------------
	local toastTitle = text({
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.2, 0),
		Size = UDim2.fromOffset(800, 40),
		Font = FONT_TITLE,
		TextSize = 32,
		TextColor3 = C.gold,
		TextStrokeTransparency = 0.3,
		TextTransparency = 1,
		ZIndex = 20,
	})
	local toastSub = text({
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.2, 42),
		Size = UDim2.fromOffset(800, 24),
		TextSize = 17,
		TextStrokeTransparency = 0.4,
		TextTransparency = 1,
		ZIndex = 20,
	})
	local toastToken = 0
	local function notify(title, subtitle)
		toastToken += 1
		local token = toastToken
		toastTitle.Text = title or ""
		toastSub.Text = subtitle or ""
		toastTitle.TextTransparency = 0
		toastSub.TextTransparency = 0
		task.delay(2.8, function()
			if toastToken == token then
				local info = TweenInfo.new(0.6)
				TweenService:Create(toastTitle, info, { TextTransparency = 1 }):Play()
				TweenService:Create(toastSub, info, { TextTransparency = 1 }):Play()
			end
		end)
	end

	-- eventos do servidor -------------------------------------------------------------
	local runState = { inRun = false }

	Net.RunState.OnClientEvent:Connect(function(state)
		runState = state
		runFrame.Visible = state.inRun
		lobbyHint.Visible = not state.inRun
		if not state.inRun then
			levelPanel.Visible = false
			return
		end
		dungeonLabel.Text = string.upper(state.dungeon)
		if state.wave > state.waves then
			waveLabel.Text = "CHEFE"
		elseif state.wave == 0 then
			waveLabel.Text = "Preparando..."
		else
			waveLabel.Text = string.format("Onda %d/%d", state.wave, state.waves)
		end
		if state.boss then
			bossBar.back.Visible = true
			setBar(bossBar, state.boss.hp / state.boss.max)
			bossBar.label.Text = string.format("%s  ·  %d/%d", state.boss.name, math.ceil(state.boss.hp), math.floor(state.boss.max))
		else
			bossBar.back.Visible = false
		end
		timeLabel.Text = "Tempo  " .. formatTime(state.time)
		killsLabel.Text = "Abates  " .. state.kills
		goldLabel.Text = "Ouro  " .. state.gold
		enemiesLabel.Text = "Inimigos  " .. state.enemies
		levelLabel.Text = "NV " .. state.level
		setBar(xpBar, state.xp / state.xpNeed)
		xpBar.label.Text = string.format("%d / %d XP", state.xp, state.xpNeed)
		for i = 1, 4 do
			updateSlot(slots[i], state.slots[i])
		end
	end)

	Net.LevelUpOffer.OnClientEvent:Connect(showOffer)
	Net.Notify.OnClientEvent:Connect(notify)

	Net.Profile.OnClientEvent:Connect(function(data)
		profileLevel.Text = "CONTA NV " .. data.level
		profileGold.Text = data.gold .. " ouro"
		setBar(accountBar, data.xp / data.xpNeed)
		profileProgress.Text = string.format("Masmorras concluídas: %d/%d", data.cleared, data.totalDungeons)
	end)
	Net.Profile:FireServer() -- pede o perfil agora que o HUD está pronto

	-- vida e escudo (lidos direto do personagem) --------------------------------------
	local lastHealth = nil
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			lastHealth = nil
			return
		end
		local maxHealth = math.max(1, humanoid.MaxHealth)
		setBar(hpBar, humanoid.Health / maxHealth)
		local shield = math.floor(runState.inRun and runState.shield or 0)
		shieldFill.Size = UDim2.fromScale(math.clamp(shield / maxHealth, 0, 1), 1)
		hpBar.label.Text = string.format("%d / %d%s", math.ceil(humanoid.Health), math.floor(maxHealth), shield > 0 and string.format("  (+%d escudo)", shield) or "")

		if lastHealth and humanoid.Health < lastHealth - 0.5 then
			hurtFlash.BackgroundTransparency = 0.75
			TweenService:Create(hurtFlash, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		end
		lastHealth = humanoid.Health
	end)
end

return UI
