--[[
	QuestMarker.client.lua

	Indicatore dell'obiettivo corrente. Legge l'attributo replicato
	"StoryStage" e accende un faro luminoso sul bersaglio giusto.

	PER AGGIUNGERE UNA TAPPA: una riga in OBJECTIVES.
	  target = nome esatto del Model o della BasePart nel Workspace
	  enter  = prefisso della coppia di teleport (<prefisso>1 fuori, <prefisso>2 dentro)
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local TweenService      = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ============================================================================
-- OBIETTIVI  [stage] = { ... }
-- ============================================================================

local OBJECTIVES = {
	[0] = { target = "Professor.blox",  label = "Professor Blox",  hint = "Choose your first Bloxmon", enter = "proflab" },
	[1] = { target = "MomDialogue1",    label = "Outside",         hint = "Your mother is looking for you" },
	[2] = { target = "quest pacco",     label = "Professor Blox",  hint = "He has something for you" },
	[3] = { target = "Ruggero",         label = "Poké Market",     hint = "Deliver the package", enter = "market" },
	-- Palestra di Red. I pad non seguono lo schema <prefisso>1/<prefisso>2,
	-- quindi l'ingresso si indica a mano con enterPart.
	[4] = { target = "Red", label = "Fire Gym", hint = "Challenge the Gym Leader",
		enter = "teleport9", enterPart = "teleport9", zone = "teleport9" },
	[5] = { target = "Blu", label = "Water Gym", hint = "Challenge the second Gym Leader" },
	-- Capitolo 2: Team Eclipse
	[6]  = { target = "Ranger Kai",    label = "West Road",   hint = "A ranger past the checkpoint needs help" },
	[7]  = { target = "EclipseGrunt1", label = "West Road",   hint = "Get the stolen Bloxmon back" },
	[8]  = { target = "LukeTrigger2",  label = "Town gate",   hint = "Reach the town past the gate" },
	[9]  = { target = "EclipseGrunt2", label = "Town road",   hint = "Get past the Team Eclipse grunt" },
	[10] = { target = "Commander Nyx", label = "Town square", hint = "Defeat Commander Nyx of Team Eclipse" },
	[11] = { target = "BossArena",    label = "Boss Arena",  hint = "Hunt the Corrupted Bloxmon (one every hour)" },
}

local COLOR      = Color3.fromRGB(255, 214, 84)
local COLOR_DARK = Color3.fromRGB(255, 150, 30)
local BEAM_HEIGHT = 300
local RETRY_TIME  = 1.5
local OBJ_POS = UDim2.new(0, 20, 0, 64)

-- ============================================================================
-- STATO
-- ============================================================================

local current = {
	stage  = nil,
	target = nil,
	parts  = {},
	base   = nil,
	label  = "",
	obj    = nil,
}

local screenGui, edgeArrow, edgeLabel, objTitle, objHint

-- ============================================================================
-- RICERCA BERSAGLIO
-- ============================================================================

local function findTarget(name)
	local lower = string.lower(name)
	for _, d in ipairs(Workspace:GetDescendants()) do
		if (d:IsA("Model") or d:IsA("BasePart")) and string.lower(d.Name) == lower then
			if d:IsA("Model") then
				if d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart") then return d end
			else
				return d
			end
		end
	end
	return nil
end

-- Cache dei pad: whereToAim gira spesso, evito di scandire il Workspace ogni volta
local padCache = {}
local function findPad(name)
	local c = padCache[name]
	if c and c.Parent then return c end
	local found = findTarget(name)
	padCache[name] = found
	return found
end

local function pivotOf(target)
	if target:IsA("Model") then
		local cf, size = target:GetBoundingBox()
		return cf.Position, size
	end
	return target.Position, target.Size
end

-- ============================================================================
-- COSTRUZIONE EFFETTI
-- ============================================================================

local function newPart(name, parent)
	local p = Instance.new("Part")
	p.Name         = name
	p.Anchored     = true
	p.CanCollide   = false
	p.CanQuery     = false
	p.CanTouch     = false
	p.CastShadow   = false
	p.Material     = Enum.Material.Neon
	p.Color        = COLOR
	p.Parent       = parent
	table.insert(current.parts, p)
	return p
end

local function clearMarker()
	for _, inst in ipairs(current.parts) do
		if inst and inst.Parent then inst:Destroy() end
	end
	current.parts  = {}
	current.target = nil
	current.base   = nil
	if edgeArrow then edgeArrow.Visible = false end
end

local function buildMarker(target, label)
	clearMarker()

	current.target = target
	current.label  = label
	current.born   = os.clock()
	current.fx     = {}

	local center, size = pivotOf(target)
	local groundY = center.Y - size.Y / 2
	current.base = Vector3.new(center.X, groundY, center.Z)

	local canHighlight = target:IsA("Model") or target.Transparency < 0.9
	if canHighlight then
		local hl = Instance.new("Highlight")
		hl.Name                = "QuestHighlight"
		hl.Adornee             = target
		hl.FillColor           = COLOR
		hl.OutlineColor        = Color3.fromRGB(255, 255, 240)
		hl.FillTransparency    = 0.75
		hl.OutlineTransparency = 0
		hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent              = Workspace
		table.insert(current.parts, hl)
		current.highlight = hl
	else
		current.highlight = nil
	end

	-- Ancora a terra: tiene beam, anelli e particelle
	local anchor = newPart("QuestAnchor", Workspace)
	anchor.Size         = Vector3.new(3.5, 0.2, 3.5)
	anchor.Transparency = 1
	anchor.CFrame       = CFrame.new(current.base + Vector3.new(0, 0.1, 0))

	local a0 = Instance.new("Attachment")
	a0.Parent = anchor
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, BEAM_HEIGHT, 0)
	a1.Parent = anchor

	-- Colonna di luce: Beam girati verso la camera che sfumano verso l'alto
	local function beam(width, bottom, color)
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.FaceCamera     = true
		b.LightEmission  = 1
		b.LightInfluence = 0
		b.Segments       = 1
		b.Width0, b.Width1 = width, width * 0.6
		b.Color = ColorSequence.new(color)
		b.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, bottom),
			NumberSequenceKeypoint.new(0.3, bottom + (1 - bottom) * 0.5),
			NumberSequenceKeypoint.new(1, 1),
		})
		b.Parent = anchor
		table.insert(current.fx, b)
		return b
	end
	current.beamOuter = beam(4, 0.55, COLOR)
	current.beamCore  = beam(1, 0.1, Color3.fromRGB(255, 250, 225))

	-- Bagliore a terra e anelli veri (vuoti al centro) che si allargano
	local function flatDisc(radius, inner, color, transparency)
		local d = Instance.new("CylinderHandleAdornment")
		d.Adornee      = anchor
		d.CFrame       = CFrame.Angles(math.rad(90), 0, 0)
		d.Height       = 0.05
		d.Radius       = radius
		d.InnerRadius  = inner
		d.Color3       = color
		d.Transparency = transparency
		d.AlwaysOnTop  = false
		d.Parent       = anchor
		table.insert(current.fx, d)
		return d
	end
	current.glow = flatDisc(3, 0, COLOR_DARK, 0.6)
	current.ripples = {}
	for i = 1, 3 do
		current.ripples[i] = flatDisc(0.5, 0.2, COLOR, 1)
	end

	-- Scintille che salgono dal disco
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture           = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color             = ColorSequence.new(COLOR, Color3.fromRGB(255, 255, 240))
	sparks.Lifetime          = NumberRange.new(1.4, 2.4)
	sparks.Rate              = 18
	sparks.Speed             = NumberRange.new(3, 7)
	sparks.SpreadAngle       = Vector2.new(8, 8)
	sparks.Size              = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.LightEmission     = 1
	sparks.Acceleration      = Vector3.new(0, 2, 0)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Parent            = anchor
	table.insert(current.fx, sparks)

	-- Scie veloci dentro la colonna
	local streaks = Instance.new("ParticleEmitter")
	streaks.Texture           = "rbxasset://textures/particles/sparkles_main.dds"
	streaks.Color             = ColorSequence.new(Color3.fromRGB(255, 250, 225))
	streaks.Lifetime          = NumberRange.new(2, 3)
	streaks.Rate              = 6
	streaks.Speed             = NumberRange.new(10, 18)
	streaks.SpreadAngle       = Vector2.new(2, 2)
	streaks.Size              = NumberSequence.new(0.25, 0)
	streaks.LightEmission     = 1
	streaks.EmissionDirection = Enum.NormalId.Top
	streaks.Parent            = anchor
	table.insert(current.fx, streaks)

	-- Diamante che gira e fluttua sopra il bersaglio
	local diamond = newPart("QuestDiamond", Workspace)
	diamond.Size         = Vector3.new(1.3, 1.3, 1.3)
	diamond.Transparency = 0.05
	current.diamond     = diamond
	current.diamondBase = center + Vector3.new(0, size.Y / 2 + 2.2, 0)

	local dLight = Instance.new("PointLight")
	dLight.Color      = COLOR
	dLight.Brightness = 1.5
	dLight.Range      = 12
	dLight.Parent     = diamond
	table.insert(current.fx, dLight)

	-- Cartello: nome della tappa + distanza
	local signAnchor = newPart("QuestSign", Workspace)
	signAnchor.Size         = Vector3.new(1, 1, 1)
	signAnchor.Transparency = 1
	signAnchor.CFrame       = CFrame.new(center + Vector3.new(0, size.Y / 2 + 4.6, 0))

	local bb = Instance.new("BillboardGui")
	bb.Name        = "QuestSign"
	bb.Size        = UDim2.fromScale(9, 3.4)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 500
	bb.Parent      = signAnchor
	table.insert(current.fx, bb)

	local signTitle = Instance.new("TextLabel")
	signTitle.Size                   = UDim2.fromScale(1, 0.55)
	signTitle.BackgroundTransparency = 1
	signTitle.Font                   = Enum.Font.FredokaOne
	signTitle.Text                   = label
	signTitle.TextColor3             = COLOR
	signTitle.TextStrokeColor3       = Color3.fromRGB(40, 28, 0)
	signTitle.TextStrokeTransparency = 0
	signTitle.TextScaled             = true
	signTitle.Parent                 = bb

	local distText = signTitle:Clone()
	distText.Size       = UDim2.fromScale(1, 0.34)
	distText.Position   = UDim2.fromScale(0, 0.6)
	distText.Font       = Enum.Font.GothamBold
	distText.TextColor3 = Color3.new(1, 1, 1)
	distText.Text       = ""
	distText.Parent     = bb

	current.sign      = signAnchor
	current.signCF    = signAnchor.CFrame
	current.distLabel = distText
	current.bigArrow, current.signArrow = nil, nil
	current.beam, current.core, current.disc, current.ring = nil, nil, nil, nil
