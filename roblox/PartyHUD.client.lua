--[[
    PartyHUD.client.lua
    StarterPlayer/StarterPlayerScripts/PartyHUD (LocalScript)

    La squadra sempre a schermo, in stile Cobblemon: 6 schede pixel art a
    sinistra, in verticale. Ogni scheda ha il livello, lo strumento tenuto,
    il ritratto 3D del Bloxmon, la barra dei PS in verticale, il nome col
    sesso e la Ball in cui e' stato catturato. Gli slot vuoti sono solo
    linguette che spuntano dal bordo dello schermo.

    Il Bloxmon in testa (il primo non K.O.) esce un po' dalla fila con il
    bordino dorato e la freccetta. Passando col mouse su un'altra scheda la
    si seleziona e accanto compare il riquadro coi PS. Clic su una scheda:
    si apre il menu (tasto M) sulla schermata Bloxmon con quello selezionato.

    Effetti: le schede entrano una dopo l'altra, lampo rosso + scossa quando
    prende danni, lampo verde quando si cura, barra che lampeggia coi PS
    bassi, timbro "K.O.", la Ball che traballa quando cambia la selezione,
    il ritratto del selezionato che ondeggia piano.

    Si nasconde in lotta, nei dialoghi, nei negozi, col menu aperto e se in
    Settings togli "Party on screen".
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local plr       = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")

-- Via le versioni vecchie
for _, g in ipairs(playerGui:GetChildren()) do
	if g:IsA("ScreenGui") and (g.Name == "BloxmonTeam" or g.Name == "BloxmonHUD" or g.Name == "PartyStrip") then
		g:Destroy()
	end
end

local Remotes        = require(ReplicatedStorage:WaitForChild("Remotes"))
local Modules        = ReplicatedStorage:WaitForChild("Modules")
local PokemonFactory = require(Modules:WaitForChild("PokemonFactory"))

-- ============================================================================
-- MISURE (pixel "di progetto": la colonna intera viene poi scalata con uno
-- UIScale in base all'altezza dello schermo)
-- ============================================================================

local P        = 3      -- un "pixel" della pixel art
local BODY_W   = 152    -- larghezza della scheda
local CARD_H   = 96     -- altezza della scheda
local GAP      = 12     -- spazio tra una scheda e l'altra
local COL_W    = 280    -- larghezza della colonna (scheda + freccetta + riquadro PS)
local COL_H    = CARD_H * 6 + GAP * 5
local SCREEN_H = 0.6    -- frazione dell'altezza dello schermo occupata dalla colonna
local CENTER_Y = 0.52   -- centro verticale della colonna
local SELECT_X = 12     -- di quanto esce dalla fila la scheda selezionata
local ARROW_Y  = 76     -- altezza di freccetta e Ball
local TAG_X    = 176    -- riquadro coi PS (al passaggio del mouse)
local TAG_Y    = ARROW_Y - 13
local SHADOW   = 2      -- spostamento dell'ombra del testo

local FONT = Enum.Font.Arcade

local C = {
	ink         = Color3.fromRGB(26, 12, 16),
	body        = Color3.fromRGB(78, 38, 46),
	bodyLight   = Color3.fromRGB(112, 60, 70),
	bodyShade   = Color3.fromRGB(54, 24, 31),
	bodyKO      = Color3.fromRGB(62, 52, 56),
	bodyKOLight = Color3.fromRGB(86, 76, 80),
	bodyKOShade = Color3.fromRGB(44, 36, 40),
	slot        = Color3.fromRGB(46, 20, 27),   -- riquadri incavati (nome, strumento)
	slotLight   = Color3.fromRGB(92, 50, 58),
	slotShade   = Color3.fromRGB(30, 12, 17),
	empty       = Color3.fromRGB(62, 31, 38),
	emptyLight  = Color3.fromRGB(86, 48, 56),
	emptyShade  = Color3.fromRGB(44, 20, 26),
	track       = Color3.fromRGB(36, 16, 21),
	text        = Color3.fromRGB(246, 240, 230),
	textShadow  = Color3.fromRGB(28, 10, 14),
	textKO      = Color3.fromRGB(150, 140, 144),
	white       = Color3.new(1, 1, 1),
	portrait    = Color3.fromRGB(214, 230, 150),  -- sfondo del ritratto se il tipo non si sa
	portraitKO  = Color3.fromRGB(150, 146, 152),
	ballBottom  = Color3.fromRGB(214, 214, 222),
	hpGreen     = Color3.fromRGB(72, 220, 96),
	hpYellow    = Color3.fromRGB(240, 196, 48),
	hpRed       = Color3.fromRGB(232, 76, 66),
	select      = Color3.fromRGB(255, 198, 64),
	gold        = Color3.fromRGB(255, 214, 90),
	male        = Color3.fromRGB(96, 170, 255),
	female      = Color3.fromRGB(255, 120, 176),
	koRed       = Color3.fromRGB(240, 70, 60),
}

-- Sfondo del ritratto in base al primo tipo (nomi inglesi e italiani)
local TYPE_TINT = {}
for names, rgb in pairs({
	["normal normale"]       = { 226, 220, 200 },
	["fire fuoco"]           = { 255, 196, 150 },
	["water acqua"]          = { 170, 206, 255 },
	["grass erba"]           = { 204, 236, 160 },
	["electric elettro"]     = { 255, 236, 150 },
	["ice ghiaccio"]         = { 196, 240, 246 },
	["fighting lotta"]       = { 236, 170, 160 },
	["poison veleno"]        = { 222, 180, 236 },
	["ground terra"]         = { 236, 214, 160 },
	["flying volante"]       = { 206, 214, 255 },
	["psychic psico"]        = { 255, 186, 214 },
	["bug coleottero"]       = { 214, 232, 150 },
	["rock roccia"]          = { 226, 214, 170 },
	["ghost spettro"]        = { 196, 186, 230 },
	["dragon drago"]         = { 190, 176, 255 },
	["dark buio"]            = { 190, 176, 168 },
	["steel acciaio"]        = { 214, 220, 232 },
	["fairy folletto"]       = { 255, 206, 236 },
}) do
	for n in names:gmatch("%S+") do
		TYPE_TINT[n] = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	end
end

-- Problemi di stato: sigla e colore
local STATUS = {}
for names, info in pairs({
	["brn burn burned scottatura sco"]               = { "SCO", Color3.fromRGB(238, 120, 60) },
	["psn poison poisoned tox toxic avvelenamento vel"] = { "VEL", Color3.fromRGB(170, 90, 200) },
	["par paralysis paralyzed paralisi"]             = { "PAR", Color3.fromRGB(216, 184, 32) },
	["slp sleep asleep sonno son"]                   = { "SON", Color3.fromRGB(128, 128, 144) },
	["frz freeze frozen congelamento gel"]           = { "GEL", Color3.fromRGB(96, 180, 220) },
}) do
	for n in names:gmatch("%S+") do
		STATUS[n] = info
	end
end

-- Colore della meta' alta della Ball
local BALLS = {
	poke    = Color3.fromRGB(232, 56, 52),
	great   = Color3.fromRGB(56, 120, 236),
	ultra   = Color3.fromRGB(52, 52, 60),
	master  = Color3.fromRGB(134, 70, 196),
	premier = Color3.fromRGB(240, 240, 244),
	luxury  = Color3.fromRGB(36, 36, 42),
	heal    = Color3.fromRGB(255, 140, 190),
	quick   = Color3.fromRGB(70, 150, 230),
	dusk    = Color3.fromRGB(40, 90, 50),
	net     = Color3.fromRGB(60, 190, 200),
}

local function hpColor(p)
	if p > 0.5 then return C.hpGreen elseif p > 0.2 then return C.hpYellow else return C.hpRed end
end

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

-- ============================================================================
-- PEZZI PIXEL ART (solo Frame, niente UIStroke: cosi' scalano puliti)
-- ============================================================================

-- Due rettangoli incrociati = un rettangolo con gli angoli "mangiati" di un pixel
local function notch(parent, x, y, w, h, color, z)
	local holder = make("Frame", {
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1, ZIndex = z or 1,
	}, parent)
	make("Frame", {
		Position = UDim2.fromOffset(P, 0), Size = UDim2.new(1, -2 * P, 1, 0),
		BackgroundColor3 = color, BorderSizePixel = 0,
	}, holder)
	make("Frame", {
		Position = UDim2.fromOffset(0, P), Size = UDim2.new(1, 0, 1, -2 * P),
		BackgroundColor3 = color, BorderSizePixel = 0,
	}, holder)
	return holder
end

-- Riquadro: bordo scuro smussato, riempimento, luce in alto a sinistra e
-- ombra in basso a destra (scambiandole sembra incavato). Quello che ci va
-- dentro si mette su .box con ZIndex >= 3.
local function pixelBox(parent, x, y, w, h, fill, light, shade, z)
	local box = make("Frame", {
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1, ZIndex = z or 1,
	}, parent)
	notch(box, 0, 0, w, h, C.ink, 1)
	local inner = make("Frame", {
		Position = UDim2.fromOffset(P, P), Size = UDim2.new(1, -2 * P, 1, -2 * P),
		BackgroundColor3 = fill, BorderSizePixel = 0, ZIndex = 2,
	}, box)

	local pb = { box = box, inner = inner, lights = {}, shades = {} }
	if light then
		pb.lights[1] = make("Frame", {
			Size = UDim2.new(1, -P, 0, P), BackgroundColor3 = light, BorderSizePixel = 0,
		}, inner)
		pb.lights[2] = make("Frame", {
			Size = UDim2.new(0, P, 1, -P), BackgroundColor3 = light, BorderSizePixel = 0,
		}, inner)
	end
	if shade then
		pb.shades[1] = make("Frame", {
			Position = UDim2.new(0, P, 1, -P), Size = UDim2.new(1, -P, 0, P),
			BackgroundColor3 = shade, BorderSizePixel = 0,
		}, inner)
		pb.shades[2] = make("Frame", {
			Position = UDim2.new(1, -P, 0, P), Size = UDim2.new(0, P, 1, -P),
			BackgroundColor3 = shade, BorderSizePixel = 0,
		}, inner)
	end
	return pb
end

local function paintBox(pb, fill, light, shade)
	pb.inner.BackgroundColor3 = fill
	for _, f in ipairs(pb.lights) do f.BackgroundColor3 = light end
	for _, f in ipairs(pb.shades) do f.BackgroundColor3 = shade end
end

-- Testo con l'ombra "a pixel": una copia scura spostata in basso a destra
local function label(parent, x, y, w, h, color, z, font, alignX)
	local holder = make("Frame", {
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1, ZIndex = z or 3,
	}, parent)
	local props = {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
		Font = font or FONT, TextScaled = true,
		TextXAlignment = alignX or Enum.TextXAlignment.Center,
	}
	local shadow = make("TextLabel", props, holder)
	shadow.Position = UDim2.fromOffset(SHADOW, SHADOW)
	shadow.TextColor3 = C.textShadow
	local main = make("TextLabel", props, holder)
	main.TextColor3 = color or C.text
	main.ZIndex = 2
	return { holder = holder, main = main, shadow = shadow }
end

local function setText(l, text)
	l.main.Text = text
	l.shadow.Text = text
end

-- Freccetta a gradini che punta a destra: segna la scheda selezionata
local function stepArrow(parent, x0, cy, steps, color, z)
	local holder = make("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z,
	}, parent)
	-- Ogni colonna si sovrappone di un pixel a quella prima: niente fessure
	-- quando lo UIScale da' misure con la virgola
	for j = 0, steps do
		local hh = (steps + 1 - j) * P
		make("Frame", {
			Position = UDim2.fromOffset(x0 + j * P - 1, cy - hh), Size = UDim2.fromOffset(P + 1, hh * 2),
			BackgroundColor3 = C.ink, BorderSizePixel = 0,
		}, holder)
	end
	for j = 0, steps - 1 do
		local hh = (steps - j) * P
		make("Frame", {
			Position = UDim2.fromOffset(x0 + j * P - 1, cy - hh), Size = UDim2.fromOffset(P + 1, hh * 2),
			BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 2,
		}, holder)
	end
	return holder
end

local function round(o)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, o)
	return o
end

-- La Ball: cerchio scuro (bordo), faccia colore/fascia/bianco, bottone, riflesso
local function makeBall(parent, cx, cy, d, z)
	local ball = round(make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(d, d),
		BackgroundColor3 = C.ink, BorderSizePixel = 0, ZIndex = z,
	}, parent))
	local face = round(make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -2 * P, 1, -2 * P),
		BackgroundColor3 = C.white, BorderSizePixel = 0,
	}, ball))
	local grad = make("UIGradient", { Rotation = 90 }, face)
	local button = round(make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.42, 0.42),
		BackgroundColor3 = C.ink, BorderSizePixel = 0, ZIndex = 2,
	}, ball))
	round(make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = C.white, BorderSizePixel = 0,
	}, button))
	round(make("Frame", {
		Position = UDim2.fromScale(0.24, 0.17), Size = UDim2.fromScale(0.2, 0.14),
		BackgroundColor3 = C.white, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 2,
	}, ball))
	return ball, grad