end

-- ============================================================================
-- FRECCIA A BORDO SCHERMO
-- ============================================================================

local function buildScreenGui()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name           = "QuestMarkerGui"
	screenGui.ResetOnSpawn   = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder   = 15
	screenGui.Parent         = player:WaitForChild("PlayerGui")

	edgeArrow = Instance.new("TextLabel")
	edgeArrow.Size                   = UDim2.fromScale(0.05, 0.09)
	edgeArrow.AnchorPoint            = Vector2.new(0.5, 0.5)
	edgeArrow.BackgroundTransparency = 1
	edgeArrow.Font                   = Enum.Font.FredokaOne
	edgeArrow.Text                   = "➤"
	edgeArrow.TextColor3             = COLOR
	edgeArrow.TextStrokeColor3       = Color3.fromRGB(40, 28, 0)
	edgeArrow.TextStrokeTransparency = 0.2
	edgeArrow.TextScaled             = true
	edgeArrow.Visible                = false
	edgeArrow.Parent                 = screenGui

	edgeLabel = Instance.new("TextLabel")
	edgeLabel.Size                   = UDim2.fromScale(0.16, 0.028)
	edgeLabel.AnchorPoint            = Vector2.new(0.5, 0.5)
	edgeLabel.BackgroundTransparency = 1
	edgeLabel.Font                   = Enum.Font.GothamBold
	edgeLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
	edgeLabel.TextStrokeTransparency = 0.4
	edgeLabel.TextScaled             = true
	edgeLabel.Visible                = false
	edgeLabel.Parent                 = screenGui

	objTitle = Instance.new("TextLabel")
	objTitle.Name                   = "ObjectiveTitle"
	objTitle.Position               = OBJ_POS
	objTitle.Size                   = UDim2.fromOffset(340, 26)
	objTitle.BackgroundTransparency = 1
	objTitle.Font                   = Enum.Font.FredokaOne
	objTitle.TextXAlignment         = Enum.TextXAlignment.Left
	objTitle.TextColor3             = COLOR
	objTitle.TextStrokeColor3       = Color3.fromRGB(40, 28, 0)
	objTitle.TextStrokeTransparency = 0
	objTitle.TextScaled             = true
	objTitle.Text                   = ""
	objTitle.Parent                 = screenGui

	objHint = objTitle:Clone()
	objHint.Name             = "ObjectiveHint"
	objHint.Position         = OBJ_POS + UDim2.fromOffset(0, 28)
	objHint.Size             = UDim2.fromOffset(340, 20)
	objHint.Font             = Enum.Font.GothamBold
	objHint.TextColor3       = Color3.new(1, 1, 1)
	objHint.TextStrokeColor3 = Color3.fromRGB(15, 15, 25)
	objHint.Parent           = screenGui
end

-- ============================================================================
-- AGGIORNAMENTO
-- ============================================================================

local function hidden()
	return player:GetAttribute("DialogueOpen")
		or player:GetAttribute("ShopOpen")
		or player:GetAttribute("InBattle")
		or player:GetAttribute("CutsceneOpen")
end

local t0 = os.clock()

RunService.RenderStepped:Connect(function()
	if objTitle then
		local vis = not hidden()
		objTitle.Visible, objHint.Visible = vis, vis
	end

	if not current.target or not current.target.Parent then
		if edgeArrow then edgeArrow.Visible = false end
		if edgeLabel then edgeLabel.Visible = false end
		return
	end

	local show = not hidden()
	for _, inst in ipairs(current.parts) do
		if inst:IsA("BasePart") then
			inst.LocalTransparencyModifier = show and 0 or 1
		elseif inst:IsA("Highlight") then
			inst.Enabled = show
		end
	end
	-- Beam, particelle, anelli, luci e cartello non sentono LocalTransparencyModifier
	for _, fx in ipairs(current.fx or {}) do
		if fx:IsA("HandleAdornment") then fx.Visible = show else fx.Enabled = show end
	end

	if not show then
		if edgeArrow then edgeArrow.Visible = false end
		if edgeLabel then edgeLabel.Visible = false end
		return
	end

	local t   = os.clock() - t0
	local pop = 1 - (1 - math.clamp((os.clock() - (current.born or 0)) / 0.6, 0, 1)) ^ 3

	-- Vicino al bersaglio la colonna si stringe e non copre la scena
	local near = 1
	local c0 = player.Character
	local r0 = c0 and c0:FindFirstChild("HumanoidRootPart")
	if r0 and current.base then
		near = math.clamp(((r0.Position - current.base).Magnitude - 6) / 20, 0.25, 1)
	end

	if current.highlight then
		current.highlight.FillTransparency = 0.72 + math.sin(t * 2.6) * 0.12
	end
	if current.beamOuter then
		local w = (4 + math.sin(t * 2.2) * 0.5) * pop * near
		current.beamOuter.Width0, current.beamOuter.Width1 = w, w * 0.6
		local c = (1 + math.sin(t * 3.4) * 0.15) * pop * near
		current.beamCore.Width0, current.beamCore.Width1 = c, c * 0.6
	end
	if current.glow then
		current.glow.Radius       = 3 * pop
		current.glow.Transparency = 0.55 + math.sin(t * 2.6) * 0.1
	end
	if current.ripples then
		for i, r in ipairs(current.ripples) do
			local cyc = ((t + i * 0.6) % 1.8) / 1.8
			local rad = 0.5 + cyc * 6 * pop
			r.Radius       = rad
			r.InnerRadius  = math.max(rad - 0.35, 0)
			r.Transparency = 0.15 + cyc * 0.85
		end
	end
	if current.diamond and current.diamondBase then
		current.diamond.Size = Vector3.one * 1.3 * math.max(pop, 0.05)
		current.diamond.CFrame = CFrame.new(current.diamondBase + Vector3.new(0, math.sin(t * 2.4) * 0.35, 0))
			* CFrame.Angles(0, t * 1.6, 0) * CFrame.Angles(math.rad(45), 0, math.rad(35.26))
	end
	if current.sign and current.signCF then
		current.sign.CFrame = current.signCF + Vector3.new(0, math.sin(t * 2) * 0.25, 0)
	end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local targetPos = current.base or hrp.Position
	local dist = (hrp.Position - targetPos).Magnitude

	if current.distLabel then
		current.distLabel.Text = string.format("%d studs", math.floor(dist))
	end

	local cam = Workspace.CurrentCamera
	if not cam or not edgeArrow then return end

	local screenPos, onScreen = cam:WorldToViewportPoint(targetPos + Vector3.new(0, 4, 0))
	local viewport = cam.ViewportSize

	if onScreen and screenPos.Z > 0 then
		edgeArrow.Visible = false
		edgeLabel.Visible = false
		return
	end

	local dir = Vector2.new(screenPos.X, screenPos.Y) - viewport / 2
	if screenPos.Z < 0 then dir = -dir end
	if dir.Magnitude < 0.001 then dir = Vector2.new(0, -1) end
	dir = dir.Unit

	local margin = 0.12
	local pos = Vector2.new(0.5, 0.5) + dir * (0.5 - margin)
	pos = Vector2.new(math.clamp(pos.X, margin, 1 - margin), math.clamp(pos.Y, margin, 1 - margin))

	edgeArrow.Visible  = true
	edgeArrow.Position = UDim2.fromScale(pos.X, pos.Y)
	edgeArrow.Rotation = math.deg(math.atan2(dir.Y, dir.X))

	edgeLabel.Visible = false
end)