end

local function ballColors(top)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(0.42, top),
		ColorSequenceKeypoint.new(0.43, C.ink),
		ColorSequenceKeypoint.new(0.57, C.ink),
		ColorSequenceKeypoint.new(0.58, C.white),
		ColorSequenceKeypoint.new(1, C.ballBottom),
	})
end

-- ============================================================================
-- LETTURA DEI DATI (con un po' di tolleranza sui nomi dei campi)
-- ============================================================================

local function prettify(id)
	local s = tostring(id or "???"):gsub("[_%-]", " ")
	return (s:gsub("(%a)(%w*)", function(a, b) return a:upper() .. b:lower() end))
end

local function displayName(mon)
	local n = mon.nickname or mon.name or mon.speciesName
	if type(n) == "string" and n ~= "" then return n end
	return prettify(mon.speciesId)
end

local function genderOf(mon)
	local g = mon.gender
	if type(g) ~= "string" or g == "" then return nil end
	g = g:lower():sub(1, 1)
	if g == "m" then return "♂", C.male end
	if g == "f" then return "♀", C.female end
	return nil
end

local function statusOf(mon)
	local st = mon.status or mon.statusCondition
	if type(st) == "table" then st = st.name or st.id or st.type end
	if type(st) ~= "string" or st == "" then return nil end
	return STATUS[st:lower()]
end

local function tintOf(mon)
	local t = (type(mon.types) == "table" and mon.types[1]) or mon.type or mon.type1 or mon.primaryType
	if type(t) == "table" then t = t.name end
	return (type(t) == "string" and TYPE_TINT[t:lower()]) or C.portrait
end

local function ballOf(mon)
	local b = mon.ball or mon.pokeball or mon.caughtBall
	if type(b) ~= "string" then return BALLS.poke end
	b = b:lower():gsub("[^%a]", ""):gsub("ball$", "")
	return BALLS[b] or BALLS.poke
end

-- ============================================================================
-- GUI
-- ============================================================================

local gui = make("ScreenGui", {
	-- Stesso nome del vecchio pannello: la schermata iniziale (MainMenu) lo
	-- aspetta con WaitForChild("BloxmonHUD") e senza restava bloccata
	Name = "BloxmonHUD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local HOME = UDim2.new(0, 0, CENTER_Y, 0)

local column = make("Frame", {
	AnchorPoint = Vector2.new(0, 0.5), Position = HOME, Size = UDim2.fromOffset(COL_W, COL_H),
	BackgroundTransparency = 1,
}, gui)
local scaler = make("UIScale", { Scale = 1 }, column)

local slots = {}

for i = 1, 6 do
	local y = (i - 1) * (CARD_H + GAP)

	local card = make("Frame", {
		Name = "Slot" .. i, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(BODY_W, CARD_H),
		BackgroundTransparency = 1,
	}, column)

	-- Slot vuoto: solo una linguetta che spunta dal bordo dello schermo
	local sliver = pixelBox(card, -16, 0, 34, CARD_H, C.empty, C.emptyLight, C.emptyShade, 1)

	local content = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, Visible = false, ZIndex = 2,
	}, card)
	local pop = make("UIScale", { Scale = 1 }, content)

	-- Selezione: bordino dorato attorno alla scheda + freccetta
	local glow  = notch(content, -P, -P, BODY_W + 2 * P, CARD_H + 2 * P, C.select, 1)
	local arrow = stepArrow(content, BODY_W, ARROW_Y, 6, C.select, 2)

	local body = pixelBox(content, 0, 0, BODY_W, CARD_H, C.body, C.bodyLight, C.bodyShade, 3)

	-- Livello
	local lvTag = label(body.box, 6, 14, 34, 12, C.text)
	setText(lvTag, "Lv.")
	local lvNum = label(body.box, 6, 27, 34, 22, C.text)

	-- Strumento tenuto: riquadro incavato, con una gemma se ce n'e' uno
	local item = pixelBox(body.box, 40, 42, 22, 22, C.slot, C.slotShade, C.slotLight, 3)
	local gem = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(11, 11),
		Rotation = 45, BackgroundColor3 = C.ink, BorderSizePixel = 0, ZIndex = 3, Visible = false,
	}, item.box)
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = C.gold, BorderSizePixel = 0,
	}, gem)

	-- Ritratto: sfondo sfumato col colore del tipo e il Bloxmon in 3D
	local portrait = pixelBox(body.box, 64, 5, 68, 60, C.white, nil, nil, 3)
	local portraitGrad = make("UIGradient", { Rotation = 90 }, portrait.inner)

	local vp = make("ViewportFrame", {
		Position = UDim2.fromOffset(P, P), Size = UDim2.new(1, -2 * P, 1, -2 * P),
		BackgroundTransparency = 1, LightColor = C.white, LightDirection = Vector3.new(-1, -2, -1),
		Ambient = Color3.fromRGB(190, 190, 200), ZIndex = 3,
	}, portrait.box)
	local cam = make("Camera", { FieldOfView = 40 }, vp)
	vp.CurrentCamera = cam

	-- Lampo sopra il ritratto (danni / cure)
	local flash = make("Frame", {
		Position = UDim2.fromOffset(P, P), Size = UDim2.new(1, -2 * P, 1, -2 * P),
		BackgroundColor3 = C.white, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4,
	}, portrait.box)

	-- Problema di stato (in alto a sinistra) e cromatico (in alto a destra)
	local status = pixelBox(portrait.box, 2, 2, 34, 16, C.hpRed, nil, nil, 5)
	status.box.Visible = false
	local statusText = label(status.box, P + 1, P, 34 - 2 * P - 2, 16 - 2 * P, C.white, 3)
	local shiny = label(portrait.box, 68 - 19, 3, 16, 16, C.gold, 5, Enum.Font.GothamBlack)
	setText(shiny, "★")
	shiny.holder.Visible = false

	-- Timbro K.O.
	local ko = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(60, 26),
		BackgroundTransparency = 1, ZIndex = 6, Visible = false,
	}, portrait.box)
	local koScale = make("UIScale", { Scale = 1 }, ko)
	local koText = label(ko, 0, 0, 60, 26, C.koRed, 1)
	setText(koText, "K.O.")
	koText.main.Rotation = -12
	koText.shadow.Rotation = -12

	-- Barra dei PS verticale, si svuota dall'alto
	local hpBox = pixelBox(body.box, 134, 6, 12, 58, C.track, nil, nil, 3)
	local fill = make("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.hpGreen, BorderSizePixel = 0,
	}, hpBox.inner)
	make("Frame", {
		Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = C.white, BackgroundTransparency = 0.55, BorderSizePixel = 0,
	}, fill)
	for k = 1, 3 do
		make("Frame", {
			Position = UDim2.fromScale(0, k / 4), Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = C.ink, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 2,
		}, hpBox.inner)
	end
	local pulse = TweenService:Create(fill,
		TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BackgroundTransparency = 0.6 })

	-- Nome e sesso
	local strip = pixelBox(body.box, 5, 66, 128, 27, C.slot, C.slotShade, C.slotLight, 3)
	local name = label(strip.box, P + 4, P + 3, 128 - 2 * P - 26, 27 - 2 * P - 6, C.text, 3, nil, Enum.TextXAlignment.Left)
	local gender = label(strip.box, 128 - P - 20, P + 2, 16, 27 - 2 * P - 4, C.male, 3, Enum.Font.GothamBlack)

	-- Ball, appoggiata sulla freccetta
	local ball, ballGrad = makeBall(content, 141, ARROW_Y, 22, 5)
	ballGrad.Color = ballColors(BALLS.poke)

	-- Riquadro coi PS che esce al passaggio del mouse
	local tag = pixelBox(content, TAG_X, TAG_Y, 90, 26, C.body, C.bodyLight, C.bodyShade, 4)
	tag.box.Visible = false
	local tagText = label(tag.box, P + 4, P + 3, 90 - 2 * P - 8, 26 - 2 * P - 6, C.text, 3)

	local hit = make("TextButton", {
		Size = UDim2.fromOffset(BODY_W, CARD_H), BackgroundTransparency = 1, Text = "",
		AutoButtonColor = false, ZIndex = 20,
	}, card)

	slots[i] = {
		y = y, card = card, sliver = sliver, content = content, pop = pop,
		glow = glow, arrow = arrow, body = body, lvTag = lvTag, lvNum = lvNum, gem = gem,
		portraitGrad = portraitGrad, vp = vp, cam = cam, flash = flash,
		status = status, statusText = statusText, shiny = shiny, ko = ko, koScale = koScale,
		fill = fill, pulse = pulse, name = name, gender = gender, ball = ball, ballGrad = ballGrad,
		tag = tag, tagText = tagText, hit = hit,
		species = nil, uid = nil, lastHP = nil, koShown = false, pulsing = false,
		look = nil, offset = nil,
	}
end

-- Scala in base all'altezza dello schermo
local function rescale()
	local cam = workspace.CurrentCamera
	local h = cam and cam.ViewportSize.Y or 720
	scaler.Scale = math.clamp(h * SCREEN_H / COL_H, 0.5, 1.3)
end

local camConn
local function watchCamera()
	if camConn then camConn:Disconnect() end
	local cam = workspace.CurrentCamera
	if cam then camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end
	rescale()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

-- ============================================================================
-- MODELLI
-- ============================================================================

-- Primo piano di tre quarti: la camera sta davanti al Bloxmon (il davanti
-- del suo pivot, lo stesso che usa la lotta). Se il modello ha una testa
-- nella meta' alta si inquadra quella, altrimenti la parte alta del corpo.
local function frameCamera(s, model)
	local pivot = model:GetPivot()
	local cf, size = model:GetBoundingBox()
	local front = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
	front = (front.Magnitude > 0.01) and front.Unit or Vector3.new(0, 0, -1)
	local right = front:Cross(Vector3.new(0, 1, 0))

	local head = model:FindFirstChild("Head", true) or model:FindFirstChild("head", true)
	local look, dist
	if head and head:IsA("BasePart") and head.Position.Y >= cf.Position.Y then
		look = head.Position
		dist = math.max(head.Size.Magnitude * 2.2, size.Magnitude * 0.5)
	else
		look = cf.Position + Vector3.new(0, size.Y * 0.15, 0)
		dist = size.Magnitude * 0.85
	end

	s.look = look
	s.offset = front * dist + right * dist * 0.4 + Vector3.new(0, dist * 0.12, 0)
	s.cam.CFrame = CFrame.lookAt(look + s.offset, look)