-- ============================================================================
-- CAMBIO OBIETTIVO
-- ============================================================================

local shownStage = nil

local function showObjective(objective, stage)
	if not objTitle then return end
	objTitle.Text = objective and ("★ " .. string.upper(objective.label or objective.target)) or ""
	objHint.Text  = objective and (objective.hint or "") or ""

	if shownStage == stage then return end
	shownStage = stage

	for i, l in ipairs({ objTitle, objHint }) do
		local goal = OBJ_POS + UDim2.fromOffset(0, (i - 1) * 28)
		l.Position = goal - UDim2.fromOffset(40, 0)
		l.TextTransparency, l.TextStrokeTransparency = 1, 1
		TweenService:Create(l, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = goal, TextTransparency = 0, TextStrokeTransparency = 0 }):Play()
	end
end

local searching = false

-- Dentro o fuori? La zona registrata dal teleport comanda; se manca,
-- confronto la distanza dal bersaglio con quella dal pad d'ingresso.
-- Senza zona registrata dal teleport, sei "dentro" solo entro questa distanza
-- dal bersaglio. Alzala se l'interno di un edificio e' molto grande.
local INSIDE_RADIUS = 40

-- ============================================================================
-- INTERNI: se sei dentro e l'obiettivo e' fuori, il marker va sull'uscita
--   near  = part attorno a cui si trova la stanza (basta essere vicino a una)
--   radius, minY, maxY = quanto e' grande la stanza (in orizzontale / altezza)
--   exit  = il pad di teletrasporto che porta fuori da li'
-- ============================================================================
local INTERIORS = {
	{ name = "Your room", near = { "Stanza Giocatore", "Teleport4" }, radius = 30, minY = -38, maxY = -12, exit = "Teleport4" },
	{ name = "Home",      near = { "Teleport3", "Teleport2" },        radius = 45, minY = -58, maxY = -40, exit = "Teleport2" },
	{ name = "Lab",       near = { "Professor.blox", "proflab2" },    radius = 32, minY = -40, maxY = -15, exit = "proflab2" },
}