end

local function loadModel(s, speciesId, key)
	for _, c in ipairs(s.vp:GetChildren()) do
		if c:IsA("Model") or c:IsA("BasePart") then c:Destroy() end
	end
	s.look, s.offset = nil, nil
	if not speciesId then return end

	local ok, model = pcall(function()
		return PokemonFactory.SpawnModel({ speciesId = speciesId, uniqueId = "strip_" .. key }, CFrame.new(), s.vp)
	end)
	if not ok or not model then return end
	if s.species ~= speciesId then
		model:Destroy()
		return
	end
	frameCamera(s, model)
end

-- ============================================================================
-- ANIMAZIONI
-- ============================================================================

-- Entrata: la scheda "esplode" fuori dal nulla
local function popIn(s, delay)
	s.pop.Scale = 0.01
	TweenService:Create(s.pop,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay or 0),
		{ Scale = 1 }):Play()
end

local function shake(s)
	task.spawn(function()
		for _, dx in ipairs({ -5, 5, -4, 4, -2, 2, 0 }) do
			s.content.Position = UDim2.new(0.5, dx, 0.5, 0)
			task.wait(0.03)
		end
	end)
end

local function flash(s, color)
	s.flash.BackgroundColor3 = color
	s.flash.BackgroundTransparency = 0.2
	TweenService:Create(s.flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
end

-- La Ball traballa come quando si cattura qualcosa
local function wobble(s)
	task.spawn(function()
		for _, r in ipairs({ -28, 22, -12, 6, 0 }) do
			local t = TweenService:Create(s.ball, TweenInfo.new(0.09, Enum.EasingStyle.Sine), { Rotation = r })
			t:Play()
			t.Completed:Wait()
		end
	end)
end

local function stamp(s)
	s.koScale.Scale = 2.4
	TweenService:Create(s.koScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	shake(s)
end

local function setPulse(s, on)
	if on == s.pulsing then return end
	s.pulsing = on
	if on then
		s.pulse:Play()
	else
		s.pulse:Cancel()
		s.fill.BackgroundTransparency = 0
	end
end

-- ============================================================================
-- STATO
-- ============================================================================

local party = {}
local leadIndex, hovered, selected = nil, nil, nil

-- Esce dalla fila il Bloxmon sotto il mouse, se no quello in testa
local function applySelection()
	local sel = (hovered and party[hovered]) and hovered or leadIndex
	for i, s in ipairs(slots) do
		local filled = party[i] ~= nil
		local isSel = filled and i == sel

		TweenService:Create(s.card, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(isSel and SELECT_X or 0, s.y),
		}):Play()
		s.glow.Visible = isSel
		s.arrow.Visible = isSel

		local showTag = filled and i == hovered
		if showTag and not s.tag.box.Visible then
			s.tag.box.Position = UDim2.fromOffset(TAG_X - 12, TAG_Y)
			TweenService:Create(s.tag.box, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
				Position = UDim2.fromOffset(TAG_X, TAG_Y),
			}):Play()
		end
		s.tag.box.Visible = showTag

		if isSel and selected ~= i then wobble(s) end
		if not isSel and s.look then
			s.cam.CFrame = CFrame.lookAt(s.look + s.offset, s.look)
		end
	end
	selected = sel
end

local function refresh()
	leadIndex = nil
	for i = 1, 6 do
		local m = party[i]
		if m and (m.currentHP or 0) > 0 then
			leadIndex = i
			break
		end
	end
	if not leadIndex and party[1] then leadIndex = 1 end

	local appearDelay = 0
	for i, s in ipairs(slots) do
		local mon = party[i]
		if not mon then
			s.content.Visible = false
			s.sliver.box.Visible = true
			s.uid, s.lastHP, s.koShown = nil, nil, false
			setPulse(s, false)
			if s.species then
				s.species = nil
				loadModel(s, nil, "")
			end
		else
			local hp = math.max(0, mon.currentHP or 0)
			local max = math.max(1, (mon.stats and mon.stats.hp) or 1)
			local p = math.clamp(hp / max, 0, 1)
			local fainted = hp <= 0
			local uid = mon.uniqueId or mon.uid or mon.id or mon.speciesId
			local same = s.uid ~= nil and s.uid == uid

			-- Nuovo arrivo in questo slot: entra con un "pop", uno dopo l'altro
			if not s.content.Visible or not same then
				s.content.Visible = true
				popIn(s, appearDelay)
				appearDelay = appearDelay + 0.06
			end
			s.sliver.box.Visible = false

			-- Testi
			setText(s.lvNum, tostring(mon.level or mon.lvl or "?"))
			setText(s.name, displayName(mon))
			local g, gColor = genderOf(mon)
			s.gender.holder.Visible = g ~= nil
			if g then
				setText(s.gender, g)
				s.gender.main.TextColor3 = gColor
			end

			local held = mon.heldItem or mon.item
			s.gem.Visible = held ~= nil and held ~= false and held ~= ""

			local st = statusOf(mon)
			s.status.box.Visible = st ~= nil and not fainted
			if st then
				setText(s.statusText, st[1])
				s.status.inner.BackgroundColor3 = st[2]
			end
			s.shiny.holder.Visible = (mon.shiny or mon.isShiny) and true or false
			s.ballGrad.Color = ballColors(ballOf(mon))

			-- Colori: tutto spento se e' K.O.
			local textColor = fainted and C.textKO or C.text
			s.lvTag.main.TextColor3 = textColor
			s.lvNum.main.TextColor3 = textColor
			s.name.main.TextColor3 = textColor
			if fainted then
				paintBox(s.body, C.bodyKO, C.bodyKOLight, C.bodyKOShade)
			else
				paintBox(s.body, C.body, C.bodyLight, C.bodyShade)
			end
			local tint = fainted and C.portraitKO or tintOf(mon)
			s.portraitGrad.Color = ColorSequence.new(tint:Lerp(C.white, 0.6), tint)
			s.vp.ImageColor3 = fainted and Color3.fromRGB(110, 110, 120) or C.white

			s.ko.Visible = fainted
			if fainted and same and not s.koShown then stamp(s) end
			s.koShown = fainted

			-- PS
			s.fill.Visible = p > 0
			TweenService:Create(s.fill, TweenInfo.new(0.35), {
				Size = UDim2.fromScale(1, p), BackgroundColor3 = hpColor(p),
			}):Play()
			setPulse(s, p > 0 and p <= 0.2)
			setText(s.tagText, fainted and "K.O."
				or ("PS " .. math.floor(hp + 0.5) .. "/" .. math.floor(max + 0.5)))

			if same and s.lastHP then
				if hp < s.lastHP then
					flash(s, C.hpRed)
					shake(s)
				elseif hp > s.lastHP then
					flash(s, C.hpGreen)
				end
			end
			s.uid, s.lastHP = uid, hp

			if s.species ~= mon.speciesId then
				s.species = mon.speciesId
				task.spawn(loadModel, s, mon.speciesId, tostring(i))
			end
		end
	end

	applySelection()