local function interiorOf(pos)
	for _, room in ipairs(INTERIORS) do
		if pos.Y >= room.minY and pos.Y <= room.maxY then
			for _, n in ipairs(room.near) do
				local p = findPad(n)
				if p then
					local c = pivotOf(p)
					if Vector3.new(pos.X - c.X, 0, pos.Z - c.Z).Magnitude <= room.radius then
						return room
					end
				end
			end
		end
	end
	return nil
end

local function whereToAim(objective)
	local finalName  = objective.target
	local finalLabel = objective.label or objective.target

	-- Dentro camera / casa / laboratorio con l'obiettivo altrove: prima l'uscita
	do
		local char = player.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		local here = hrp and interiorOf(hrp.Position)
		if here then
			local goal = findPad(finalName)
			local gp   = goal and (pivotOf(goal))
			if not gp or interiorOf(gp) ~= here then
				return here.exit, "Exit"
			end
		end
	end

	if not objective.enter then return finalName, finalLabel end

	if player:GetAttribute("Zone") == (objective.zone or objective.enter) then
		return finalName, finalLabel
	end

	-- Prima bastava essere piu' vicino al bersaglio che alla porta: se
	-- l'interno del lab sta vicino a casa tua, il marker saltava la porta.
	local outPad = findPad(objective.enterPart or (objective.enter .. "1"))
	local goal   = findPad(finalName)
	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if outPad and goal and hrp then
		local dGoal = (hrp.Position - (pivotOf(goal))).Magnitude
		local dOut  = (hrp.Position - (pivotOf(outPad))).Magnitude
		if dGoal < INSIDE_RADIUS and dGoal < dOut then
			return finalName, finalLabel
		end
	end

	return (objective.enterPart or (objective.enter .. "1")), finalLabel .. " — Entrance"