end

-- Il ritratto del selezionato ondeggia piano a destra e sinistra
RunService.RenderStepped:Connect(function()
	if not gui.Enabled or not selected then return end
	local s = slots[selected]
	if not s.look then return end
	local a = math.sin(os.clock() * 1.1) * 0.35
	s.cam.CFrame = CFrame.lookAt(s.look + CFrame.Angles(0, a, 0) * s.offset, s.look)
end)

-- ============================================================================
-- MOUSE: passaggio = selezione, clic = menu sulla schermata Bloxmon
-- ============================================================================

for i, s in ipairs(slots) do
	s.hit.MouseEnter:Connect(function()
		if not party[i] then return end
		hovered = i
		applySelection()
	end)
	s.hit.MouseLeave:Connect(function()
		if hovered ~= i then return end
		hovered = nil
		applySelection()
	end)
	s.hit.MouseButton1Click:Connect(function()
		if not party[i] then return end
		local signal = playerGui:FindFirstChild("PauseMenuSignal")
		if signal then signal:Fire("bloxmon", i) end
	end)
end

-- ============================================================================
-- QUANDO SI VEDE
-- ============================================================================

local WATCH = { "InBattle", "BattleStarting", "DialogueOpen", "ShopOpen", "MenuOpen", "Pref_PartyHUD" }