end

local function refresh()
	local stage = player:GetAttribute("StoryStage") or 0
	local objective = OBJECTIVES[stage]

	current.stage = stage
	current.obj   = objective
	showObjective(objective, stage)

	if not objective then
		clearMarker()
		return
	end

	local wantName, wantLabel = whereToAim(objective)

	if current.target and current.target.Parent
		and string.lower(current.target.Name) == string.lower(wantName) then
		return
	end

	local target = findTarget(wantName)
	if target then
		buildMarker(target, wantLabel)
		return
	end

	clearMarker()
	warn(("[QuestMarker] stage %d: '%s' non trovato nel Workspace, riprovo..."):format(stage, wantName))

	if searching then return end
	searching = true
	task.spawn(function()
		while current.stage == stage do
			task.wait(RETRY_TIME)
			if current.stage ~= stage then break end
			if current.target and current.target.Parent then break end
			local n, l = whereToAim(objective)
			local found = findTarget(n)
			if found then
				buildMarker(found, l)
				break
			end
		end
		searching = false
	end)
end

buildScreenGui()
player:GetAttributeChangedSignal("StoryStage"):Connect(refresh)
player.CharacterAdded:Connect(function()
	player:SetAttribute("Zone", nil) -- rinasci fuori
	task.wait(1)
	refresh()
end)

task.defer(function()
	task.wait(2)
	refresh()
end)

-- Ricontrolla dentro/fuori dopo ogni teletrasporto
task.spawn(function()
	while true do
		task.wait(0.35)
		-- Sempre: anche uscendo da camera/casa/lab il bersaglio cambia.
		-- Si rifa' solo se serve un bersaglio diverso (niente warn a raffica).
		if current.obj and not searching then
			local want = whereToAim(current.obj)
			local have = current.target and current.target.Parent and current.target.Name
			if not have or string.lower(have) ~= string.lower(want) then
				refresh()
			end
		end
	end
end)