local function refreshVisible()
	local hidden = plr:GetAttribute("InBattle") or plr:GetAttribute("BattleStarting")
		or plr:GetAttribute("DialogueOpen") or plr:GetAttribute("ShopOpen")
		or plr:GetAttribute("MenuOpen") or plr:GetAttribute("Pref_PartyHUD") == false

	if hidden then
		gui.Enabled = false
		hovered = nil
	elseif not gui.Enabled then
		-- Rientra scivolando da sinistra
		column.Position = UDim2.new(0, -(COL_W * scaler.Scale) - 20, CENTER_Y, 0)
		gui.Enabled = true
		TweenService:Create(column, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Position = HOME,
		}):Play()
		applySelection()
	end
end

for _, a in ipairs(WATCH) do
	plr:GetAttributeChangedSignal(a):Connect(refreshVisible)
end
refreshVisible()

-- ============================================================================
-- DATI
-- ============================================================================

local function setParty(p)
	party = (type(p) == "table") and p or {}
	refresh()
end

Remotes.PartyUpdate.OnClientEvent:Connect(setParty)
Remotes.BattleStarted.OnClientEvent:Connect(function(data)
	if type(data) == "table" and data.party then setParty(data.party) end
end)

refresh()

task.spawn(function()
	for _ = 1, 3 do
		local ok, p = pcall(function() return Remotes.GetParty:InvokeServer() end)
		if ok and type(p) == "table" and #p > 0 then
			setParty(p)
			return
		end
		task.wait(1.5)
	end
end)
