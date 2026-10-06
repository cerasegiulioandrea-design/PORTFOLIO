--[[
    MainMenu.client.lua
    StarterPlayer/StarterPlayerScripts/MainMenu (LocalScript)

    Schermata del titolo in stile Pokemon: Astropix vola dritto nel cielo
    notturno sopra le nuvole, con logo e "CLICK TO START". Al clic la camera
    va sulla sua faccia e fa il VERSO, poi compare il menu (NEW GAME,
    CONTINUE, CREDITS). Cliccando nel cielo mentre sei nel menu rifa' il verso.

    NEW GAME fa partire l'intro del professore e il risveglio sulla spiaggia,
    come prima. Interfacce e box di dialogo sono in pixel art, nello stesso
    stile della squadra a schermo (PartyHUD).

    Il vecchio StartMenu non serve piu': lo script lo spegne da solo, e puoi
    anche cancellarlo da StarterGui.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")

local plr       = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")
local camera    = Workspace.CurrentCamera

local Remotes         = require(ReplicatedStorage:WaitForChild("Remotes"))
local Modules         = ReplicatedStorage:WaitForChild("Modules")
local PokemonDatabase = require(Modules:WaitForChild("PokemonDatabase"))
local PokemonFactory  = require(Modules:WaitForChild("PokemonFactory"))

-- ============================================================================
-- KIT PIXEL ART (lo stesso della squadra a schermo, PartyHUD)
-- Riquadri bordeaux con bordo scuro e angoli "mangiati" di un pixel, luce in
-- alto a sinistra e ombra in basso a destra, testo Arcade con l'ombra a
-- pixel, oro per la selezione. Solo Frame: niente UICorner/UIStroke.
-- Dentro Pix.canvas() gli offset sono "pixel a 1080p" e scalano con lo
-- schermo; le misure in scale restano frazioni dello schermo come sempre.
-- La ScreenGui deve avere ZIndexBehavior = Sibling.
-- ============================================================================

local Pix = {}
do
	local TweenService = game:GetService("TweenService")

	Pix.P      = 3                  -- un "pixel" della pixel art (pixel a 1080p)
	Pix.SHADOW = 2                  -- spostamento dell'ombra del testo
	Pix.FONT   = Enum.Font.Arcade
	Pix.SYMBOL = Enum.Font.GothamBlack  -- solo per simboli che Arcade non ha (₽ ★ ♂ ♀)

	local C = {
		ink         = Color3.fromRGB(26, 12, 16),
		body        = Color3.fromRGB(78, 38, 46),
		bodyLight   = Color3.fromRGB(112, 60, 70),
		bodyShade   = Color3.fromRGB(54, 24, 31),
		slot        = Color3.fromRGB(46, 20, 27),    -- riquadri incavati
		slotLight   = Color3.fromRGB(92, 50, 58),
		slotShade   = Color3.fromRGB(30, 12, 17),
		hover       = Color3.fromRGB(96, 48, 58),    -- riga sotto il mouse
		track       = Color3.fromRGB(36, 16, 21),
		text        = Color3.fromRGB(246, 240, 230),
		textDim     = Color3.fromRGB(196, 172, 176),
		textShadow  = Color3.fromRGB(28, 10, 14),
		white       = Color3.new(1, 1, 1),
		gold        = Color3.fromRGB(255, 198, 64),
		goldLight   = Color3.fromRGB(255, 230, 140),
		goldShade   = Color3.fromRGB(196, 132, 28),
		goldText    = Color3.fromRGB(62, 34, 6),
		green       = Color3.fromRGB(72, 190, 96),
		greenLight  = Color3.fromRGB(128, 226, 140),
		greenShade  = Color3.fromRGB(40, 128, 62),
		red         = Color3.fromRGB(214, 64, 58),
		redLight    = Color3.fromRGB(246, 120, 108),
		redShade    = Color3.fromRGB(146, 36, 36),
		blue        = Color3.fromRGB(64, 128, 220),
		blueLight   = Color3.fromRGB(122, 176, 248),
		blueShade   = Color3.fromRGB(38, 80, 156),
		purple      = Color3.fromRGB(136, 84, 200),
		purpleLight = Color3.fromRGB(184, 140, 236),
		purpleShade = Color3.fromRGB(88, 50, 140),
		off         = Color3.fromRGB(96, 84, 88),
		offLight    = Color3.fromRGB(124, 112, 116),
		offShade    = Color3.fromRGB(70, 60, 64),
		hpGreen     = Color3.fromRGB(72, 220, 96),
		hpYellow    = Color3.fromRGB(240, 196, 48),
		hpRed       = Color3.fromRGB(232, 76, 66),
		ballRed     = Color3.fromRGB(232, 56, 52),
		ballBottom  = Color3.fromRGB(214, 214, 222),
	}
	Pix.C = C

	-- { riempimento, luce, ombra }: rilievo; "slot" ha luce e ombra scambiate (incavato)
	Pix.STYLE = {
		panel  = { C.body,   C.bodyLight,   C.bodyShade },
		slot   = { C.slot,   C.slotShade,   C.slotLight },
		hover  = { C.hover,  C.bodyLight,   C.bodyShade },
		track  = { C.track },
		gold   = { C.gold,   C.goldLight,   C.goldShade },
		green  = { C.green,  C.greenLight,  C.greenShade },
		red    = { C.red,    C.redLight,    C.redShade },
		blue   = { C.blue,   C.blueLight,   C.blueShade },
		purple = { C.purple, C.purpleLight, C.purpleShade },
		off    = { C.off,    C.offLight,    C.offShade },
	}

	-- Colore della scritta sopra uno stile (sull'oro ci va scuro)
	function Pix.textOn(style)
		return style == "gold" and C.goldText or C.text
	end

	local function make(class, props, parent)
		local o = Instance.new(class)
		for k, v in pairs(props) do o[k] = v end
		if parent then o.Parent = parent end
		return o
	end
	Pix.make = make

	function Pix.tw(obj, time, props, style, dir)
		local t = TweenService:Create(obj, TweenInfo.new(time,
			style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
		t:Play()
		return t
	end

	local function resolve(style)
		if type(style) == "string" then style = Pix.STYLE[style] end
		return style or Pix.STYLE.panel
	end

	-- Strato dove gli offset valgono "pixel a 1080p": un Frame grande 1/k
	-- dello schermo con uno UIScale k sopra. Le misure in scale non cambiano.
	function Pix.canvas(parent, z)
		local root = make("Frame", {
			Name = "PixCanvas", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z or 1,
		}, parent)
		local scaler = make("UIScale", { Scale = 1 }, root)
		local camConn
		local function fit()
			local cam = workspace.CurrentCamera
			local h = cam and cam.ViewportSize.Y or 1080
			local k = math.clamp(h / 1080, 0.4, 2.5)
			scaler.Scale = k
			root.Size = UDim2.fromScale(1 / k, 1 / k)
		end
		local function watch()
			if camConn then camConn:Disconnect() end
			local cam = workspace.CurrentCamera
			if cam then camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
			fit()
		end
		workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)
		watch()
		return root
	end

	-- Due rettangoli incrociati = un rettangolo con gli angoli "mangiati"
	function Pix.notch(parent, pos, size, color, z)
		local P = Pix.P
		local holder = make("Frame", {
			Position = pos or UDim2.new(), Size = size or UDim2.fromScale(1, 1),
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

	function Pix.notchColor(holder, color)
		for _, f in ipairs(holder:GetChildren()) do
			if f:IsA("Frame") then f.BackgroundColor3 = color end
		end
	end

	-- Riquadro: bordo scuro smussato, riempimento, luce e ombra.
	-- Ritorna { box, edge, inner, content, lights, shades }: le cose vanno in
	-- .content (gia' rientrato dal bordo, ZIndex sopra al riempimento).
	function Pix.box(parent, pos, size, style, z, anchor)
		local P = Pix.P
		local box = make("Frame", {
			Position = pos or UDim2.new(), Size = size or UDim2.fromScale(1, 1),
			AnchorPoint = anchor or Vector2.zero, BackgroundTransparency = 1, ZIndex = z or 1,
		}, parent)
		local edge = Pix.notch(box, UDim2.new(), UDim2.fromScale(1, 1), C.ink, 1)
		local inner = make("Frame", {
			Position = UDim2.fromOffset(P, P), Size = UDim2.new(1, -2 * P, 1, -2 * P),
			BorderSizePixel = 0, ZIndex = 2,
		}, box)
		local pb = { box = box, edge = edge, inner = inner, lights = {}, shades = {} }
		pb.lights[1] = make("Frame", { Size = UDim2.new(1, -P, 0, P), BorderSizePixel = 0 }, inner)
		pb.lights[2] = make("Frame", { Size = UDim2.new(0, P, 1, -P), BorderSizePixel = 0 }, inner)
		pb.shades[1] = make("Frame", {
			Position = UDim2.new(0, P, 1, -P), Size = UDim2.new(1, -P, 0, P), BorderSizePixel = 0,
		}, inner)
		pb.shades[2] = make("Frame", {
			Position = UDim2.new(1, -P, 0, P), Size = UDim2.new(0, P, 1, -P), BorderSizePixel = 0,
		}, inner)
		pb.content = make("Frame", {
			Position = UDim2.fromOffset(2 * P, 2 * P), Size = UDim2.new(1, -4 * P, 1, -4 * P),
			BackgroundTransparency = 1, ZIndex = 3,
		}, box)
		Pix.paint(pb, style)
		return pb
	end

	function Pix.paint(pb, style)
		local s = resolve(style)
		pb.inner.BackgroundColor3 = s[1]
		for _, f in ipairs(pb.lights) do
			f.Visible = s[2] ~= nil
			if s[2] then f.BackgroundColor3 = s[2] end
		end
		for _, f in ipairs(pb.shades) do
			f.Visible = s[3] ~= nil
			if s[3] then f.BackgroundColor3 = s[3] end
		end
	end

	-- Riquadro schiacciato (luce e ombra scambiate): per il clic
	function Pix.press(pb, style, down)
		local s = resolve(style)
		if down then
			Pix.paint(pb, { s[1], s[3], s[2] })
		else
			Pix.paint(pb, s)
		end
	end

	-- Testo con l'ombra a pixel. L'ombra copia da sola Text,
	-- MaxVisibleGraphemes e TextTransparency della scritta: basta usare .main
	-- come un TextLabel normale (anche per l'effetto macchina da scrivere).
	-- opts: text, color, shadowColor, shadow (false = niente ombra), font,
	--       alignX, alignY, wrap, max, min, z, anchor, rotation
	function Pix.text(parent, pos, size, opts)
		opts = opts or {}
		local holder = make("Frame", {
			Position = pos or UDim2.new(), Size = size or UDim2.fromScale(1, 1),
			AnchorPoint = opts.anchor or Vector2.zero, BackgroundTransparency = 1, ZIndex = opts.z or 3,
		}, parent)
		local function lbl(color, z)
			local l = make("TextLabel", {
				Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = opts.text or "",
				Font = opts.font or Pix.FONT, TextScaled = true, TextWrapped = opts.wrap or false,
				TextXAlignment = opts.alignX or Enum.TextXAlignment.Center,
				TextYAlignment = opts.alignY or Enum.TextYAlignment.Center,
				TextColor3 = color, ZIndex = z, Rotation = opts.rotation or 0,
			}, holder)
			if opts.max or opts.min then
				make("UITextSizeConstraint", { MaxTextSize = opts.max or 100, MinTextSize = opts.min or 1 }, l)
			end
			return l
		end
		local t = { holder = holder }
		t.main = lbl(opts.color or C.text, 2)
		if opts.shadow ~= false then
			local sh = lbl(opts.shadowColor or C.textShadow, 1)
			sh.Position = UDim2.fromOffset(Pix.SHADOW, Pix.SHADOW)
			t.shadow = sh
			for _, prop in ipairs({ "Text", "MaxVisibleGraphemes", "TextTransparency" }) do
				t.main:GetPropertyChangedSignal(prop):Connect(function()
					sh[prop] = t.main[prop]
				end)
			end
		end
		return t
	end

	function Pix.setText(t, text)
		t.main.Text = text
	end

	-- Freccetta a gradini. rotation: 0 = destra, 90 = giu', 180 = sinistra, 270 = su.
	-- pos e' il centro. Ritorna l'holder (si puo' muovere/ruotare/nascondere).
	function Pix.arrow(parent, pos, steps, color, z, rotation)
		local P = Pix.P
		local w, h = (steps + 1) * P, 2 * (steps + 1) * P
		local holder = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = pos or UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, ZIndex = z or 1,
			Rotation = rotation or 0,
		}, parent)
		local cy = h / 2
		-- Ogni colonna sborda di un pixel su quella prima: niente fessure con lo UIScale
		for j = 0, steps do
			local hh = (steps + 1 - j) * P
			make("Frame", {
				Position = UDim2.fromOffset(j * P - (j > 0 and 1 or 0), cy - hh),
				Size = UDim2.fromOffset(P + (j > 0 and 1 or 0), hh * 2),
				BackgroundColor3 = C.ink, BorderSizePixel = 0,
			}, holder)
		end
		for j = 0, steps - 1 do
			local hh = (steps - j) * P
			make("Frame", {
				Position = UDim2.fromOffset(j * P - (j > 0 and 1 or 0), cy - hh),
				Size = UDim2.fromOffset(P + (j > 0 and 1 or 0), hh * 2),
				BackgroundColor3 = color or C.gold, BorderSizePixel = 0, ZIndex = 2,
			}, holder)
		end
		return holder
	end

	function Pix.ballColors(top)
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, top),
			ColorSequenceKeypoint.new(0.42, top),
			ColorSequenceKeypoint.new(0.43, C.ink),
			ColorSequenceKeypoint.new(0.57, C.ink),
			ColorSequenceKeypoint.new(0.58, C.white),
			ColorSequenceKeypoint.new(1, C.ballBottom),
		})
	end

	-- La Ball, come quella delle schede della squadra. size: UDim2 (quadrato).
	-- Ritorna ball, gradiente (per cambiare colore: grad.Color = Pix.ballColors(...))
	function Pix.ball(parent, pos, size, z, top)
		local P = Pix.P
		local function round(o)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, o)
			return o
		end
		local ball = round(make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = size,
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundColor3 = C.ink, BorderSizePixel = 0, ZIndex = z or 1,
		}, parent))
		local face = round(make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -2 * P, 1, -2 * P), BackgroundColor3 = C.white, BorderSizePixel = 0,
		}, ball))
		local grad = make("UIGradient", { Rotation = 90, Color = Pix.ballColors(top or C.ballRed) }, face)
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

	-- Barra orizzontale (caricamento, esperienza...). bar.set(p, color, time)
	function Pix.bar(parent, pos, size, color, z, anchor)
		local pb = Pix.box(parent, pos, size, "track", z, anchor)
		local fill = make("Frame", {
			Size = UDim2.fromScale(0, 1), BackgroundColor3 = color or C.gold, BorderSizePixel = 0,
		}, pb.inner)
		make("Frame", {
			Position = UDim2.fromScale(0, 0), Size = UDim2.new(1, 0, 0, Pix.P),
			BackgroundColor3 = C.white, BackgroundTransparency = 0.55, BorderSizePixel = 0,
		}, fill)
		local bar = { pb = pb, fill = fill }
		function bar.set(p, col, time)
			p = math.clamp(p or 0, 0, 1)
			local goal = { Size = UDim2.fromScale(p, 1) }
			if col then goal.BackgroundColor3 = col end
			if time and time > 0 then
				Pix.tw(fill, time, goal)
			else
				for k, v in pairs(goal) do fill[k] = v end
			end
		end
		return bar
	end

	-- Bottone: riquadro + scritta, bordino dorato quando e' "caldo" (mouse o
	-- tastiera), si schiaccia al clic. opts: text, style, z, anchor, max,
	-- textColor, font, manual (true = il bordino lo gestisci tu con setHot)
	-- Ritorna { root, pb, label, hit, scale, glow, setHot, setStyle, setEnabled }
	function Pix.button(parent, pos, size, opts)
		opts = opts or {}
		local P = Pix.P
		local b = { style = opts.style or "panel", enabled = true, hot = false }
		b.root = make("Frame", {
			Position = pos or UDim2.new(), Size = size or UDim2.fromScale(1, 1),
			AnchorPoint = opts.anchor or Vector2.zero, BackgroundTransparency = 1, ZIndex = opts.z or 1,
		}, parent)
		b.scale = make("UIScale", { Scale = 1 }, b.root)
		b.glow = Pix.notch(b.root, UDim2.fromOffset(-P, -P), UDim2.new(1, 2 * P, 1, 2 * P), C.gold, 1)
		b.glow.Visible = false
		b.pb = Pix.box(b.root, UDim2.new(), UDim2.fromScale(1, 1), b.style, 2)
		b.label = Pix.text(b.pb.content, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.86, 0.7), {
			text = opts.text or "", anchor = Vector2.new(0.5, 0.5), max = opts.max, font = opts.font,
			color = opts.textColor or Pix.textOn(b.style),
			shadowColor = b.style == "gold" and C.goldLight or nil,
		})
		b.hit = make("TextButton", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
			AutoButtonColor = false, ZIndex = 10,
		}, b.root)

		function b.setHot(on)
			on = on and b.enabled or false
			if b.hot == on then return end
			b.hot = on
			b.glow.Visible = on
			Pix.tw(b.scale, 0.2, { Scale = on and 1.05 or 1 }, Enum.EasingStyle.Back)
		end
		function b.setStyle(style)
			b.style = style
			Pix.paint(b.pb, b.enabled and style or "off")
			b.label.main.TextColor3 = opts.textColor or Pix.textOn(b.enabled and style or "off")
			if b.label.shadow then
				b.label.shadow.TextColor3 = (b.enabled and style == "gold") and C.goldLight or C.textShadow
			end
		end
		function b.setEnabled(on)
			b.enabled = on
			b.setStyle(b.style)
			if not on then b.setHot(false) end
		end

		if not opts.manual then
			b.hit.MouseEnter:Connect(function() b.setHot(true) end)
			b.hit.MouseLeave:Connect(function() b.setHot(false) end)
		end
		b.hit.MouseButton1Down:Connect(function()
			if not b.enabled then return end
			Pix.press(b.pb, b.style, true)
			Pix.tw(b.scale, 0.08, { Scale = 0.94 })
		end)
		local function release()
			Pix.paint(b.pb, b.enabled and b.style or "off")
			Pix.tw(b.scale, 0.2, { Scale = b.hot and 1.05 or 1 }, Enum.EasingStyle.Back)
		end
		b.hit.MouseButton1Up:Connect(release)
		b.hit.MouseLeave:Connect(release)
		return b
	end

	-- Finestra: riquadro con la fascia del titolo e, se opts.close, la X rossa.
	-- opts: accent (stile della fascia, default "slot"), band (altezza in scale,
	--       default 0.16), close (true), z, anchor
	-- Ritorna { root, pop (UIScale), pb, band, title, close, content }
	function Pix.window(parent, pos, size, title, opts)
		opts = opts or {}
		local P = Pix.P
		local w = {}
		w.root = make("Frame", {
			Position = pos or UDim2.new(), Size = size or UDim2.fromScale(1, 1),
			AnchorPoint = opts.anchor or Vector2.zero, BackgroundTransparency = 1, ZIndex = opts.z or 1,
		}, parent)
		w.pop = make("UIScale", { Scale = 1 }, w.root)
		w.pb = Pix.box(w.root, UDim2.new(), UDim2.fromScale(1, 1), "panel", 1)
		local bandH = opts.band or 0.16
		w.band = Pix.box(w.pb.content, UDim2.new(), UDim2.fromScale(1, bandH), opts.accent or "slot", 1)
		w.title = Pix.text(w.band.content, UDim2.fromScale(0.03, 0.1), UDim2.fromScale(0.75, 0.8), {
			text = title or "", alignX = Enum.TextXAlignment.Left,
			color = Pix.textOn(opts.accent or "slot"),
			shadowColor = (opts.accent == "gold") and C.goldLight or nil,
		})
		if opts.close then
			w.close = Pix.button(w.band.content, UDim2.fromScale(1, 0.5), UDim2.fromScale(0.9, 0.9), {
				text = "X", style = "red", anchor = Vector2.new(1, 0.5), z = 5,
			})
			w.close.root.SizeConstraint = Enum.SizeConstraint.RelativeYY
		end
		w.content = make("Frame", {
			Position = UDim2.new(0, 0, bandH, 2 * P), Size = UDim2.new(1, 0, 1 - bandH, -2 * P),
			BackgroundTransparency = 1, ZIndex = 2,
		}, w.pb.content)
		return w
	end
end

-- Dichiarato dopo il kit, che ha il suo TweenService interno
local TweenService = game:GetService("TweenService")

local PROFESSOR_MODEL_NAME = "professor.blox"

local MON_FACE_YAW = -90   -- gradi. Prova 90 o -90; se serve, 180 o 0

-- Risveglio sulla spiaggia
local WAKE_SPAWN_NAME = "startgame"
local LOCATION_NAME   = "Blox Beach"
local WAVES_SOUND_ID  = ""

-- La mamma ti viene a prendere
local MOM_MODEL_NAME = "mom"
local MOM_SPAWN_PART = "MomBeachSpawn"
local MOM_RUN_ANIM   = "rbxassetid://180426354"
local ROOM_PART_NAME = "Stanza Giocatore"
local ROOM_LABEL     = "Your Room"

-- Schermata del titolo con Astropix
local TITLE_CFG = {
	title       = "BLOXMON",
	logoImage   = "",          -- id di un'immagine logo: se c'e', sostituisce la scritta
	creditsLines = {                 -- la prima riga e' il titolo grande
		"BLOXMON",
		"Created by Fopix",
		"Scripting & building: Fopix",
		"Thanks for playing!",
	},
	loadingTips = {
		"Tall grass hides wild Bloxmon. Walk through it to find them!",
		"Some Bloxmon only come out at night.",
		"Legends say a star-born Bloxmon crosses the night sky...",
		"Every Bloxmon's nature and stats make it unique.",
	},
	-- stessi suoni della GUI di lotta
	sounds = {
		click  = "rbxassetid://78837174260782",
		hover  = "rbxassetid://6324790483",
		denied = "rbxassetid://130457635881559",
		tick   = "rbxassetid://86056556814402",
	},

	model       = "Astropix",
	flyAnim     = "rbxassetid://96541347422493",
	roarAnim    = "rbxassetid://106925668127159",
	crySound    = "",          -- il verso vero di Astropix, se ce l'hai
	size        = 18,
	yawOffset   = 180,         -- stessi valori di LegendaryEncounterClient
	pitchOffset = 0,
	rollOffset  = 0,

	scenePart   = "MenuScene", -- Part facoltativa: il volo parte da li', nella sua direzione
	altitude    = 260,         -- senza MenuScene: quanto sopra lo spawn
	night       = true,
	clock       = 22,
	speed       = 70,          -- velocita' del volo in studs al secondo
}

local profModel, monModel, camGoal
local camStyle, camT0, camFocus, camFov = "static", os.clock(), nil, 60
local frames, frameFocus, frameFov = {}, {}, {}
local profForward, profRight, monSpot

local INTRO_SCRIPT = {
	{ text = "Hello there! Sorry to keep you waiting.", camera = "face", style = "push", soundId = "rbxassetid://89887416490708" },
	{ text = "My name is BLOX. Though everyone around here just calls me the Bloxmon Professor.", camera = "profile", style = "orbit", soundId = "rbxassetid://114242941665190" },
	{ text = "This world of ours is a big place. Mountains, oceans, deep forests... and every corner of it is home to creatures we call BLOXMON.", camera = "high", style = "pull", soundId = "rbxassetid://72050290989458" },
	{ text = "Here — words only get you so far. Let me show you one instead.", camera = "wide", style = "push", soundId = "rbxassetid://97688866337715" },
	{ text = "This is a Bloxmon. Go on, say hello. They're friendlier than they look.", spawn = true, camera = "duo", style = "push", soundId = "rbxassetid://82306315053925" },
	{ text = "Bloxmon like this one live all around us. Some hide in the tall grass, others nest high in the mountains, and a few only come out at night.", camera = "duoClose", style = "orbit", soundId = "rbxassetid://82567222102802" },
	{ text = "For some people, Bloxmon are lifelong partners. Others battle alongside them, to see how far they can go together.", camera = "overMon", style = "push", soundId = "rbxassetid://75514128154200" },
	{ text = "As for me? I study them. And after all these years, I still learn something new every single day.", camera = "faceClose", style = "push", soundId = "rbxassetid://95840023934717" },
	{ text = "But that's quite enough from an old researcher. Today isn't about me.", camera = "profile", style = "pull", soundId = "rbxassetid://134142065943098" },
	{ text = "Today is the day your own story begins. Your very own Bloxmon adventure.", camera = "wideLow", style = "rise", soundId = "rbxassetid://116196709135055" },
	{ text = "A world of dreams and challenges is waiting out there. And something tells me you're ready for it.", camera = "duo", style = "orbit", soundId = "rbxassetid://114218887511249" },
	{ text = "Well then... let's get going!", camera = "faceClose", style = "push", soundId = "rbxassetid://94983434209444" },
}

-- Colori delle scene (le interfacce usano Pix.C)
local C = {
	bgTop    = Color3.fromRGB(18, 22, 40),
	bgBottom = Color3.fromRGB(8, 10, 20),
	skyTop   = Color3.fromRGB(28, 96, 220),
}

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)

-- ============================================================ HELPER

-- Scritta del logo in pixel art: faccia dorata, contorno e "estrusione" di
-- pixel scuri (copie del testo spostate di un pixel grosso). Ritorna la faccia.
local function pixLogo(parent, text, z)
	local LP = Pix.P * 2
	local function copy(dx, dy, color, zz)
		return Pix.make("TextLabel", {
			Position = UDim2.fromOffset(dx, dy), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
			Text = text, Font = Pix.FONT, TextScaled = true, TextColor3 = color, ZIndex = z + zz,
		}, parent)
	end
	for k = 4, 1, -1 do
		copy(k * LP, k * LP, Pix.C.ink, 0)
	end
	for _, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
		copy(d[1] * LP, d[2] * LP, Pix.C.ink, 1)
	end
	local face = copy(0, 0, Pix.C.white, 2)
	Pix.make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0,    Pix.C.goldLight),
			ColorSequenceKeypoint.new(0.5,  Pix.C.gold),
			ColorSequenceKeypoint.new(1,    Pix.C.goldShade),
		}),
	}, face)
	return face
end

-- Box dei dialoghi (intro del professore e la mamma), nello stile della
-- squadra a schermo: riquadro bordeaux, testo in un incavo, targhetta dorata
-- col nome sul bordo in alto e freccetta dorata che salta a fine frase.
-- Ritorna box (da spostare), text (TextLabel per la macchina da scrivere),
-- arrow (si mostra con Visible), tag (TextLabel del nome) e group: il
-- CanvasGroup con tutto il box, per farlo sfumare con GroupTransparency.
local function storyBox(parent, z)
	local TOP    = 26   -- spazio sopra il riquadro per la targhetta che sborda
	local TAG_H  = 40
	local TAG_TX = 24   -- altezza della scritta nella targhetta

	local layer = Pix.canvas(parent, z)
	local box = Pix.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.965),
		Size = UDim2.fromScale(0.62, 0.235), BackgroundTransparency = 1,
	}, layer)
	local group = Pix.make("CanvasGroup", {
		Position = UDim2.fromOffset(0, -TOP), Size = UDim2.new(1, 0, 1, TOP), BackgroundTransparency = 1,
	}, box)

	local panel = Pix.box(group, UDim2.fromOffset(0, TOP), UDim2.new(1, 0, 1, -TOP), "panel", 1)
	local well  = Pix.box(panel.content, UDim2.fromOffset(0, 20), UDim2.new(1, 0, 1, -20), "slot", 1)

	local text = Pix.text(well.content, UDim2.fromOffset(14, 10), UDim2.new(1, -56, 1, -20), {
		alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top, wrap = true, max = 30, min = 8,
	})

	local arrow = Pix.arrow(well.content, UDim2.new(1, -18, 1, -14), 3, Pix.C.gold, 4, 90)
	TweenService:Create(arrow, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.new(1, -18, 1, -22) }):Play()

	-- targhetta col nome: larga quanto la scritta
	local tag = Pix.box(group, UDim2.fromOffset(28, TOP - TAG_H / 2), UDim2.fromOffset(120, TAG_H), "gold", 5)
	local tagText = Pix.text(tag.content, UDim2.fromScale(0.5, 0.5), UDim2.new(1, -12, 0, TAG_TX), {
		anchor = Vector2.new(0.5, 0.5), max = TAG_TX,
		color = Pix.textOn("gold"), shadowColor = Pix.C.goldLight,
	})
	local TextService = game:GetService("TextService")
	tagText.main:GetPropertyChangedSignal("Text"):Connect(function()
		local w = TextService:GetTextSize(tagText.main.Text, TAG_TX, Pix.FONT, Vector2.new(2000, 200)).X
		tag.box.Size = UDim2.fromOffset(math.max(80, w + 30), TAG_H)
	end)

	return box, text.main, arrow, tagText.main, group
end

local function lockPlayer(locked)
	plr:SetAttribute("MovementLocked", locked)
	local char = plr.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.WalkSpeed = locked and 0 or 16 end
end

-- Nasconde TUTTE le altre interfacce (HUD, mobile, lista giocatori, chat,
-- zaino...) finche' sei nel menu, nell'intro e nel risveglio. Anche quelle
-- che altri script provano ad accendere nel frattempo. Poi rimette tutto
-- com'era.
local toggleGameGuis
do
	local StarterGui = game:GetService("StarterGui")
	local KEEP = { MainMenuGui = true, LoadingGui = true, WakeGui = true, StartMenu = true }
	local CORE = {
		Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health,
		Enum.CoreGuiType.EmotesMenu, Enum.CoreGuiType.Chat,
	}
	local hiding = false
	local hidden, conns, coreWas = {}, {}, {}

	local function watch(g)
		if not g:IsA("ScreenGui") or KEEP[g.Name] then return end
		if g.Enabled then
			g.Enabled = false
			hidden[g] = true
		end
		table.insert(conns, g:GetPropertyChangedSignal("Enabled"):Connect(function()
			if hiding and g.Enabled then
				g.Enabled = false
				hidden[g] = true
			end
		end))
	end

	toggleGameGuis = function(visible)
		if not visible then
			if hiding then return end
			hiding = true
			for _, g in ipairs(playerGui:GetChildren()) do watch(g) end
			table.insert(conns, playerGui.ChildAdded:Connect(function(g)
				task.defer(function()
					if hiding and g.Parent == playerGui then watch(g) end
				end)
			end))
			for _, t in ipairs(CORE) do
				local ok, was = pcall(function() return StarterGui:GetCoreGuiEnabled(t) end)
				if ok then
					coreWas[t] = was
					pcall(function() StarterGui:SetCoreGuiEnabled(t, false) end)
				end
			end
		else
			if not hiding then return end
			hiding = false
			for _, c in ipairs(conns) do c:Disconnect() end
			conns = {}
			for g in pairs(hidden) do
				if g.Parent then g.Enabled = true end
			end
			hidden = {}
			for t, was in pairs(coreWas) do
				pcall(function() StarterGui:SetCoreGuiEnabled(t, was) end)
			end
			coreWas = {}
		end
	end
end

-- ============================================================ GUI BASE

local gui = Instance.new("ScreenGui")
gui.Name = "MainMenuGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 99
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = playerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = C.bgTop
bg.BackgroundTransparency = 1
bg.BorderSizePixel = 0
bg.ZIndex = 1
bg.Parent = gui

local bgGradient = Instance.new("UIGradient")
bgGradient.Color = ColorSequence.new(C.bgTop, C.bgBottom)
bgGradient.Rotation = 90
bgGradient.Parent = bg

-- Il vecchio menu non serve piu'
task.spawn(function()
	local old = playerGui:WaitForChild("StartMenu", 5)
	if old then old.Enabled = false end
end)

-- ============================================================ SCHERMATA DEL TITOLO
-- Astropix vola dritto nel cielo notturno. Clic = camera sulla faccia + verso.

local Title = {}
local buttons = {}
local selectedIndex = 1
local menuActive = false
local hasSave = false
local titleState = "off"      -- off | title | starting | menu | leaving
local activate, refreshSelection

do
	local Lighting     = game:GetService("Lighting")
	local SoundService = game:GetService("SoundService")
	local Debris       = game:GetService("Debris")

	local CFG     = TITLE_CFG
	local UP      = Vector3.yAxis
	local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
	local SMOKE   = "rbxasset://textures/particles/smoke_main.dds"
	local BIND    = "TitleAstropixCam"

	local SFX_APPEAR = "rbxassetid://90715600940410"
	local SFX_BOOM   = "rbxasset://sounds/action_jump_land.mp3"
	local SFX_WHOOSH = "rbxasset://sounds/action_falling.mp3"

	-- Versi e ali di Astropix (gli stessi della cinematica del leggendario)
	local SFX_SCREAM = "rbxassetid://100023908449541"
	local SFX_ROARS  = { "rbxassetid://91628801149739", "rbxassetid://92787013376256", "rbxassetid://110243577981559" }
	local SFX_FLAP   = "rbxassetid://88388895007089"
	local FLAP_VOLUME       = 0.9    -- in volo normale (c'e' la musica sotto)
	local FLAP_VOLUME_CLOSE = 1.8    -- nel primo piano sulla faccia

	local AC1    = Color3.fromRGB(150, 110, 255)   -- viola
	local AC2    = Color3.fromRGB(110, 225, 255)   -- azzurro dei cristalli
	local AC3    = Color3.fromRGB(255, 170, 90)    -- arancio delle ali

	local CLOSE_IN, CLOSE_HOLD, CLOSE_OUT = 0.55, 2.3, 1.1

	-- ------------------------------------------------ utilita'
	local function clamp01(t) return math.clamp(t, 0, 1) end
	local function smooth(t) t = clamp01(t) return t * t * (3 - 2 * t) end
	local function easeOut(t) t = clamp01(t) return 1 - (1 - t) ^ 3 end
	local function rnd(a, b) return a + math.random() * (b - a) end

	local function tw(obj, time, props, style, dir)
		local t = TweenService:Create(obj, TweenInfo.new(time,
			style or Enum.EasingStyle.Sine, dir or Enum.EasingDirection.InOut), props)
		t:Play()
		return t
	end

	local function flat(v)
		v = Vector3.new(v.X, 0, v.Z)
		return v.Magnitude > 1e-3 and v.Unit or Vector3.new(0, 0, -1)
	end

	local MODEL_ROT = CFrame.Angles(math.rad(CFG.pitchOffset), math.rad(CFG.yawOffset), math.rad(CFG.rollOffset))
	local lastFlat  = Vector3.new(0, 0, -1)

	local function rotFromDir(dir, bank, maxPitch)
		local h = Vector3.new(dir.X, 0, dir.Z)
		if h.Magnitude > 1e-3 then lastFlat = h.Unit end
		local pitch = math.clamp(math.atan2(dir.Y, math.max(h.Magnitude, 1e-4)), -maxPitch, maxPitch)
		return CFrame.lookAt(Vector3.zero, lastFlat)
			* CFrame.Angles(pitch, 0, 0)
			* CFrame.Angles(0, 0, bank or 0)
			* MODEL_ROT
	end

	-- ------------------------------------------------ suoni
	local function playSfx(id, volume, pitch, fadeIn, hold, fadeOut)
		if not id or id == "" then return nil end
		local s = Instance.new("Sound")
		s.SoundId       = id
		s.Volume        = volume or 1
		s.PlaybackSpeed = pitch or 1
		s.Parent        = SoundService
		if fadeIn then
			s.Volume = 0
			s:Play()
			tw(s, fadeIn, { Volume = volume or 1 })
			task.delay(fadeIn + hold, function()
				if s.Parent then tw(s, fadeOut, { Volume = 0 }) end
			end)
			Debris:AddItem(s, fadeIn + hold + fadeOut + 0.1)
		else
			s:Play()
			Debris:AddItem(s, 12)
		end
		return s
	end

	local function whoosh(vol)
		playSfx(SFX_WHOOSH, vol or 0.8, 1.5, 0.12, 0.25, 0.6)
	end

	-- Uno dei tre ruggiti, mai lo stesso due volte di fila
	local lastRoarIdx = nil
	local function playRoar(vol)
		local i
		repeat i = math.random(1, #SFX_ROARS) until i ~= lastRoarIdx or #SFX_ROARS == 1
		lastRoarIdx = i
		return playSfx(SFX_ROARS[i], vol or 1.4, rnd(0.95, 1.05))
	end

	-- Abbassa la musica di MenuMusic durante il verso (equalizzatore:
	-- il volume lo gestisce MenuMusic e non va toccato)
	local duckEq = nil
	local function duckMusic()
		if not duckEq or not duckEq.Parent then
			local ps  = plr:FindFirstChild("PlayerScripts")
			local ms  = ps and ps:FindFirstChild("MenuMusic")
			local snd = ms and ms:FindFirstChildOfClass("Sound")
			if not snd then return end
			duckEq = Instance.new("EqualizerSoundEffect")
			duckEq.HighGain, duckEq.MidGain, duckEq.LowGain = 0, 0, 0
			duckEq.Parent = snd
		end
		tw(duckEq, 0.15, { HighGain = -18, MidGain = -14, LowGain = -10 })
		task.delay(1.8, function()
			if duckEq and duckEq.Parent then
				tw(duckEq, 1.4, { HighGain = 0, MidGain = 0, LowGain = 0 })
			end
		end)
	end

	-- ================================================ INTERFACCIA
	-- Stesso stile pixel art della squadra a schermo (PartyHUD): riquadri
	-- bordeaux, testo Arcade con l'ombra a pixel, oro per la selezione.

	local UI = {}   -- tutto quello che serve piu' sotto sta qui dentro

	do
		local PC    = Pix.C
		local SND   = CFG.sounds
		local TOUCH = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

		local function SC(x, y) return UDim2.fromScale(x, y) end
		UI.SC = SC

		local function new(class, props, parent)
			local o = Instance.new(class)
			for k, v in pairs(props) do o[k] = v end
			if parent then o.Parent = parent end
			return o
		end

		local function sound(id, vol, pitch)
			if id and id ~= "" then playSfx(id, vol or 0.5, pitch or 1) end
		end
		UI.sound = sound
		UI.SND = SND

		-- Suono al passaggio del mouse (sui telefoni niente, come prima)
		local function hoverSound(hit)
			if TOUCH then return end
			hit.MouseEnter:Connect(function() sound(SND.hover, 0.22, 1.15) end)
		end

		-- Titolo della finestra della stessa misura di quello del negozio (con
		-- le fasce alte uguali, ~70 pixel a 1080p, viene uguale anche la X)
		local function capTitle(w)
			for _, l in ipairs({ w.title.main, w.title.shadow }) do
				new("UITextSizeConstraint", { MaxTextSize = 28 }, l)
			end
		end

		-- Arcade non ha il ₽: quel simbolo si scrive col font dei simboli
		local RUB = '<font face="' .. Pix.SYMBOL.Name .. '">₽</font>'
		local function rich(t)
			t.main.RichText = true
			t.shadow.RichText = true
			return t
		end

		-- ------------------------------------------------ ombre, bande, flash
		UI.shades = new("Frame", {
			Size = SC(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 2,
		}, gui)
		for _, isTop in ipairs({ true, false }) do
			local f = new("Frame", {
				AnchorPoint = Vector2.new(0, isTop and 0 or 1), Position = SC(0, isTop and 0 or 1),
				Size = SC(1, isTop and 0.34 or 0.42), BackgroundColor3 = Color3.fromRGB(6, 4, 18),
				BorderSizePixel = 0, ZIndex = 2,
			}, UI.shades)
			new("UIGradient", {
				Rotation = isTop and 90 or -90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.2),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}, f)
		end

		local function bar(y)
			return new("Frame", {
				AnchorPoint = Vector2.new(0, y), Position = SC(0, y), Size = SC(1, 0),
				BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = 4,
			}, gui)
		end
		local barTop, barBot = bar(0), bar(1)

		function UI.letterbox(on, time)
			local size = on and SC(1, 0.1) or SC(1, 0)
			if time == 0 then
				barTop.Size, barBot.Size = size, size
				return
			end
			local dir = on and Enum.EasingDirection.Out or Enum.EasingDirection.In
			tw(barTop, time or 0.5, { Size = size }, Enum.EasingStyle.Quart, dir)
			tw(barBot, time or 0.5, { Size = size }, Enum.EasingStyle.Quart, dir)
		end

		local flashFrame = new("Frame", {
			Size = SC(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1,
			BorderSizePixel = 0, ZIndex = 6,
		}, gui)
		function UI.flash(peak, dur)
			flashFrame.BackgroundTransparency = 1 - peak
			tw(flashFrame, dur, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		end

		-- logo, pulsante e menu: sotto le bande nere (ZIndex 4), sopra le ombre (2)
		local canvas = Pix.canvas(gui, 3)

		-- ------------------------------------------------ LOGO
		UI.logo = new("CanvasGroup", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = SC(0.5, 0.2), Size = SC(0.7, 0.3),
			BackgroundTransparency = 1, GroupTransparency = 1, ZIndex = 3,
		}, canvas)
		UI.logoScale = new("UIScale", {}, UI.logo)
		UI.logoInner = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = SC(0.5, 0.5), Size = SC(0.9, 0.8),
			BackgroundTransparency = 1,
		}, UI.logo)

		if CFG.logoImage ~= "" then
			new("ImageLabel", {
				BackgroundTransparency = 1, Size = SC(1, 1), Image = CFG.logoImage,
				ScaleType = Enum.ScaleType.Fit, ZIndex = 4,
			}, UI.logoInner)
		else
			pixLogo(UI.logoInner, CFG.title, 3)
			-- riflesso che scorre
			local shineText = new("TextLabel", {
				Size = SC(1, 1), BackgroundTransparency = 1, Text = CFG.title, Font = Pix.FONT,
				TextScaled = true, TextColor3 = PC.white, ZIndex = 6,
			}, UI.logoInner)
			UI.shineGrad = new("UIGradient", {
				Rotation = 25, Offset = Vector2.new(-1, 0),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0,    1),
					NumberSequenceKeypoint.new(0.42, 1),
					NumberSequenceKeypoint.new(0.5,  0.15),
					NumberSequenceKeypoint.new(0.58, 1),
					NumberSequenceKeypoint.new(1,    1),
				}),
			}, shineText)
		end

		-- ------------------------------------------------ CLICK TO START
		UI.prompt = new("CanvasGroup", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = SC(0.5, 0.84), Size = SC(0.34, 0.1),
			BackgroundTransparency = 1, GroupTransparency = 1, ZIndex = 3,
		}, canvas)
		UI.promptScale = new("UIScale", {}, UI.prompt)

		-- piu' piccolo del CanvasGroup: il bordino e il pop non vengono tagliati
		local start = Pix.button(UI.prompt, SC(0.5, 0.5), SC(0.9, 0.72), {
			text = TOUCH and "TAP TO START" or "CLICK TO START", style = "gold", anchor = Vector2.new(0.5, 0.5),
		})
		Pix.ball(start.pb.content, SC(0.09, 0.5), SC(0.7, 0.7), 4)
		start.label.holder.Position = SC(0.56, 0.5)
		start.label.holder.Size = SC(0.74, 0.56)
		UI.promptHit = start.hit
		hoverSound(start.hit)

		-- ------------------------------------------------ MENU
		UI.panel = new("CanvasGroup", {
			AnchorPoint = Vector2.new(0, 0.5), Position = SC(0.03, 0.62), Size = SC(0.36, 0.5),
			BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, ZIndex = 3,
		}, canvas)

		-- a sinistra dei tasti resta posto per la freccetta
		UI.BTN_X = 0.1

		local ITEMS = {
			{ id = "new",      text = "New Game", style = "red"    },
			{ id = "continue", text = "Continue", style = "green"  },
			{ id = "afk",      text = "AFK",      style = "purple" },
			{ id = "credits",  text = "Credits",  style = "blue"   },
		}

		-- Freccetta dorata accanto al tasto selezionato: sta dentro il tasto,
		-- cosi' entra con lui e lo segue nel pop
		local pointer = Pix.arrow(UI.panel, UDim2.new(0, -20, 0.5, 0), 6, PC.gold, 8, 0)
		pointer.Visible = false
		TweenService:Create(pointer, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = UDim2.new(0, -26, 0.5, 0) }):Play()

		for i, item in ipairs(ITEMS) do
			local y = 0.07 + (i - 1) * 0.31
			-- manual: il bordino lo decide la selezione (mouse o tastiera)
			local btn = Pix.button(UI.panel, SC(-1, y), SC(0.78, 0.24), {
				text = item.text, style = item.style, z = 1 + i, max = 44, manual = true,
			})
			btn.root.Name = item.id

			-- Solo la scritta, a sinistra, niente icone
			local lbl = btn.label
			lbl.holder.AnchorPoint = Vector2.new(0, 0.5)
			lbl.holder.Position = SC(0.06, 0.5)
			lbl.holder.Size = SC(0.7, 0.5)
			lbl.main.TextXAlignment = Enum.TextXAlignment.Left
			lbl.shadow.TextXAlignment = Enum.TextXAlignment.Left

			-- targhetta dorata sull'angolo (squadra salvata)
			local sticker = Pix.box(btn.root, SC(0.84, 0), SC(0.34, 0.36), "gold", 6, Vector2.new(0.5, 0.5))
			sticker.box.Visible = false
			local stickerText = Pix.text(sticker.content, SC(0.5, 0.5), SC(0.92, 0.8), {
				anchor = Vector2.new(0.5, 0.5), color = Pix.textOn("gold"), shadowColor = PC.goldLight,
			})

			buttons[i] = {
				btn = btn, root = btn.root, scale = btn.scale, y = y,
				id = item.id, enabled = true, sticker = sticker, stickerText = stickerText,
			}

			btn.hit.MouseEnter:Connect(function()
				if not menuActive or not buttons[i].enabled then return end
				if selectedIndex ~= i then
					selectedIndex = i
					sound(SND.hover, 0.22, 1.15)
					refreshSelection()
				end
			end)
			btn.hit.Activated:Connect(function()
				if not menuActive then return end
				selectedIndex = i
				refreshSelection()
				activate()
			end)
		end

		-- Mette in fila i tasti visibili: con 4 si stringono per stare nel pannello
		local function layoutButtons()
			local vis = {}
			for _, b in ipairs(buttons) do
				if b.root.Visible then table.insert(vis, b) end
			end
			local n = math.max(1, #vis)
			local step = math.min(0.31, 0.96 / n)
			local h = math.min(0.24, step - 0.05)
			local top = (1 - ((n - 1) * step + h)) / 2
			for k, b in ipairs(vis) do
				b.y = top + (k - 1) * step
				b.root.Size = SC(0.78, h)
				if b.root.Position.X.Scale > -0.5 then   -- menu gia' aperto
					tw(b.root, 0.3, { Position = SC(UI.BTN_X, b.y) })
				else
					b.root.Position = SC(-1, b.y)
				end
			end
		end
		layoutButtons()

		-- Bordino dorato e pop sul selezionato, spento ("off") se non si puo' usare
		refreshSelection = function()
			for i, b in ipairs(buttons) do
				b.btn.setEnabled(b.enabled)
				b.btn.setHot(i == selectedIndex and b.enabled)
			end
			local sel = buttons[selectedIndex]
			pointer.Visible = sel ~= nil and sel.enabled and sel.root.Visible
			if pointer.Visible then pointer.Parent = sel.root end
		end

		function UI.moveSelection(dir)
			local before = selectedIndex
			for _ = 1, #buttons do
				selectedIndex = (selectedIndex - 1 + dir) % #buttons + 1
				if buttons[selectedIndex].enabled then break end
			end
			if selectedIndex ~= before then sound(SND.hover, 0.22, 1.15) end
			refreshSelection()
		end

		function Title.setSave(has, count)
			local b = buttons[2]
			b.enabled = has
			b.sticker.box.Visible = true
			local style = has and "gold" or "off"
			Pix.paint(b.sticker, style)
			b.stickerText.main.TextColor3 = Pix.textOn(style)
			b.stickerText.shadow.TextColor3 = has and PC.goldLight or PC.textShadow
			b.stickerText.main.Text = has and (count and count > 0 and (count .. " Bloxmon") or "Saved") or "No save"

			-- Partita gia' iniziata: NEW GAME sparisce e gli altri salgono
			local nb = buttons[1]
			nb.enabled = not has
			nb.root.Visible = not has
			layoutButtons()
			refreshSelection()
		end

		function Title.confirm()
			sound(SND.click, 0.5, 1.05)
			local b = buttons[selectedIndex]
			if not b then return end
			b.scale.Scale = 0.9
			tw(b.scale, 0.35, { Scale = 1.05 }, Enum.EasingStyle.Back)
		end

		function Title.denied()
			sound(SND.denied, 0.25, 1.8)
		end

		-- ------------------------------------------------ CREDITI (finestra pixel art)
		UI.creditsOpen = false
		local dim = new("TextButton", {
			Size = SC(1, 1), BackgroundColor3 = Color3.fromRGB(6, 8, 16), BackgroundTransparency = 1,
			AutoButtonColor = false, Text = "", Visible = false, ZIndex = 20,
		}, gui)
		local holder = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = SC(0.5, 0.53), Size = SC(0.56, 0.6),
			BackgroundTransparency = 1, ZIndex = 21,
		}, Pix.canvas(dim, 21))
		new("UIAspectRatioConstraint", {
			AspectRatio = 1.45, AspectType = Enum.AspectType.FitWithinMaxSize,
			DominantAxis = Enum.DominantAxis.Width,
		}, holder)
		local win = Pix.window(holder, SC(0.5, 0.5), SC(1, 1), "Credits", {
			accent = "blue", band = 0.11, close = true, anchor = Vector2.new(0.5, 0.5),
		})
		capTitle(win)
		local winPop = win.pop
		hoverSound(win.close.hit)

		local well = Pix.box(win.content, SC(0, 0), SC(1, 1), "slot", 1)
		local lines = new("Frame", {
			Position = SC(0.04, 0.04), Size = SC(0.92, 0.92), BackgroundTransparency = 1, ZIndex = 3,
		}, well.content)
		new("UIListLayout", {
			Padding = UDim.new(0.04, 0), SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}, lines)
		for i, text in ipairs(CFG.creditsLines) do
			local l = Pix.text(lines, nil, SC(1, i == 1 and 0.24 or 0.14), {
				text = text, color = i == 1 and PC.gold or PC.text,
			})
			l.holder.LayoutOrder = i
		end

		function UI.closeCredits()
			if not UI.creditsOpen then return end
			UI.creditsOpen = false
			tw(dim, 0.15, { BackgroundTransparency = 1 })
			local t = tw(winPop, 0.15, { Scale = 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			t.Completed:Connect(function()
				if not UI.creditsOpen then dim.Visible = false end
			end)
		end

		function Title.credits()
			if UI.creditsOpen then return end
			UI.creditsOpen = true
			dim.Visible = true
			dim.BackgroundTransparency = 1
			tw(dim, 0.2, { BackgroundTransparency = 0.35 })
			winPop.Scale = 0.85
			tw(winPop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end

		win.close.hit.Activated:Connect(function()
			sound(SND.click, 0.5, 1.05)
			UI.closeCredits()
		end)
		dim.Activated:Connect(UI.closeCredits)

		-- ------------------------------------------------ AFK (si guarda il cielo e arrivano soldi)
		UI.afkOn = false
		local afkRoot = Pix.canvas(gui, 10)
		afkRoot.Visible = false

		-- finestra al centro col conto alla rovescia
		local afkHolder = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = SC(0.5, 0.5), Size = SC(0.38, 0.3),
			BackgroundTransparency = 1, ZIndex = 11,
		}, afkRoot)
		new("UIAspectRatioConstraint", {
			AspectRatio = 1.9, AspectType = Enum.AspectType.FitWithinMaxSize,
			DominantAxis = Enum.DominantAxis.Width,
		}, afkHolder)
		local afkWin = Pix.window(afkHolder, SC(0.5, 0.5), SC(1, 1), "AFK", {
			accent = "purple", band = 0.23, close = true, anchor = Vector2.new(0.5, 0.5),
		})
		capTitle(afkWin)
		local afkPop = afkWin.pop
		hoverSound(afkWin.close.hit)
		afkWin.close.hit.Activated:Connect(function()
			sound(SND.click, 0.5, 1.05)
			Title.leaveAFK()
		end)

		local afkBig = Pix.text(afkWin.content, SC(0.05, 0.08), SC(0.9, 0.36), {
			text = "In 200 seconds", color = PC.gold,
		})
		Pix.text(afkWin.content, SC(0.05, 0.52), SC(0.9, 0.16), { text = "you get the reward" })
		local afkInfo = rich(Pix.text(afkWin.content, SC(0.05, 0.76), SC(0.9, 0.13), {
			text = "+50 " .. RUB .. " every 200 seconds", color = PC.textDim,
		}))

		-- soldi in basso a sinistra
		local money = Pix.box(afkRoot, SC(0.02, 0.965), SC(0.17, 0.065), "panel", 11, Vector2.new(0, 1))
		local moneyPop = new("UIScale", {}, money.box)
		local coin = Pix.box(money.content, SC(0.02, 0.5), SC(0.86, 0.86), "gold", 3, Vector2.new(0, 0.5))
		coin.box.SizeConstraint = Enum.SizeConstraint.RelativeYY
		Pix.text(coin.content, SC(0.5, 0.5), SC(1, 1), {
			text = "₽", font = Pix.SYMBOL, anchor = Vector2.new(0.5, 0.5),
			color = Pix.textOn("gold"), shadowColor = PC.goldLight,
		})
		local moneyL = Pix.text(money.content, SC(0.97, 0.5), SC(0.64, 0.6), {
			anchor = Vector2.new(1, 0.5), alignX = Enum.TextXAlignment.Right,
		})
		local function showMoney()
			local s = tostring(math.floor(tonumber(plr:GetAttribute("Money")) or 0))
			moneyL.main.Text = (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
		end
		plr:GetAttributeChangedSignal("Money"):Connect(showMoney)
		showMoney()

		-- "+50" che sale sopra i soldi
		local gainL = rich(Pix.text(afkRoot, SC(0.025, 0.9), SC(0.14, 0.05), {
			anchor = Vector2.new(0, 1), alignX = Enum.TextXAlignment.Left, color = PC.hpGreen, z = 12,
		}))
		gainL.main.TextTransparency = 1

		local afkNextAt, afkShownS = nil, nil
		RunService.Heartbeat:Connect(function()
			if not (afkRoot.Visible and afkNextAt) then return end
			local s = math.max(0, math.ceil(afkNextAt - os.clock()))
			if s ~= afkShownS then
				afkShownS = s
				afkBig.main.Text = "In " .. s .. (s == 1 and " second" or " seconds")
			end
		end)

		function UI.afkSetLeft(left, reward, interval)
			afkNextAt = os.clock() + (tonumber(left) or 0)
			if reward and interval then
				afkInfo.main.Text = "+" .. tostring(reward) .. " " .. RUB .. " every " .. tostring(interval) .. " seconds"
			end
		end

		function UI.afkNote(text)
			afkInfo.main.Text = text
		end

		function UI.afkReward(amount)
			gainL.main.Text = "+" .. tostring(amount) .. " " .. RUB
			gainL.holder.Position = SC(0.025, 0.9)
			gainL.main.TextTransparency = 0
			tw(gainL.holder, 1.8, { Position = SC(0.025, 0.82) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			tw(gainL.main, 1.8, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			moneyPop.Scale = 1.15
			tw(moneyPop, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
			sound(SND.click, 0.6, 1.4)
		end

		function UI.afkShow(on)
			afkRoot.Visible = on
			if on then
				afkNextAt, afkShownS = nil, nil
				showMoney()
				afkPop.Scale = 0.85
				tw(afkPop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
	end

	-- ------------------------------------------------ stato dell'interfaccia
	local logoShown, panelShown, promptOn, uiHidden = false, false, false, false

	local function applyUI(time)
		local hide = uiHidden
		tw(UI.logo,   time, { GroupTransparency = (logoShown and not hide) and 0 or 1 })
		tw(UI.panel,  time, { GroupTransparency = (panelShown and not hide) and 0 or 1 })
		tw(UI.prompt, time, { GroupTransparency = (promptOn and not hide) and 0 or 1 })
	end

	-- il pulsante di start respira
	task.spawn(function()
		while true do
			if promptOn and not uiHidden then
				tw(UI.promptScale, 0.7, { Scale = 1.05 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				task.wait(0.7)
				if promptOn then
					tw(UI.promptScale, 0.7, { Scale = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				end
				task.wait(0.7)
			else
				task.wait(0.2)
			end
		end
	end)

	-- riflesso sul logo
	task.spawn(function()
		while true do
			if UI.shineGrad and logoShown and not uiHidden then
				UI.shineGrad.Offset = Vector2.new(-1, 0)
				tw(UI.shineGrad, 1.1, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
				task.wait(4.5)
			else
				task.wait(0.5)
			end
		end
	end)

	local floating = false
	local function showLogo()
		logoShown = true
		UI.logoScale.Scale = 1.4
		tw(UI.logoScale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
		applyUI(0.3)
		if not floating then
			floating = true
			-- solo su e giu': la pixel art resta dritta
			TweenService:Create(UI.logoInner, TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Position = UI.SC(0.5, 0.46) }):Play()
		end
	end

	local shadeHolder = UI.shades
	local letterbox, flash = UI.letterbox, UI.flash

	-- ================================================ SCENA 3D

	local T = nil
	local sceneToken = 0

	local function part(shape, color, size, cf)
		local p = Instance.new("Part")
		p.Shape      = shape
		p.Anchored   = true
		p.CanCollide = false
		p.CanQuery   = false
		p.CanTouch   = false
		p.CastShadow = false
		p.Material   = Enum.Material.Neon
		p.Color      = color
		p.Size       = size
		p.CFrame     = cf
		p.Parent     = T and T.folder or Workspace
		return p
	end

	local function hidden(cf, size)
		local p = part(Enum.PartType.Block, WHITE, size, cf)
		p.Transparency = 1
		return p
	end

	local function emitter(parent, props)
		local e = Instance.new("ParticleEmitter")
		e.Texture        = SPARKLE
		e.LightEmission  = 1
		e.LightInfluence = 0
		e.Rate           = 0
		e.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0,    WHITE),
			ColorSequenceKeypoint.new(0.35, AC2),
			ColorSequenceKeypoint.new(1,    AC1),
		})
		for k, v in pairs(props or {}) do e[k] = v end
		e.Parent = parent
		return e
	end

	local function animate(dur, fn)
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < dur do
				fn((os.clock() - t0) / dur)
				RunService.RenderStepped:Wait()
			end
			fn(1)
		end)
	end

	local function starBurst(pos, scale)
		if not T then return end
		scale = scale or 1

		local anchor = hidden(CFrame.new(pos), Vector3.one)
		local core = part(Enum.PartType.Ball, WHITE, Vector3.one * 2, CFrame.new(pos))
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Shadows = AC2, 60, 8, false
		light.Parent = core

		emitter(anchor, {
			Lifetime    = NumberRange.new(0.8, 1.6),
			Speed       = NumberRange.new(25 * scale, 60 * scale),
			SpreadAngle = Vector2.new(180, 180),
			Drag        = 3,
			Size        = NumberSequence.new(1.6 * scale, 0),
		}):Emit(math.floor(90 * scale))

		emitter(anchor, {
			Lifetime     = NumberRange.new(2.5, 4),
			Speed        = NumberRange.new(2, 7),
			SpreadAngle  = Vector2.new(180, 180),
			Drag         = 1,
			Acceleration = Vector3.new(0, -2, 0),
			Size         = NumberSequence.new(0.55 * scale, 0),
		}):Emit(math.floor(60 * scale))

		animate(0.9, function(a)
			if not core.Parent then return end
			local e = easeOut(a)
			core.Size         = Vector3.one * (2 + e * 22 * scale)
			core.Transparency = e
			light.Brightness  = 8 * (1 - a)
		end)
		Debris:AddItem(core, 1)
		Debris:AddItem(anchor, 5)
	end

	-- Onda d'urto che segue un punto che si muove (la testa in volo)
	local function shockwave(getPos, delay, color, radius, dur)
		task.delay(delay, function()
			if not T then return end
			local bubble = part(Enum.PartType.Ball, color, Vector3.one * 2, CFrame.new(getPos()))
			bubble.Material = Enum.Material.ForceField
			animate(dur, function(a)
				if not bubble.Parent then return end
				local e = easeOut(a)
				bubble.CFrame       = CFrame.new(getPos())
				bubble.Size         = Vector3.one * (2 + e * radius)
				bubble.Transparency = e
			end)
			Debris:AddItem(bubble, dur + 0.1)
		end)
	end

	local function shootingStar(from, to, dur, size, color)
		if not T then return end
		local p = part(Enum.PartType.Ball, WHITE, Vector3.one * size, CFrame.new(from))

		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, size * 0.5, 0)
		a0.Parent   = p
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -size * 0.5, 0)
		a1.Parent   = p

		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.FaceCamera     = true
		tr.Lifetime       = 0.55
		tr.LightEmission  = 1
		tr.LightInfluence = 0
		tr.Color          = ColorSequence.new(WHITE, color)
		tr.Transparency   = NumberSequence.new(0, 1)
		tr.WidthScale     = NumberSequence.new(1, 0)
		tr.Parent         = p

		local t = tw(p, dur, { CFrame = CFrame.new(to) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		t.Completed:Connect(function()
			p.Transparency = 1
			tr.Enabled     = false
			Debris:AddItem(p, 0.8)
		end)
	end

	-- ------------------------------------------------ percorso: dritto, con un filo di ondeggio
	local function pathAt(t)
		return T.O
			+ T.F * (CFG.speed * t)
			+ T.R * (math.sin(t * 0.3) * 10 + math.sin(t * 0.13) * 4)
			+ UP  * (math.sin(t * 0.5) * 3 + math.sin(t * 0.23) * 2)
	end

	local function pathTangent(t)
		local d = pathAt(t + 0.05) - pathAt(t - 0.05)
		return d.Magnitude > 1e-4 and d.Unit or T.F
	end

	local function randomShootingStar(scale)
		local s = T
		if not s then return end
		local base = pathAt(os.clock() - s.t0)
		local a    = math.rad(rnd(0, 100))
		local c    = -s.F * math.cos(a) + s.R * math.sin(a)
		local side = c:Cross(UP).Unit
		local from = base + c * rnd(350, 500) + side * rnd(-250, 250) + UP * rnd(150, 250)
		local dir  = (side * (math.random() < 0.5 and 1 or -1) - UP * rnd(0.3, 0.6)).Unit
		shootingStar(from, from + dir * rnd(150, 230), rnd(0.7, 1.1), (scale or 1) * rnd(1.4, 2.2),
			math.random() < 0.5 and AC1 or AC2)
	end

	local function headPos()
		local s = T
		local fwd = s.fwd or s.F
		local p
		if s.m and s.m.head and s.m.head.Parent then
			p = s.m.head.TransformedWorldCFrame.Position + fwd * (CFG.size * 0.06)
		else
			p = (s.pos or s.O) + fwd * (CFG.size * 0.4) + UP * (CFG.size * 0.1)
		end
		s.lastHead = p
		return p
	end

	local function overCreature(screenPos)
		local s = T
		if not (s and s.pos and s.visible) then return false end
		local sp, onScreen = camera:WorldToViewportPoint(s.pos)
		if not onScreen or sp.Z <= 0 then return false end
		local px = (CFG.size * 0.55 / sp.Z) * (camera.ViewportSize.Y * 0.5)
			/ math.tan(math.rad(camera.FieldOfView * 0.5))
		return (Vector2.new(sp.X, sp.Y) - screenPos).Magnitude < px
	end

	-- ------------------------------------------------ mondo
	local function cloudProps(lifeMin, lifeMax)
		return {
			Texture        = SMOKE,
			Shape          = Enum.ParticleEmitterShape.Box,
			ShapeStyle     = Enum.ParticleEmitterShapeStyle.Volume,
			Lifetime       = NumberRange.new(lifeMin, lifeMax),
			Speed          = NumberRange.new(0, 0),
			Rotation       = NumberRange.new(0, 360),
			RotSpeed       = NumberRange.new(-4, 4),
			LightEmission  = 0.05,
			LightInfluence = 0.3,
			Size           = NumberSequence.new(55, 90),
			Transparency   = NumberSequence.new({
				NumberSequenceKeypoint.new(0,    1),
				NumberSequenceKeypoint.new(0.12, 0.72),
				NumberSequenceKeypoint.new(0.85, 0.76),
				NumberSequenceKeypoint.new(1,    1),
			}),
			Color = ColorSequence.new(Color3.fromRGB(205, 195, 250), Color3.fromRGB(125, 120, 200)),
		}
	end

	local function buildWorld()
		local s = T
		local O, F, R = s.O, s.F, s.R
		local life = 840 / CFG.speed

		-- Cielo stellato che viaggia con lui
		s.sky = hidden(CFrame.new(O + UP * 320), Vector3.new(1600, 380, 1600))
		s.stars = emitter(s.sky, {
			Shape        = Enum.ParticleEmitterShape.Box,
			ShapeStyle   = Enum.ParticleEmitterShapeStyle.Volume,
			LockedToPart = true,
			Rate         = 150,
			Lifetime     = NumberRange.new(4, 7),
			Speed        = NumberRange.new(0, 0),
			Rotation     = NumberRange.new(0, 360),
			RotSpeed     = NumberRange.new(-40, 40),
			Size         = NumberSequence.new({
				NumberSequenceKeypoint.new(0,   0),
				NumberSequenceKeypoint.new(0.5, 2.6),
				NumberSequenceKeypoint.new(1,   0),
			}),
			Color = ColorSequence.new(WHITE, AC2),
		})
		s.stars:Emit(500)

		-- Mare di nuvole: resta fermo nel mondo, lui ci vola sopra
		s.clouds = hidden(CFrame.new(O - UP * 55 + F * 420), Vector3.new(1000, 10, 80))
		local cp = cloudProps(life * 0.95, life)
		cp.Rate = 14
		emitter(s.clouds, cp)

		for k = 0, 8 do
			local d = 420 - k * 105
			local l = (d + 420) / CFG.speed
			local b = hidden(CFrame.new(O - UP * 55 + F * d), Vector3.new(1000, 10, 105))
			emitter(b, cloudProps(l * 0.9, l)):Emit(20)
			Debris:AddItem(b, l + 1)
		end

		-- Nuvolette alla sua altezza: passano vicino e danno la velocita'
		local wl = 600 / CFG.speed
		s.wisps = hidden(CFrame.new(O + F * 300 - UP * 4), Vector3.new(300, 60, 40))
		local wp = cloudProps(wl * 0.95, wl)
		wp.Rate = 1.2
		wp.Size = NumberSequence.new(22, 38)
		wp.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0,    1),
			NumberSequenceKeypoint.new(0.15, 0.86),
			NumberSequenceKeypoint.new(0.85, 0.88),
			NumberSequenceKeypoint.new(1,    1),
		})
		emitter(s.wisps, wp)

		-- Polvere di stelle che resta indietro mentre vola
		s.dustBox = hidden(CFrame.new(O + F * 60), Vector3.new(160, 90, 40))
		s.dust = emitter(s.dustBox, {
			Shape      = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Rate       = 35,
			Lifetime   = NumberRange.new(1.6, 2.4),
			Speed      = NumberRange.new(0, 0),
			Size       = NumberSequence.new({
				NumberSequenceKeypoint.new(0,   0),
				NumberSequenceKeypoint.new(0.3, 0.7),
				NumberSequenceKeypoint.new(1,   0),
			}),
		})

		-- Aurora: nastri curvi nel cielo, viaggiano con lui
		s.aurora = hidden(CFrame.new(O), Vector3.one)
		s.beams = {}
		for i, ang in ipairs({ 10, 55, 100 }) do
			local a    = math.rad(ang)
			local c    = -F * math.cos(a) + R * math.sin(a)
			local side = c:Cross(UP).Unit
			local p0 = O + c * 650 - side * 420 + UP * (150 + i * 25)
			local p1 = O + c * 620 + side * 420 + UP * (180 + i * 15)

			local a0 = Instance.new("Attachment")
			a0.Parent = s.aurora
			a0.WorldCFrame = CFrame.fromMatrix(p0, UP, side)
			local a1 = Instance.new("Attachment")
			a1.Parent = s.aurora
			a1.WorldCFrame = CFrame.fromMatrix(p1, UP, side)

			local b = Instance.new("Beam")
			b.Attachment0, b.Attachment1 = a0, a1
			b.CurveSize0     = 110 - i * 25
			b.CurveSize1     = 70 + i * 10
			b.Width0         = 90 + i * 10
			b.Width1         = 110
			b.Segments       = 40
			b.FaceCamera     = true
			b.Texture        = SMOKE
			b.TextureMode    = Enum.TextureMode.Wrap
			b.TextureLength  = 180
			b.TextureSpeed   = 0.06 * i
			b.LightEmission  = 1
			b.LightInfluence = 0
			b.Brightness     = 1.4
			b.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0,   AC2),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 255, 205)),
				ColorSequenceKeypoint.new(1,   AC1),
			})
			b.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0,    1),
				NumberSequenceKeypoint.new(0.25, 0.6),
				NumberSequenceKeypoint.new(0.5,  0.5 + i * 0.05),
				NumberSequenceKeypoint.new(0.75, 0.65),
				NumberSequenceKeypoint.new(1,    1),
			})
			b.Parent = s.aurora
			table.insert(s.beams, b)
		end

		-- Luci di scena: una davanti dal lato camera, una azzurra dietro
		s.key = hidden(CFrame.new(O), Vector3.one)
		local key = Instance.new("PointLight")
		key.Color, key.Range, key.Brightness, key.Shadows = Color3.fromRGB(225, 215, 255), 70, 1.6, false
		key.Parent = s.key

		s.rim = hidden(CFrame.new(O), Vector3.one)
		local rim = Instance.new("PointLight")
		rim.Color, rim.Range, rim.Brightness, rim.Shadows = AC2, 45, 2, false
		rim.Parent = s.rim

		-- Colori, bagliore e profondita' di campo
		s.old = { clock = Lighting.ClockTime, outdoor = Lighting.OutdoorAmbient }

		s.cc = Instance.new("ColorCorrectionEffect")
		s.cc.Name       = "TitleCC"
		s.cc.Contrast   = 0.12
		s.cc.Saturation = 0.08
		s.cc.TintColor  = Color3.fromRGB(218, 212, 255)
		s.cc.Parent     = Lighting

		s.bloom = Instance.new("BloomEffect")
		s.bloom.Name      = "TitleBloom"
		s.bloom.Intensity = 0.6
		s.bloom.Size      = 36
		s.bloom.Threshold = 0.85
		s.bloom.Parent    = Lighting

		s.dof = Instance.new("DepthOfFieldEffect")
		s.dof.Name           = "TitleDOF"
		s.dof.FarIntensity   = 0.22
		s.dof.NearIntensity  = 0
		s.dof.InFocusRadius  = 22
		s.dof.FocusDistance  = 30
		s.dof.Parent         = Lighting

		if CFG.night then
			Lighting.ClockTime      = CFG.clock
			Lighting.OutdoorAmbient = Color3.fromRGB(95, 85, 140)
		end
	end

	local function restoreWorld(s)
		if s.cc then s.cc:Destroy() end
		if s.bloom then s.bloom:Destroy() end
		if s.dof then s.dof:Destroy() end
		if CFG.night and s.old then
			Lighting.ClockTime      = s.old.clock
			Lighting.OutdoorAmbient = s.old.outdoor
		end
	end

	-- ------------------------------------------------ Astropix
	local function buildModel(template)
		local model = template:Clone()
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
		end

		local bbCF, bbSize = model:GetBoundingBox()
		model.WorldPivot = CFrame.new(bbCF.Position)

		local maxDim = math.max(bbSize.X, bbSize.Y, bbSize.Z)
		if CFG.size > 0 and maxDim > 0.1 then
			pcall(function() model:ScaleTo(model:GetScale() * CFG.size / maxDim) end)
			bbCF, bbSize = model:GetBoundingBox()
		end

		local parts = {}
		local head = nil
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored   = true
				d.CanCollide = false
				d.CanQuery   = false
				d.CanTouch   = false
				d.LocalTransparencyModifier = 1
				table.insert(parts, d)
			elseif d:IsA("Bone") and d.Name == "Head" then
				head = d
			end
		end
		if model.PrimaryPart and not model.PrimaryPart:IsA("MeshPart") then
			model.PrimaryPart.Transparency = 1
		end

		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			hum.HealthDisplayType   = Enum.HumanoidHealthDisplayType.AlwaysOff
		end

		local vol = Instance.new("Part")
		vol.Name         = "AuraVolume"
		vol.Transparency = 1
		vol.Anchored     = true
		vol.CanCollide   = false
		vol.CanQuery     = false
		vol.CanTouch     = false
		vol.Size         = bbSize * 0.7
		vol.CFrame       = model:GetPivot()
		vol.Parent       = model

		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Shadows = AC1, 0, 45, false
		light.Parent = vol

		local dust = emitter(vol, {
			Shape        = Enum.ParticleEmitterShape.Box,
			ShapeStyle   = Enum.ParticleEmitterShapeStyle.Volume,
			Lifetime     = NumberRange.new(1.2, 2.4),
			Speed        = NumberRange.new(0.5, 3),
			SpreadAngle  = Vector2.new(180, 180),
			Drag         = 1.5,
			Size         = NumberSequence.new({
				NumberSequenceKeypoint.new(0,   0),
				NumberSequenceKeypoint.new(0.2, 0.8),
				NumberSequenceKeypoint.new(1,   0),
			}),
			Transparency = NumberSequence.new(0.05, 1),
		})

		local burst = emitter(vol, {
			LockedToPart = true,
			Lifetime     = NumberRange.new(0.9, 1.8),
			Speed        = NumberRange.new(30, 75),
			SpreadAngle  = Vector2.new(180, 180),
			Drag         = 2.5,
			Size         = NumberSequence.new(1.8, 0),
		})

		local hl = Instance.new("Highlight")
		hl.Adornee             = model
		hl.FillColor           = AC1
		hl.OutlineColor        = AC2
		hl.FillTransparency    = 1
		hl.OutlineTransparency = 1
		hl.DepthMode           = Enum.HighlightDepthMode.Occluded
		hl.Parent              = model

		-- Scie di luce dalle ossa di ali e code
		local trails = {}
		local host = model:FindFirstChildWhichIsA("MeshPart", true) or vol

		local function ribbon(a0, a1, life, cA, cB, alpha)
			local t = Instance.new("Trail")
			t.Attachment0, t.Attachment1 = a0, a1
			t.Lifetime       = life
			t.MinLength      = 0.05
			t.LightEmission  = 1
			t.LightInfluence = 0
			t.Color          = ColorSequence.new(cA, cB)
			t.Transparency   = NumberSequence.new(alpha, 1)
			t.WidthScale     = NumberSequence.new(1, 0.2)
			t.Enabled        = false
			t.Parent         = host
			table.insert(trails, t)
		end

		local function boneRibbon(n0, n1, life, cA, cB, alpha)
			local a0 = model:FindFirstChild(n0, true)
			local a1 = model:FindFirstChild(n1, true)
			if a0 and a1 and a0:IsA("Attachment") and a1:IsA("Attachment") then
				ribbon(a0, a1, life, cA, cB, alpha)
			end
		end

		boneRibbon("WingL2", "WingL3", 0.25, AC3, AC1, 0.55)
		boneRibbon("WingR2", "WingR3", 0.25, AC3, AC1, 0.55)
		boneRibbon("TailA4", "TailA5", 0.5,  AC2, AC1, 0.35)
		boneRibbon("TailB4", "TailB5", 0.5,  AC2, AC1, 0.35)
		boneRibbon("TailC3", "TailC4", 0.5,  AC2, AC1, 0.35)

		if #trails == 0 then
			local w  = math.max(bbSize.X, bbSize.Z) * 0.5
			local th = math.max(bbSize.Y * 0.06, 0.25)
			for _, sgn in ipairs({ -1, 1 }) do
				local a0 = Instance.new("Attachment")
				a0.Position = Vector3.new(w * sgn, -th, 0)
				a0.Parent   = vol
				local a1 = Instance.new("Attachment")
				a1.Position = Vector3.new(w * sgn, th, 0)
				a1.Parent   = vol
				ribbon(a0, a1, 0.6, AC2, AC1, 0.1)
			end
		end

		model.Parent = T.folder

		-- Animazioni
		local roar
		local ctrl = hum or model:FindFirstChildOfClass("AnimationController")
		if not ctrl and model:FindFirstChildWhichIsA("Bone", true) then
			ctrl = Instance.new("AnimationController")
			ctrl.Parent = model
		end
		if ctrl then
			local animator = ctrl:FindFirstChildOfClass("Animator")
			if not animator then
				animator = Instance.new("Animator")
				animator.Parent = ctrl
			end
			local function load(id, looped, priority)
				if id == "" then return nil end
				local anim = Instance.new("Animation")
				anim.AnimationId = id
				local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
				if not ok or not track then
					warn("[MainMenu] Animazione non caricabile: " .. id)
					return nil
				end
				track.Looped   = looped
				track.Priority = priority
				return track
			end
			local fly = load(CFG.flyAnim, true, Enum.AnimationPriority.Movement)
			if fly then fly:Play(0.3) end
			roar = load(CFG.roarAnim, false, Enum.AnimationPriority.Action)
		end

		return {
			model  = model,
			parts  = parts,
			head   = head,
			light  = light,
			dust   = dust,
			burst  = burst,
			hl     = hl,
			trails = trails,
			roar   = roar,
		}
	end

	local function fadeParts(list, from, to, dur)
		animate(dur, function(a)
			local v = from + (to - from) * a
			for _, p in ipairs(list) do
				if p.Parent then p.LocalTransparencyModifier = v end
			end
		end)
	end

	-- ------------------------------------------------ ogni frame
	local function render(dt)
		local s = T
		if not s then return end
		local now = os.clock()
		local t   = now - s.t0

		local base = pathAt(t)
		local tan  = pathTangent(t)
		s.fwd = tan

		-- rollio: si inclina dalla parte dove sta curvando
		local acc   = (pathAt(t + 0.1) - base * 2 + pathAt(t - 0.1)) / 0.01
		local bankT = math.clamp(-acc:Dot(s.R) * 0.25, -0.5, 0.5)
		s.bank += (bankT - s.bank) * (1 - math.exp(-3 * dt))

		-- il cielo viaggia con lui
		s.sky.CFrame     = CFrame.new(base + UP * 320)
		s.aurora.CFrame  = CFrame.new(base)
		s.clouds.CFrame  = CFrame.new(base - UP * 55 + s.F * 420)
		s.wisps.CFrame   = CFrame.new(base + s.F * 300 - UP * 4)
		s.dustBox.CFrame = CFrame.new(base + s.F * 60)
		s.key.CFrame     = CFrame.new(base + s.F * 14 - s.R * 10 + UP * 10)
		s.rim.CFrame     = CFrame.new(base - s.F * 10 + s.R * 12 + UP * 6)

		-- Astropix
		local m = s.m
		if m and m.model.Parent then
			local rot = rotFromDir(tan, s.bank, math.rad(25))
			s.modelRot = s.modelRot and s.modelRot:Lerp(rot, 1 - math.exp(-6 * dt)) or rot
			local wing = math.sin(t * 5.5)
			s.pos = base + UP * wing * 0.35
			m.model:PivotTo(CFrame.new(s.pos) * s.modelRot)

			-- Battito d'ali a ogni colpo verso il basso (quando si vede)
			if s.visible and s.prevWing and s.prevWing > 0 and wing <= 0 then
				playSfx(SFX_FLAP, s.closeT0 and FLAP_VOLUME_CLOSE or FLAP_VOLUME, rnd(0.92, 1.08))
			end
			s.prevWing = wing

			if s.visible then
				local over = UserInputService.MouseEnabled
					and overCreature(UserInputService:GetMouseLocation())
				local k = 1 - math.exp(-8 * dt)
				local outGoal  = (s.closeT0 and 0) or (over and 0.05) or 0.45
				local fillGoal = (s.closeT0 and 0.8) or (over and 0.82) or 0.9
				m.hl.OutlineTransparency += (outGoal - m.hl.OutlineTransparency) * k
				m.hl.FillTransparency    += (fillGoal - m.hl.FillTransparency) * k
			end
		end

		-- camera: gira piano attorno a lui mentre vola
		local th   = math.rad(-58 + 32 * math.sin(t * 0.11))
		local dist = 31 + 3 * math.sin(t * 0.07)
		local h    = 3.5 + 2.5 * math.sin(t * 0.16)
		local off  = (s.F * math.cos(th) + s.R * math.sin(th)) * dist + UP * h
		s.framing += (s.framingGoal - s.framing) * (1 - math.exp(-2 * dt))

		local camCF = CFrame.lookAt(base + off, base + UP) * CFrame.Angles(0, s.framing, 0)
		local fov   = 58
		local focus = dist

		-- primo piano sulla faccia
		if s.closeT0 then
			local e  = now - s.closeT0
			local wc = 0
			if e < CLOSE_IN then
				wc = smooth(e / CLOSE_IN)
			elseif e < CLOSE_IN + CLOSE_HOLD then
				wc = 1
			elseif e < CLOSE_IN + CLOSE_HOLD + CLOSE_OUT then
				wc = 1 - smooth((e - CLOSE_IN - CLOSE_HOLD) / CLOSE_OUT)
			else
				s.closeT0 = nil
			end

			if s.closeT0 and m then
				local hp   = headPos()
				local side = tan:Cross(UP)
				local push = clamp01(e / (CLOSE_IN + CLOSE_HOLD))
				local cp   = hp + tan * (9.5 - 2.2 * push) - side * 2.6 + UP * 1.1
				camCF = camCF:Lerp(CFrame.lookAt(cp, hp), wc)
				fov   = fov + (40 - fov) * wc
				focus = focus + ((cp - hp).Magnitude - focus) * wc
			end
		end

		s.dof.FocusDistance = focus

		s.fovKick += (0 - s.fovKick) * (1 - math.exp(-3 * dt))
		s.shake = math.max(0, s.shake - dt * 2)
		local amp = 0.05 + s.shake
		local n = now * 12
		local shakeCF = CFrame.Angles(
			math.rad(math.noise(n, 0.31, 0) * amp),
			math.rad(math.noise(0.73, n, 0) * amp),
			math.rad(math.noise(0, 1.17, n) * amp * 0.5))

		camera.CameraType  = Enum.CameraType.Scriptable
		camera.CFrame      = camCF * shakeCF
		camera.FieldOfView = fov + s.fovKick
	end

	-- ------------------------------------------------ entrata: cometa, esplosione, eccolo
	local function entrance(onReady)
		local s, m = T, T.m
		local travel = 1.4
		local tHit   = (os.clock() - s.t0) + travel
		local to     = pathAt(tHit)
		local from   = to + s.F * 320 + UP * 150 - s.R * 140

		whoosh(0.9)
		shootingStar(from, to, travel, 3.4, AC2)

		task.delay(travel, function()
			if T ~= s then return end
			starBurst(to, 1.2)
			flash(0.45, 0.7)
			s.shake = 1.4
			playSfx(SFX_APPEAR, 1.1, 0.65)

			fadeParts(m.parts, 1, 0, 0.35)
			for _, tr in ipairs(m.trails) do tr.Enabled = true end
			m.dust.Rate = 16
			tw(m.light, 0.6, { Brightness = 2.5 })
			s.visible = true
			onReady()
		end)
	end

	local function sceneOrigin()
		local p = Workspace:FindFirstChild(CFG.scenePart, true)
		if p and p:IsA("BasePart") then
			return p.Position, flat(p.CFrame.LookVector)
		end

		local hrp
		local t0 = os.clock()
		repeat
			local c = plr.Character
			hrp = c and c:FindFirstChild("HumanoidRootPart")
			if not hrp then task.wait(0.1) end
		until hrp or os.clock() - t0 > 3

		if hrp then
			return hrp.Position + UP * CFG.altitude, flat(hrp.CFrame.LookVector)
		end
		return Vector3.new(0, CFG.altitude + 100, 0), Vector3.new(0, 0, -1)
	end

	local function startScene(onReady)
		if T then Title.stopScene() end
		sceneToken += 1
		local token = sceneToken

		local O, F = sceneOrigin()
		if token ~= sceneToken then return end

		T = {
			O = O, F = F, R = F:Cross(UP), t0 = os.clock(),
			bank = 0, shake = 0, fovKick = 0, framing = 0, framingGoal = 0,
		}
		T.folder = Instance.new("Folder")
		T.folder.Name   = "TitleScene"
		T.folder.Parent = Workspace
		buildWorld()
		shadeHolder.Visible = true

		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function(dt)
			local ok, err = pcall(render, dt)
			if not ok and T and not T.warned then
				T.warned = true
				warn("[MainMenu] Titolo: " .. tostring(err))
			end
		end)

		-- stelle cadenti di sottofondo
		task.spawn(function()
			local mine = T
			while T == mine do
				task.wait(rnd(2.5, 6))
				if T == mine then randomShootingStar(1) end
			end
		end)

		local folder   = ReplicatedStorage:WaitForChild("LegendaryModels", 20)
		local template = folder and folder:WaitForChild(CFG.model, 20)
		if token ~= sceneToken or not T then return end
		if not template then
			warn("[MainMenu] '" .. CFG.model .. "' non trovato in ReplicatedStorage.LegendaryModels.")
			onReady()
			return
		end

		T.m = buildModel(template)
		entrance(onReady)
	end

	function Title.stopScene()
		sceneToken += 1
		local s = T
		T = nil
		pcall(function() RunService:UnbindFromRenderStep(BIND) end)
		letterbox(false, 0)
		shadeHolder.Visible = false
		if not s then return end
		if s.folder then s.folder:Destroy() end
		restoreWorld(s)
	end

	function Title.busy()
		return T ~= nil and T.closeT0 ~= nil
	end

	-- ------------------------------------------------ IL VERSO: camera sulla faccia
	function Title.roar()
		local s = T
		if not (s and s.m and s.visible) or s.closeT0 then return false end
		local m = s.m
		s.closeT0 = os.clock()

		whoosh(0.8)
		letterbox(true, 0.45)
		uiHidden = true
		applyUI(0.25)

		task.delay(0.3, function()
			if T ~= s then return end
			if m.roar then m.roar:Play(0.1) end
			duckMusic()
		end)

		task.delay(0.85, function()
			if T ~= s then return end
			if CFG.crySound ~= "" then playSfx(CFG.crySound, 1.3, 1) end
			playSfx(SFX_SCREAM, 1.5, 1)   -- l'urlo, solo quando lo clicchi
			playSfx(SFX_BOOM, 1.5, 0.3)
			playSfx(SFX_APPEAR, 1.1, 0.55)

			s.shake   = 2.4
			s.fovKick = 10
			flash(0.5, 0.8)

			local getHead = function()
				return (T == s and headPos()) or s.lastHead or s.O
			end
			shockwave(getHead, 0,    AC2,  18, 0.8)
			shockwave(getHead, 0.12, AC1,  28, 1.0)
			shockwave(getHead, 0.26, WHITE, 40, 1.2)
			m.burst:Emit(120)

			s.bloom.Intensity = 2.2
			tw(s.bloom, 1.6, { Intensity = 0.6 })
			s.cc.Brightness = 0.12
			tw(s.cc, 1.2, { Brightness = 0 })
			for _, b in ipairs(s.beams) do
				b.Brightness = 4
				tw(b, 2, { Brightness = 1.4 })
			end
			m.light.Brightness = 7
			tw(m.light, 1.2, { Brightness = 2.5 })

			s.dust.Rate = 140
			task.delay(1, function() if s.dust.Parent then s.dust.Rate = 35 end end)

			for i = 1, 5 do
				task.delay(0.1 + i * 0.12, function()
					if T == s then randomShootingStar(1.3) end
				end)
			end
		end)

		task.delay(CLOSE_IN + CLOSE_HOLD, function()
			if T ~= s then return end
			letterbox(false, 0.6)
			if titleState == "title" or titleState == "starting" or titleState == "menu" then
				uiHidden = false
				applyUI(0.6)
			end
		end)

		return true
	end

	-- ------------------------------------------------ flusso del titolo
	function Title.showMenu()
		titleState = "menu"
		promptOn   = false
		logoShown  = true
		panelShown = true
		UI.panel.Visible = true
		for i, b in ipairs(buttons) do
			b.root.Position = UI.SC(-1, b.y)
			task.delay(0.1 + (i - 1) * 0.09, function()
				tw(b.root, 0.5, { Position = UI.SC(UI.BTN_X, b.y) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			end)
		end
		applyUI(0.4)
		if T then T.framingGoal = math.rad(14) end
		menuActive = true
		refreshSelection()
	end

	-- AFK: menu e logo spariscono, resta il cielo. I soldi li da' il server
	-- (AFKRewards), qui c'e' solo il conto alla rovescia.
	local afkRemote = nil
	task.spawn(function()
		afkRemote = ReplicatedStorage:WaitForChild("AFKRemote", 30)
		if not afkRemote then return end
		afkRemote.OnClientEvent:Connect(function(kind, data)
			if not UI.afkOn then return end
			data = type(data) == "table" and data or {}
			if kind == "state" then
				UI.afkSetLeft(data.left, data.reward, data.interval)
			elseif kind == "reward" then
				UI.afkSetLeft(data.left)
				UI.afkReward(data.amount or 0)
			elseif kind == "stopped" then
				Title.leaveAFK(true)
			elseif kind == "hop" then
				UI.afkNote("Changing server, you stay AFK...")
			end
		end)
	end)

	function Title.afk()
		if UI.afkOn or titleState ~= "menu" then return end
		UI.afkOn   = true
		menuActive = false
		logoShown, panelShown = false, false
		applyUI(0.4)
		if T then T.framingGoal = 0 end
		UI.afkShow(true)
		if afkRemote then afkRemote:FireServer("start") end
	end

	function Title.leaveAFK(fromServer)
		if not UI.afkOn then return end
		UI.afkOn = false
		if afkRemote and not fromServer then afkRemote:FireServer("stop") end
		UI.afkShow(false)
		if titleState ~= "menu" then return end
		logoShown, panelShown = true, true
		applyUI(0.4)
		if T then T.framingGoal = math.rad(14) end
		menuActive = true
		refreshSelection()
	end

	-- Arrivato da un cambio server dell'AFK: dritto in AFK, senza clic
	task.spawn(function()
		local ok, td = pcall(function()
			return game:GetService("TeleportService"):GetLocalPlayerTeleportData()
		end)
		if not (ok and type(td) == "table" and td.afk == true) then return end
		local t0 = os.clock()
		while not (titleState == "title" and promptOn and afkRemote) do
			if os.clock() - t0 > 90 then return end
			task.wait(0.2)
		end
		Title.showMenu()
		Title.afk()
	end)

	-- Un clic solo: il verso parte una volta, il pulsante sparisce e dal
	-- menu non si puo' piu' far ruggire
	local function pressStart()
		if titleState ~= "title" then return end
		titleState = "starting"
		promptOn   = false
		UI.sound(UI.SND.click, 0.5, 1.05)
		tw(UI.promptScale, 0.1, { Scale = 0.9 })
		applyUI(0.25)

		local roared = Title.roar()
		task.delay(roared and (CLOSE_IN + CLOSE_HOLD) or 0.3, function()
			if titleState == "starting" then Title.showMenu() end
		end)
	end

	UI.promptHit.Activated:Connect(pressStart)

	function Title.open()
		titleState = "title"
		menuActive = false
		logoShown, panelShown, promptOn, uiHidden = false, false, false, false
		UI.panel.Visible = false
		UI.promptScale.Scale = 1
		applyUI(0)

		task.spawn(startScene, function()
			if titleState ~= "title" then return end
			showLogo()
			flash(0.25, 0.5)
			task.delay(0.8, function()
				if titleState == "title" then
					promptOn = true
					applyUI(0.4)
				end
			end)
		end)
	end

	function Title.leave(time)
		UI.closeCredits()
		titleState = "leaving"
		menuActive = false
		promptOn   = false
		uiHidden   = true
		applyUI(time or 0.4)
	end

	-- ------------------------------------------------ tasti
	local NUM = {
		[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4,
		[Enum.KeyCode.KeypadOne] = 1, [Enum.KeyCode.KeypadTwo] = 2, [Enum.KeyCode.KeypadThree] = 3,
		[Enum.KeyCode.KeypadFour] = 4,
	}

	UserInputService.InputBegan:Connect(function(input, processed)
		local ty, key = input.UserInputType, input.KeyCode
		local click = ty == Enum.UserInputType.MouseButton1 or ty == Enum.UserInputType.Touch

		if UI.afkOn then
			if key == Enum.KeyCode.Escape or key == Enum.KeyCode.Backspace or key == Enum.KeyCode.ButtonB then
				Title.leaveAFK()
			end
			return
		end

		if titleState == "title" then
			if processed then return end
			if click or key == Enum.KeyCode.Return or key == Enum.KeyCode.Space
				or key == Enum.KeyCode.E or key == Enum.KeyCode.ButtonA
				or key == Enum.KeyCode.ButtonStart then
				pressStart()
			end

		elseif titleState == "menu" and menuActive then
			if UI.creditsOpen then
				if key == Enum.KeyCode.Escape or key == Enum.KeyCode.Backspace or key == Enum.KeyCode.ButtonB
					or key == Enum.KeyCode.Return or key == Enum.KeyCode.Space then
					UI.closeCredits()
				end
				return
			end
			if processed or Title.busy() then return end

			local n = NUM[key]
			if n and buttons[n] then
				selectedIndex = n
				refreshSelection()
				activate()
			elseif key == Enum.KeyCode.Down or key == Enum.KeyCode.S or key == Enum.KeyCode.DPadDown then
				UI.moveSelection(1)
			elseif key == Enum.KeyCode.Up or key == Enum.KeyCode.W or key == Enum.KeyCode.DPadUp then
				UI.moveSelection(-1)
			elseif key == Enum.KeyCode.Return or key == Enum.KeyCode.Space or key == Enum.KeyCode.ButtonA then
				activate()
			end
		end
	end)
end

-- ============================================================ INTRO

local introHolder = Instance.new("Frame")
introHolder.Size = UDim2.fromScale(1, 1)
introHolder.BackgroundColor3 = Color3.fromRGB(6, 7, 12)
introHolder.BackgroundTransparency = 1
introHolder.BorderSizePixel = 0
introHolder.Visible = false
introHolder.ZIndex = 5
introHolder.Parent = gui

local skyStrip = Instance.new("Frame")
skyStrip.Size = UDim2.new(1, 0, 0.3, 0)
skyStrip.BackgroundColor3 = C.skyTop
skyStrip.BackgroundTransparency = 1
skyStrip.BorderSizePixel = 0
skyStrip.ZIndex = 5
skyStrip.Parent = introHolder

local skyGradient = Instance.new("UIGradient")
skyGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(1, 1),
})
skyGradient.Rotation = 90
skyGradient.Parent = skyStrip

local profViewport = Instance.new("ViewportFrame")
profViewport.AnchorPoint = Vector2.new(0.5, 0.5)
profViewport.Position = UDim2.fromScale(0.5, 0.44)
profViewport.Size = UDim2.fromOffset(700, 620)
profViewport.BackgroundTransparency = 1
profViewport.LightColor = Color3.fromRGB(255, 255, 255)
profViewport.LightDirection = Vector3.new(-0.4, -1, -0.6)
profViewport.Ambient = Color3.fromRGB(190, 200, 220)
profViewport.ImageTransparency = 1
profViewport.ZIndex = 6
profViewport.Parent = introHolder

local profCam = Instance.new("Camera")
profCam.Parent = profViewport
profViewport.CurrentCamera = profCam

local introBox, introText, introArrow, introTag, introGroup = storyBox(introHolder, 7)
introTag.Text = "Professor Blox"
introGroup.GroupTransparency = 1
introArrow.Visible = false

-- Pulsante SKIP: salta l'intera intro. Sta in un CanvasGroup (un po' piu'
-- grande, per il bordino e il pop) per comparire in dissolvenza.
local introSkipGroup = Instance.new("CanvasGroup")
introSkipGroup.AnchorPoint = Vector2.new(1, 1)
introSkipGroup.Size = UDim2.fromOffset(112, 54)
introSkipGroup.Position = UDim2.new(1, 6, 0, -4)
introSkipGroup.BackgroundTransparency = 1
introSkipGroup.GroupTransparency = 1
introSkipGroup.Visible = false
introSkipGroup.ZIndex = 12
introSkipGroup.Parent = introBox

local introSkip = Pix.button(introSkipGroup, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(92, 36), {
	text = "SKIP", anchor = Vector2.new(0.5, 0.5), max = 20,
})

-- Il box resta sempre (si nasconde con introHolder): la voce sta li'
local introSound = Instance.new("Sound")
introSound.Name = "IntroVoice"
introSound.Volume = 1
introSound.Parent = introBox

-- ============================================================ INQUADRATURE

local function computeFrames(model)
	local cf, size = model:GetBoundingBox()
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	local head = model:FindFirstChild("Head")

	local forward = root and root.CFrame.LookVector or Vector3.new(0, 0, 1)
	forward = Vector3.new(forward.X, 0, forward.Z)
	forward = (forward.Magnitude < 0.01) and Vector3.new(0, 0, 1) or forward.Unit
	local right = forward:Cross(Vector3.new(0, 1, 0)).Unit

	profForward, profRight = forward, right

	local center  = cf.Position
	local h       = size.Y
	local facePos = head and head.Position or (center + Vector3.new(0, h * 0.34, 0))

	monSpot = center + right * math.max(size.X, 3) * 1.5

	local mid = center:Lerp(monSpot, 0.5)

	local function shot(name, pos, focus, fov)
		frames[name]     = CFrame.lookAt(pos, focus)
		frameFocus[name] = focus
		frameFov[name]   = fov or 55
	end

	shot("face",
		facePos + forward * (h * 0.95) + right * (h * 0.22) - Vector3.new(0, h * 0.05, 0),
		facePos - Vector3.new(0, h * 0.05, 0), 48)

	shot("faceClose",
		facePos + forward * (h * 0.62) - right * (h * 0.18) - Vector3.new(0, h * 0.03, 0),
		facePos, 44)

	shot("profile",
		facePos + forward * (h * 0.75) + right * (h * 0.68) + Vector3.new(0, h * 0.04, 0),
		facePos, 50)

	shot("wide",
		center + forward * (h * 1.25) + right * (h * 0.20) + Vector3.new(0, h * 0.15, 0),
		center + Vector3.new(0, h * 0.03, 0), 55)

	shot("wideLow",
		center + forward * (h * 1.15) - right * (h * 0.30) - Vector3.new(0, h * 0.26, 0),
		center + Vector3.new(0, h * 0.22, 0), 62)

	shot("high",
		center + forward * (h * 1.65) + right * (h * 0.45) + Vector3.new(0, h * 0.95, 0),
		center + Vector3.new(0, h * 0.05, 0), 58)

	shot("duo",
		center + forward * (h * 2.45) + right * (h * 0.62) + Vector3.new(0, h * 0.22, 0),
		mid + Vector3.new(0, h * 0.06, 0), 55)

	shot("duoClose",
		center + forward * (h * 1.55) + right * (h * 0.60) + Vector3.new(0, h * 0.16, 0),
		mid + Vector3.new(0, h * 0.05, 0), 48)

	shot("overMon",
		monSpot + forward * (h * 0.55) + right * (h * 0.55) + Vector3.new(0, h * 0.30, 0),
		facePos, 45)

	shot("throw",
		center + forward * (h * 1.90) + right * (h * 1.40) + Vector3.new(0, h * 0.70, 0),
		mid + Vector3.new(0, h * 0.30, 0), 65)

	shot("low",
		monSpot + forward * (h * 0.75) - right * (h * 0.15) + Vector3.new(0, h * 0.05, 0),
		monSpot + Vector3.new(0, h * 0.28, 0), 55)

	shot("monLow",
		monSpot + forward * (h * 0.90) + right * (h * 0.25) - Vector3.new(0, h * 0.06, 0),
		monSpot + Vector3.new(0, h * 0.25, 0), 50)

	shot("monFace",
		monSpot + forward * (h * 0.85) - right * (h * 0.28) + Vector3.new(0, h * 0.34, 0),
		monSpot + Vector3.new(0, h * 0.22, 0), 38)

	camGoal        = frames.face
	camFocus       = frameFocus.face
	camFov         = frameFov.face
	camStyle       = "push"
	camT0          = os.clock()
	profCam.CFrame = frames.face
	profCam.FieldOfView = camFov
end

local function setShot(name, style)
	if not frames[name] then return end
	camGoal  = frames[name]
	camFocus = frameFocus[name]
	camFov   = frameFov[name] or 55
	camStyle = style or "push"
	camT0    = os.clock()
end

local function cutTo(name, style)
	if not frames[name] then return end
	setShot(name, style)
	profCam.CFrame      = camGoal
	profCam.FieldOfView = camFov
end

local function computeMonFrames(model)
	if not model then return end
	local cf, size = model:GetBoundingBox()
	local mh    = math.max(size.Y, 1)
	local reach = math.max(size.X, size.Z, mh)
	local base  = cf.Position - Vector3.new(0, mh * 0.5, 0)
	local fwd   = profForward or Vector3.new(0, 0, 1)
	local rgt   = profRight   or Vector3.new(1, 0, 0)

	local function shotM(name, p, f, fov)
		frames[name]     = CFrame.lookAt(p, f)
		frameFocus[name] = f
		frameFov[name]   = fov
	end

	local eye = base + Vector3.new(0, mh * 0.72, 0)

	shotM("monLow",
		base + fwd * (reach * 2.0) + rgt * (reach * 0.5) + Vector3.new(0, mh * 0.25, 0),
		base + Vector3.new(0, mh * 0.55, 0), 52)

	shotM("monFace",
		eye + fwd * (reach * 1.6) - rgt * (reach * 0.55) + Vector3.new(0, mh * 0.12, 0),
		eye, 45)

	shotM("low",
		base + fwd * (reach * 2.2) - rgt * (reach * 0.3) + Vector3.new(0, mh * 0.20, 0),
		base + Vector3.new(0, mh * 0.60, 0), 55)
end

local function pickRandomSpecies()
	local names = {}
	local folder = ReplicatedStorage:FindFirstChild("PokemonModels")

	if folder then
		-- Anche dentro le sottocartelle Riggati / NonRiggati
		for _, c in ipairs(folder:GetDescendants()) do
			if c:IsA("Model") and (c.Parent == folder or c.Parent.Parent == folder)
				and PokemonDatabase.Get(c.Name) then
				table.insert(names, c.Name)
			end
		end
	end

	if #names == 0 then
		for key in pairs(PokemonDatabase.Species) do table.insert(names, key) end
	end
	if #names == 0 then return nil end

	return names[math.random(1, #names)]
end

-- ---------------------------------------------------------- EFFETTI VIEWPORT

local function vpPart(props)
	local p = Instance.new("Part")
	p.Anchored     = true
	p.CanCollide   = false
	p.CanQuery     = false
	p.CastShadow   = false
	p.Material     = Enum.Material.Neon
	p.Size         = Vector3.new(1, 1, 1)
	for k, v in pairs(props) do p[k] = v end
	p.Parent = profViewport
	return p
end

local function vpAnimate(duration, fn)
	local t0 = os.clock()
	while os.clock() - t0 < duration do
		fn(math.clamp((os.clock() - t0) / duration, 0, 1))
		RunService.RenderStepped:Wait()
	end
	fn(1)
end

local function vpRing(pos, color, radius, duration)
	local ring = vpPart({
		Shape = Enum.PartType.Cylinder, Color = color, Transparency = 0.05,
		Size = Vector3.new(0.3, 1, 1),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
	})
	task.spawn(function()
		vpAnimate(duration, function(t)
			local e = 1 - (1 - t) ^ 2
			ring.Size = Vector3.new(0.3 * (1 - t * 0.7), 1 + e * radius, 1 + e * radius)
			ring.Transparency = 0.05 + t * 0.95
		end)
		ring:Destroy()
	end)
end

local function vpFlash(pos, color, radius, duration)
	local orb = vpPart({
		Shape = Enum.PartType.Ball, Color = color, Transparency = 0.1,
		Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(pos),
	})
	task.spawn(function()
		vpAnimate(duration, function(t)
			local e = 1 - (1 - t) ^ 2
			orb.Size = Vector3.new(1, 1, 1) * (0.5 + e * radius * 2)
			orb.Transparency = 0.1 + t * 0.9
		end)
		orb:Destroy()
	end)
end

local function vpSparks(pos, color, count, power)
	for _ = 1, count do
		local dir = Vector3.new(
			math.random() * 2 - 1,
			math.random() * 1.3 + 0.3,
			math.random() * 2 - 1).Unit

		local s = vpPart({
			Shape = Enum.PartType.Ball, Color = color,
			Size = Vector3.new(0.28, 0.28, 0.28), CFrame = CFrame.new(pos),
		})

		task.spawn(function()
			local vel, p = dir * power * (0.5 + math.random()), pos
			vpAnimate(0.45 + math.random() * 0.25, function(t)
				vel = vel - Vector3.new(0, 1.1, 0)
				p = p + vel / 60
				s.CFrame = CFrame.new(p)
				s.Transparency = t
				s.Size = Vector3.new(1, 1, 1) * (0.28 * (1 - t * 0.6))
			end)
			s:Destroy()
		end)
	end
end

local ballWarned = false
local ballTemplate = ReplicatedStorage:WaitForChild("BloxBall", 10)

local function makeBall()
	local template = ballTemplate

	if not template and not ballWarned then
		ballWarned = true
		warn("[MainMenu] 'BloxBall' non trovata in ReplicatedStorage. " ..
			"Copiala da ServerStorage a ReplicatedStorage: il client non puo' leggere ServerStorage.")
	end

	if template and template:IsA("Model") then
		local clone = template:Clone()
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ProximityPrompt") then
				d:Destroy()
			end
		end
		if not clone.PrimaryPart then
			clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
		end
		clone.Parent = profViewport
		return clone, true
	end

	local ball = vpPart({
		Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(245, 245, 250), Size = Vector3.new(1.5, 1.5, 1.5),
	})

	local top = vpPart({
		Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(226, 58, 54), Size = Vector3.new(1.52, 0.78, 1.52),
	})
	local bandPart = vpPart({
		Color = Color3.fromRGB(24, 24, 30), Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(1.56, 0.16, 1.56),
	})

	local holder = Instance.new("Model")
	holder.Name = "IntroBall"
	holder.Parent = profViewport
	ball.Parent, top.Parent, bandPart.Parent = holder, holder, holder
	holder.PrimaryPart = ball

	top.CFrame = ball.CFrame * CFrame.new(0, 0.37, 0)
	bandPart.CFrame = ball.CFrame

	return holder, false
end

-- ---------------------------------------------------------- LANCIO E SPAWN

local function spawnBloxmon()
	if not profModel or not monSpot then return nil end

	local speciesId = pickRandomSpecies()
	if not speciesId then return nil end

	local profCF, profSize = profModel:GetBoundingBox()

	local hand = profModel:FindFirstChild("RightHand")
		or profModel:FindFirstChild("Right Arm")
		or profModel:FindFirstChild("Head")
	local startPos = hand and hand.Position
		or (profCF.Position + Vector3.new(0, profSize.Y * 0.2, 0))

	local ballBall = select(1, makeBall())
	local landPos = monSpot + Vector3.new(0, profSize.Y * 0.12, 0)

	ballBall:PivotTo(CFrame.new(startPos))

	cutTo("throw", "pull")
	task.wait(0.15)

	local arc = (landPos - startPos).Magnitude * 0.35
	vpAnimate(0.55, function(t)
		local e = t * t * (3 - 2 * t)
		local pos = startPos:Lerp(landPos, e) + Vector3.new(0, math.sin(e * math.pi) * arc, 0)
		ballBall:PivotTo(CFrame.new(pos) * CFrame.Angles(e * 16, e * 10, 0))
	end)

	task.wait(0.1)
	cutTo("low", "push")

	local gold = Color3.fromRGB(255, 246, 210)
	vpFlash(landPos, gold, profSize.Y * 0.5, 0.3)
	vpRing(landPos, gold, profSize.Y * 1.9, 0.45)
	vpSparks(landPos, gold, 16, 22)

	task.spawn(function()
		vpAnimate(0.25, function(t)
			for _, p in ipairs(ballBall:GetDescendants()) do
				if p:IsA("BasePart") then p.Transparency = t end
			end
		end)
		ballBall:Destroy()
	end)

	task.wait(0.12)

	local ok, model = pcall(function()
		return PokemonFactory.SpawnModel(
			{ speciesId = speciesId, uniqueId = "intro_" .. speciesId },
			CFrame.new(monSpot), profViewport)
	end)
	if not ok or not model then return nil end

	do
		local camPos = (frames.duo and frames.duo.Position)
			or (monSpot + (profForward or Vector3.new(0, 0, 1)) * 20)
		local dir = camPos - monSpot
		dir = Vector3.new(dir.X, 0, dir.Z)
		dir = (dir.Magnitude < 0.01) and (profForward or Vector3.new(0, 0, 1)) or dir.Unit
		dir = CFrame.Angles(0, math.rad(MON_FACE_YAW), 0) * dir
		model:PivotTo(CFrame.lookAt(monSpot, monSpot + dir))
	end

	do
		local pivot = model:GetPivot()
		local _, yaw = pivot:ToEulerAnglesYXZ()
		model:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, yaw, 0))
	end
	local monCF, monSize = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(0,
		(profCF.Position.Y - profSize.Y / 2) - (monCF.Position.Y - monSize.Y / 2), 0))

	monModel = model

	local saved = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			saved[p] = { p.Color, p.Material }
			p.Color = Color3.new(1, 1, 1)
			p.Material = Enum.Material.Neon
		end
	end

	local restCF = model:GetPivot()
	model:PivotTo(restCF * CFrame.new(0, -monSize.Y * 0.5, 0))

	vpAnimate(0.45, function(t)
		local e = 1 - (1 - t) ^ 2
		model:PivotTo(restCF * CFrame.new(0, -monSize.Y * 0.5 * (1 - e), 0))
		for p, d in pairs(saved) do
			if p.Parent then
				p.Color = Color3.new(1, 1, 1):Lerp(d[1], e)
				if e > 0.65 then p.Material = d[2] end
			end
		end
	end)

	for p, d in pairs(saved) do
		if p.Parent then p.Color = d[1]; p.Material = d[2] end
	end
	model:PivotTo(restCF)

	vpSparks(monSpot + Vector3.new(0, 0.5, 0), Color3.fromRGB(200, 240, 255), 10, 14)

	computeMonFrames(model)

	task.wait(0.35)
	cutTo("monLow", "rise")
	task.wait(0.9)
	cutTo("monFace", "push")
	task.wait(1.0)
	setShot("duoClose", "orbit")
	task.wait(0.4)

	local data = PokemonDatabase.Get(speciesId)
	return (data and data.name) or speciesId
end

local function loadProfessor()
	local source
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("Model") and string.lower(d.Name) == PROFESSOR_MODEL_NAME then
			source = d
			break
		end
	end
	if not source then
		warn("[MainMenu] Modello '" .. PROFESSOR_MODEL_NAME .. "' non trovato: intro senza rig.")
		return nil
	end

	local clone = source:Clone()
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	clone.Parent = profViewport

	computeFrames(clone)
	profModel = clone
	return clone
end

-- ============================================================ SEQUENZA

local finished = false

-- CONTINUE: nero, via la scena del titolo, e si torna al gioco
local function releaseControl()
	if finished then return end
	finished = true

	Title.leave(0.4)
	TweenService:Create(bg, TweenInfo.new(0.45), { BackgroundTransparency = 0 }):Play()
	task.wait(0.5)

	Title.stopScene()
	camera.CameraType  = Enum.CameraType.Custom
	camera.FieldOfView = 70
	local char = plr.Character
	if char and char:FindFirstChild("Humanoid") then
		camera.CameraSubject = char.Humanoid
	end

	lockPlayer(false)
	toggleGameGuis(true)

	TweenService:Create(bg, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
	task.wait(0.75)
	gui.Enabled = false
end

-- Testo lettera per lettera, sincronizzato con la voce. Il testo e' gia'
-- tutto nel label (MaxVisibleGraphemes): la grandezza non cambia mentre scrive.
local function typeWrite(label, text, token, getToken, soundId)
	label.Text = text
	label.MaxVisibleGraphemes = 0

	introSound:Stop()
	if soundId and soundId ~= "" then
		introSound.SoundId = soundId
		introSound.TimePosition = 0
		introSound:Play()
	end

	local total = utf8.len(text) or #text
	local charDelay = 0.022
	if soundId and soundId ~= "" then
		if not introSound.IsLoaded then
			introSound.Loaded:Wait()
		end
		local dur = introSound.TimeLength
		if dur and dur > 0 and total > 0 then
			charDelay = math.clamp(dur / total, 0.008, 0.05)
		end
	end

	for i = 1, total do
		if getToken() ~= token then
			introSound:Stop()
			return false
		end
		label.MaxVisibleGraphemes = i
		task.wait(charDelay)
	end
	label.MaxVisibleGraphemes = -1
	return true
end

-- ============================================================ RISVEGLIO SULLA SPIAGGIA

local Lighting = game:GetService("Lighting")
local Debris   = game:GetService("Debris")

local ALERT_SOUND_ID = "rbxassetid://118649555607825"

-- Sound del "!" tenuto sempre pronto e gia' caricato: creato al momento,
-- la prima volta partiva prima che l'audio fosse scaricato e restava muto
local alertSfx = Instance.new("Sound")
alertSfx.Name    = "MomAlertSound"
alertSfx.SoundId = ALERT_SOUND_ID
alertSfx.Volume  = 1
alertSfx.Parent  = game:GetService("SoundService")
task.spawn(function()
	pcall(function() game:GetService("ContentProvider"):PreloadAsync({ alertSfx }) end)
end)

local function findWakeSpawn()
	local want = string.lower(WAKE_SPAWN_NAME)
	local folder = Workspace:FindFirstChild("Spawn")
	local p = folder and folder:FindFirstChild(WAKE_SPAWN_NAME, true)
	if p and p:IsA("BasePart") then return p end
	for _, d in ipairs(Workspace:GetDescendants()) do
		local n = string.lower(d.Name)
		if d:IsA("BasePart") and (n == want or n == "spawn/" .. want) then return d end
	end
	return nil
end

local function charBottomY(char)
	local minY = math.huge
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 1
			and not p:FindFirstAncestorOfClass("Accessory") then
			local cf, s = p.CFrame, p.Size
			local ext = math.abs(cf.RightVector.Y) * s.X / 2
				+ math.abs(cf.UpVector.Y) * s.Y / 2
				+ math.abs(cf.LookVector.Y) * s.Z / 2
			minY = math.min(minY, cf.Position.Y - ext)
		end
	end
	return minY
end

local function snapToGround(hrp, char, groundY)
	for _ = 1, 3 do RunService.RenderStepped:Wait() end
	local bottom = charBottomY(char)
	if bottom < math.huge then
		hrp.CFrame += Vector3.new(0, groundY - bottom, 0)
	end
	RunService.RenderStepped:Wait()
end

local function wakeUpSequence()
	local char = plr.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	local head = char and char:FindFirstChild("Head")
	local spawnPart = findWakeSpawn()

	local wg = Instance.new("ScreenGui")
	wg.Name = "WakeGui"
	wg.IgnoreGuiInset = true
	wg.ResetOnSpawn = false
	wg.DisplayOrder = 150
	wg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	wg.Parent = playerGui

	local fade = Instance.new("Frame")
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Color3.new(1, 1, 1)
	fade.BorderSizePixel = 0
	fade.ZIndex = 10
	fade.Parent = wg

	gui.Enabled = false

	local function handBack()
		camera.CameraType = Enum.CameraType.Custom
		if hum then camera.CameraSubject = hum end
		camera.FieldOfView = 70
		lockPlayer(false)
		toggleGameGuis(true)
	end

	if not (hum and hrp and head and spawnPart) then
		warn("[MainMenu] Part '" .. WAKE_SPAWN_NAME .. "' o personaggio non trovati: salto il risveglio.")
		handBack()
		TweenService:Create(fade, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		Debris:AddItem(wg, 0.9)
		return
	end

	-- ---- palpebre ----
	local LID = 0.6
	local function makeLid(isTop)
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, LID)
		f.AnchorPoint = Vector2.new(0, isTop and 0 or 1)
		f.Position = UDim2.fromScale(0, isTop and 0 or 1)
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.ZIndex = 5
		f.Parent = wg
		local g = Instance.new("UIGradient")
		g.Rotation = isTop and 90 or -90
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.85, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
		return f
	end
	local topLid, botLid = makeLid(true), makeLid(false)

	local function setEyes(open, t, style)
		local a = UDim2.fromScale(0, -LID * open)
		local b = UDim2.fromScale(0, 1 + LID * open)
		if t and t > 0 then
			local info = TweenInfo.new(t, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			TweenService:Create(topLid, info, { Position = a }):Play()
			TweenService:Create(botLid, info, { Position = b }):Play()
		else
			topLid.Position, botLid.Position = a, b
		end
	end

	-- scritta Arcade con l'ombra a pixel, sopra le palpebre (ZIndex 5)
	local prompt = Pix.text(Pix.canvas(wg, 6), UDim2.fromScale(0.5, 0.85), UDim2.fromOffset(720, 28), {
		text = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
			and "Tap anywhere to wake up" or "Click anywhere to wake up",
		anchor = Vector2.new(0.5, 0.5),
	}).main
	prompt.TextTransparency = 1
	local promptScale = Instance.new("UIScale")
	promptScale.Parent = prompt.Parent

	-- ---- articolazioni per le pose (R15 e R6) ----
	local r15 = hum.RigType == Enum.HumanoidRigType.R15
	local function joint(r15Part, r15Name, r6Name)
		local p = char:FindFirstChild(r15 and r15Part or "Torso")
		return p and p:FindFirstChild(r15 and r15Name or r6Name)
	end
	local J = {
		rHip = joint("RightUpperLeg", "RightHip", "Right Hip"),
		lHip = joint("LeftUpperLeg", "LeftHip", "Left Hip"),
		rSh  = joint("RightUpperArm", "RightShoulder", "Right Shoulder"),
		lSh  = joint("LeftUpperArm", "LeftShoulder", "Left Shoulder"),
		neck = joint("Head", "Neck", "Neck"),
	}
	if r15 then
		J.rElbow = joint("RightLowerArm", "RightElbow")
		J.lElbow = joint("LeftLowerArm", "LeftElbow")
		J.rKnee  = joint("RightLowerLeg", "RightKnee")
		J.lKnee  = joint("LeftLowerLeg", "LeftKnee")
		J.waist  = joint("UpperTorso", "Waist")
	end
	local base0 = {}
	for k, m in pairs(J) do base0[k] = m.C0 end

	local LEFT = { lHip = true, lSh = true }
	local function jcf(key, fwd, out, twist)
		local b = base0[key]
		if not b then return nil end
		local f, o, w = math.rad(fwd or 0), math.rad(out or 0), math.rad(twist or 0)
		local side = LEFT[key] and -1 or 1
		if r15 then
			return b * CFrame.Angles(f, 0, 0) * CFrame.Angles(0, 0, o * side) * CFrame.Angles(0, w, 0)
		end
		return b * CFrame.Angles(0, 0, f * side) * CFrame.Angles(-o, 0, 0) * CFrame.Angles(0, w, 0)
	end
	local function bendCF(key, deg)
		local b = base0[key]
		if not b then return nil end
		local s = (key == "rKnee" or key == "lKnee") and -1 or 1
		return b * CFrame.Angles(math.rad(deg) * s, 0, 0)
	end
	local function waistCF(deg)
		return base0.waist and base0.waist * CFrame.Angles(-math.rad(deg), 0, 0) or nil
	end
	local function headCF(yawD, pitchD, rollD)
		local b = base0.neck
		if not b then return nil end
		local y, p, r = math.rad(yawD or 0), math.rad(pitchD or 0), math.rad(rollD or 0)
		if r15 then return b * CFrame.Angles(p, y, r) end
		return b * CFrame.Angles(-p, r, y)
	end
	local function setJ(key, cf)
		if J[key] and cf then J[key].C0 = cf end
	end
	local function curve(keys, t)
		local n = #keys
		if t <= keys[1][1] then return keys[1][2] end
		if t >= keys[n][1] then return keys[n][2] end
		for i = 2, n do
			local a, b = keys[i - 1], keys[i]
			if t <= b[1] then
				local u = (t - a[1]) / (b[1] - a[1])
				local p0, p1, p2 = (keys[i - 2] or a)[2], a[2], b[2]
				local p3 = (keys[i + 1] or b)[2]
				return 0.5 * (2 * p1 + (-p0 + p2) * u
					+ (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u
					+ (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u)
			end
		end
		return keys[n][2]
	end

	local function yaw(deg)
		if not base0.neck then return nil end
		local r = math.rad(deg)
		return base0.neck * (r15 and CFrame.Angles(0, r, 0) or CFrame.Angles(0, 0, r))
	end
	local function pose(goals, t, style)
		for key, cf in pairs(goals) do
			local m = J[key]
			if m then
				if t and t > 0 then
					TweenService:Create(m, TweenInfo.new(t, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { C0 = cf }):Play()
				else
					m.C0 = cf
				end
			end
		end
	end

	-- ---- setup nel nero ----
	setEyes(0.78, 0)
	TweenService:Create(fade, TweenInfo.new(0.9), { BackgroundColor3 = Color3.new(0, 0, 0) }):Play()
	task.wait(1)

	local animate = char:FindFirstChild("Animate")
	if animate then animate.Enabled = false end
	local animator = hum:FindFirstChildOfClass("Animator")
	if animator then
		for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do tr:Stop(0) end
	end
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	local look = spawnPart.CFrame.LookVector
	local fwd = Vector3.new(look.X, 0, look.Z)
	fwd = fwd.Magnitude > 0.01 and fwd.Unit or Vector3.new(0, 0, -1)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local hit = Workspace:Raycast(spawnPart.Position + Vector3.new(0, spawnPart.Size.Y / 2 + 3, 0), Vector3.new(0, -60, 0), params)
	local groundY = hit and hit.Position.Y or (spawnPart.Position.Y + spawnPart.Size.Y / 2)
	local base = Vector3.new(spawnPart.Position.X, groundY, spawnPart.Position.Z)

	hrp.Anchored = true

	hrp.CFrame = CFrame.lookAt(base, base + fwd) + Vector3.new(0, 5, 0)
	snapToGround(hrp, char, groundY)
	local standCF = hrp.CFrame

	local hipLocal = Vector3.new(0, -1, 0)
	if J.rHip and J.lHip then
		local a = (J.rHip.Part0.CFrame * J.rHip.C0).Position
		local b = (J.lHip.Part0.CFrame * J.lHip.C0).Position
		hipLocal = standCF:PointToObjectSpace((a + b) / 2)
	end

	pose({
		rSh = jcf("rSh", 0, 14),   rElbow = bendCF("rElbow", 10),
		lSh = jcf("lSh", 0, 18),   lElbow = bendCF("lElbow", 12),
		rHip = jcf("rHip", 0, 7),
		lHip = r15 and jcf("lHip", 18, 5) or jcf("lHip", 0, 9),
		lKnee = bendCF("lKnee", 34),
		neck = headCF(22, 0, 8),
	}, 0)

	hrp.CFrame = standCF * CFrame.Angles(math.rad(90), 0, 0)
	snapToGround(hrp, char, groundY)

	local breathing = true
	task.spawn(function()
		local t, yawCur, yawGoal, nextShift = 0, 25, 25, 5
		while breathing do
			local dt = RunService.Heartbeat:Wait()
			if not breathing then break end
			t += dt
			local b = (math.sin(t * 1.5) + 1) / 2
			if t > nextShift then
				yawGoal = (yawGoal > 16) and 6 or 28
				nextShift = t + 5 + math.random() * 3
			end
			yawCur += (yawGoal - yawCur) * math.min(dt * 1.2, 1)
			setJ("waist", waistCF(2.5 * b))
			setJ("neck", headCF(yawCur, 2 * b, 8))
		end
	end)

	-- ---- camera ----
	local camMode = "sleep"
	local cineFn, camLerp = nil, 0.09
	local orbit = { ang = 28, dist = 6.5, height = 0.3, lookY = -0.2 }
	local t0 = os.clock()
	camera.CameraType = Enum.CameraType.Scriptable

	local lastMode
	RunService:BindToRenderStep("WakeCam", Enum.RenderPriority.Last.Value, function(dt)
		local t = os.clock() - t0
		local sway = CFrame.new(math.sin(t * 0.5) * 0.05, math.sin(t * 0.7) * 0.04, 0)
			* CFrame.Angles(0, 0, math.rad(math.sin(t * 0.37) * 0.25))

		local goal
		local alpha = 1 - math.exp(-dt * 12)

		if camMode == "sleep" then
			local k = 1 - (1 - math.clamp(t / 7, 0, 1)) ^ 3
			local ang = math.rad(160 - 85 * k - math.max(t - 7, 0) * 1.5)
			local off = CFrame.Angles(0, ang, 0) * (fwd * (26 - 19 * k))
			local focus = hrp.Position
			goal = CFrame.lookAt(focus + off + Vector3.new(0, 30 - 21.5 * k, 0), focus)
			camera.FieldOfView = 60
		elseif camMode == "orbit" then
			local off = CFrame.Angles(0, math.rad(orbit.ang), 0) * (fwd * orbit.dist)
			goal = CFrame.lookAt(hrp.Position + off + Vector3.new(0, orbit.height, 0),
				head.Position + Vector3.new(0, orbit.lookY, 0))
		elseif camMode == "cine" and cineFn then
			goal = cineFn()
			alpha = (camLerp >= 1) and 1 or (1 - (1 - camLerp) ^ (dt * 60))
		end

		if goal then
			if camMode ~= lastMode then alpha = 1 end
			camera.CFrame = camera.CFrame:Lerp(goal * sway, alpha)
		end
		lastMode = camMode

		if camera.FieldOfView > 70 then camera.FieldOfView = 70 end
	end)
	local camConn = { Disconnect = function() RunService:UnbindFromRenderStep("WakeCam") end }

	local function moveOrbit(goal, time)
		local start = table.clone(orbit)
		task.spawn(vpAnimate, time, function(t)
			local e = t * t * (3 - 2 * t)
			for k, v in pairs(goal) do orbit[k] = start[k] + (v - start[k]) * e end
		end)
	end

	-- ---- Zzz ----
	local sleeping = true
	local zzz = Instance.new("BillboardGui")
	zzz.Adornee = head
	zzz.Size = UDim2.fromScale(4, 4)
	zzz.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	zzz.LightInfluence = 0
	zzz.ResetOnSpawn = false
	zzz.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	zzz.Parent = playerGui

	task.spawn(function()
		local i = 0
		while sleeping do
			i += 1
			-- Arcade con l'ombra a pixel, spostata in scala (il cartello e' in stud)
			local z = Pix.text(zzz, UDim2.fromScale(0.35, 0.85), UDim2.fromScale(0.16, 0.16), {
				text = (i % 3 == 0) and "Z" or "z", anchor = Vector2.new(0.5, 0.5),
			})
			z.shadow.Position = UDim2.fromScale(0.07, 0.07)
			z.holder.Rotation = -15
			z.main.TextTransparency = 1
			TweenService:Create(z.holder, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(0.6 + math.random() * 0.2, 0.1),
				Size = UDim2.fromScale(0.32, 0.32),
				Rotation = 12,
			}):Play()
			TweenService:Create(z.main, TweenInfo.new(0.4), { TextTransparency = 0.1 }):Play()
			task.delay(1.3, function()
				if z.holder.Parent then
					TweenService:Create(z.main, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
				end
			end)
			Debris:AddItem(z.holder, 2.3)
			task.wait(0.75)
		end
	end)

	local waves
	if WAVES_SOUND_ID ~= "" then
		waves = Instance.new("Sound")
		waves.SoundId = WAVES_SOUND_ID
		waves.Looped = true
		waves.Volume = 0
		waves.Parent = wg
		waves:Play()
		TweenService:Create(waves, TweenInfo.new(3), { Volume = 0.5 }):Play()
	end

	-- ---- apertura sulla spiaggia ----
	t0 = os.clock()
	TweenService:Create(fade, TweenInfo.new(2.2, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 }):Play()
	task.wait(3.5)

	TweenService:Create(prompt, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
	task.spawn(function()
		task.wait(0.6)
		while sleeping do
			TweenService:Create(promptScale, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Scale = 1.06 }):Play()
			TweenService:Create(prompt, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { TextTransparency = 0.35 }):Play()
			task.wait(0.9)
			if not sleeping then break end
			TweenService:Create(promptScale, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Scale = 1 }):Play()
			TweenService:Create(prompt, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { TextTransparency = 0 }):Play()
			task.wait(0.9)
		end
	end)

	local woke = Instance.new("BindableEvent")
	local inConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		local ty = input.UserInputType
		if ty == Enum.UserInputType.MouseButton1 or ty == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Return
			or input.KeyCode == Enum.KeyCode.ButtonA then
			woke:Fire()
		end
	end)
	woke.Event:Wait()
	inConn:Disconnect()
	sleeping = false
	breathing = false

	TweenService:Create(prompt, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
	zzz:Destroy()
	setEyes(0, 0.35, Enum.EasingStyle.Quad)
	task.wait(0.45)

	-- ---- POV ----
	camMode = nil
	local function hideChar(hidden)
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = hidden and 1 or 0
			end
		end
	end
	hideChar(true)

	local blur = Instance.new("BlurEffect")
	blur.Size = 24
	blur.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = 0.35
	cc.Saturation = -0.5
	cc.Parent = Lighting
	local function fx(t, size, bright, sat)
		TweenService:Create(blur, TweenInfo.new(t), { Size = size }):Play()
		TweenService:Create(cc, TweenInfo.new(t), { Brightness = bright, Saturation = sat }):Play()
	end

	local eyeLie = head.Position + Vector3.new(0, 0.9, 0)
	local povLie = CFrame.lookAt(eyeLie, eyeLie + Vector3.yAxis, -fwd)
	camera.CFrame = povLie
	camera.FieldOfView = 70

	setEyes(0.22, 1.1); fx(1.1, 18, 0.3, -0.4); task.wait(1.3)
	setEyes(0, 0.16); task.wait(0.22)
	setEyes(0.5, 0.6); fx(0.6, 10, 0.18, -0.25); task.wait(0.8)
	setEyes(0.05, 0.14); task.wait(0.2)
	setEyes(0.85, 0.45); fx(0.9, 3, 0.05, -0.05); task.wait(0.5)

	-- ---- seduto ----
	hrp.CFrame = standCF
	local sitLeg = r15 and 100 or 88
	pose(base0, 0)
	pose({
		rHip = jcf("rHip", sitLeg, 8),  lHip = jcf("lHip", sitLeg, 8),
		rKnee = bendCF("rKnee", 20),    lKnee = bendCF("lKnee", 20),
		rSh = jcf("rSh", 35, 5),        lSh = jcf("lSh", 35, 5),
		rElbow = bendCF("rElbow", 35),  lElbow = bendCF("lElbow", 35),
		waist = waistCF(4),
		neck = headCF(0, -8, 0),
	}, 0)
	snapToGround(hrp, char, groundY)
	local sitCF = hrp.CFrame

	local eyeSit = head.Position + fwd * 0.7 + Vector3.new(0, 0.2, 0)
	local povSit = CFrame.lookAt(eyeSit, eyeSit + fwd - Vector3.new(0, 0.06, 0))
	fx(1, 0, 0, 0)
	vpAnimate(1.1, function(t)
		local e = t * t * (3 - 2 * t)
		camera.CFrame = povLie:Lerp(povSit, e)
	end)
	task.wait(0.8)

	-- ---- terza persona ----
	setEyes(0, 0.14); task.wait(0.18)
	blur:Destroy(); cc:Destroy()
	hideChar(false)
	orbit.ang, orbit.dist, orbit.height, orbit.lookY = 28, 6.5, 0.3, -0.25
	camMode = "orbit"
	camera.FieldOfView = 55
	setEyes(0.82, 0.35)
	moveOrbit({ dist = 5.8 }, 1.2)
	task.wait(0.35)
	pose({ neck = headCF(-18, -6, -6) }, 0.14); task.wait(0.14)
	pose({ neck = headCF(18, -6, 6) }, 0.16);   task.wait(0.16)
	pose({ neck = headCF(-10, -7, -3) }, 0.14); task.wait(0.14)
	pose({ neck = headCF(0, -8, 0) }, 0.2);     task.wait(0.35)

	local LEAN   = { {0, 0}, {0.3, 30}, {0.55, 22}, {0.85, 0}, {1, 0} }
	local RISE   = { {0, 0}, {0.3, 0}, {0.8, 1.02}, {0.9, 0.97}, {1, 1} }
	local LEGS   = r15 and { {0, sitLeg}, {0.3, 140}, {0.55, 70}, {0.8, 8}, {1, 0} }
		or { {0, sitLeg}, {0.3, sitLeg}, {0.8, 6}, {1, 0} }
	local KNEES  = { {0, 20}, {0.3, 100}, {0.55, 75}, {0.8, 20}, {0.9, 14}, {1, 0} }
	local ARMS   = { {0, 35}, {0.3, 50}, {0.55, 30}, {0.85, 0}, {1, 0} }
	local ELBOWS = { {0, 35}, {0.3, 25}, {0.7, 10}, {1, 0} }
	local WAIST  = { {0, 4}, {0.3, 14}, {0.6, 8}, {1, 0} }
	local HEAD   = { {0, -8}, {0.3, -14}, {0.7, 0}, {1, 0} }

	moveOrbit({ dist = 8.5, height = 1.4, lookY = -0.1 }, 1.3)
	local dropY = sitCF.Position.Y - standCF.Position.Y
	vpAnimate(1.3, function(t)
		local L = curve(LEAN, t)
		local up = standCF + Vector3.new(0, dropY * (1 - curve(RISE, t)), 0)
		hrp.CFrame = up * CFrame.new(hipLocal) * CFrame.Angles(-math.rad(L), 0, 0) * CFrame.new(-hipLocal)

		local legs = curve(LEGS, t) + L
		setJ("rHip", jcf("rHip", legs, 8 * (1 - t)))
		setJ("lHip", jcf("lHip", legs, 8 * (1 - t)))
		setJ("rKnee", bendCF("rKnee", curve(KNEES, t)))
		setJ("lKnee", bendCF("lKnee", curve(KNEES, t)))
		setJ("rSh", jcf("rSh", curve(ARMS, t), 5 * (1 - t)))
		setJ("lSh", jcf("lSh", curve(ARMS, t), 5 * (1 - t)))
		setJ("rElbow", bendCF("rElbow", curve(ELBOWS, t)))
		setJ("lElbow", bendCF("lElbow", curve(ELBOWS, t)))
		setJ("waist", waistCF(curve(WAIST, t)))
		setJ("neck", headCF(0, curve(HEAD, t), 0))
	end)
	pose(base0, 0)
	task.wait(0.15)

	pose({ neck = yaw(50) }, 0.4); task.wait(0.65)
	pose({ neck = yaw(-50) }, 0.65); task.wait(0.9)
	pose({ neck = base0.neck }, 0.35); task.wait(0.3)

	-- ============================================================ LA MAMMA
	moveOrbit({ ang = 120, dist = 9, height = 2.3, lookY = 0.15 }, 1.3)
	setEyes(0.92, 1)
	task.wait(1)

	local function findAny(name, class, roots)
		local want = string.lower(name)
		for _, r in ipairs(roots) do
			for _, d in ipairs(r:GetDescendants()) do
				if d:IsA(class) and string.lower(d.Name) == want then
					if class ~= "Model" or d:FindFirstChildOfClass("Humanoid") then return d end
				end
			end
		end
		return nil
	end

	-- ---- box di dialogo: lo stesso dell'intro del professore ----
	local box, boxText, boxArrow, tag = storyBox(wg, 7)
	box.Position = UDim2.fromScale(0.5, 1.3)
	tag.Text = "Mom"
	boxArrow.Visible = false

	local function boxShow(on)
		TweenService:Create(box, TweenInfo.new(0.45, Enum.EasingStyle.Quart,
			on and Enum.EasingDirection.Out or Enum.EasingDirection.In),
			{ Position = UDim2.fromScale(0.5, on and 0.965 or 1.3) }):Play()
	end

	local advance = Instance.new("BindableEvent")
	local dlgConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		local ty = input.UserInputType
		if ty == Enum.UserInputType.MouseButton1 or ty == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.E
			or input.KeyCode == Enum.KeyCode.Return
			or input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.ButtonA then
			advance:Fire()
		end
	end)

	local function say(text)
		boxText.Text = text
		boxText.MaxVisibleGraphemes = 0
		boxArrow.Visible = false
		local typed = false
		task.spawn(function()
			for i = 1, (utf8.len(text) or #text) do
				if typed then return end
				boxText.MaxVisibleGraphemes = i
				task.wait(1 / 55)
			end
			typed = true
			boxText.MaxVisibleGraphemes = -1
			boxArrow.Visible = true
		end)
		advance.Event:Wait()
		if not typed then
			typed = true
			boxText.MaxVisibleGraphemes = -1
			boxArrow.Visible = true
			advance.Event:Wait()
		end
	end

	-- ---- rig della mamma (clone solo lato client) ----
	local momSrc = findAny(MOM_MODEL_NAME, "Model", { ReplicatedStorage })
	local mom, momHum, momRoot, momHead

	if momSrc then
		mom = momSrc:Clone()
		mom.Name = "MomWakeScene"
		for _, d in ipairs(mom:GetDescendants()) do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
			end
		end
		momHum  = mom:FindFirstChildOfClass("Humanoid")
		momRoot = mom:FindFirstChild("HumanoidRootPart") or mom.PrimaryPart
		momHead = mom:FindFirstChild("Head") or momRoot
		if momHum and momRoot then
			momRoot.Anchored = true
			if momHead ~= momRoot then
				local focus = Instance.new("Part")
				focus.Name = "CamFocus"
				focus.Size = Vector3.new(0.2, 0.2, 0.2)
				focus.Transparency = 1
				focus.CanCollide, focus.CanQuery, focus.CanTouch = false, false, false
				focus.Massless = true
				focus.CFrame = CFrame.new(momHead.Position)
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1 = momRoot, focus
				weld.Parent = focus
				focus.Parent = mom
				momHead = focus
			end
			momHum.AutoRotate = false
			momHum.WalkSpeed = 0
			momHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			momHum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			momHum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			mom.Parent = Workspace
		else
			mom:Destroy(); mom = nil
		end
	else
		warn("[MainMenu] Rig '" .. MOM_MODEL_NAME .. "' non trovato in ReplicatedStorage.")
	end

	if mom then
		local momTracks = {}
		local function momAnim(id)
			if not id or id == "" then return nil end
			if momTracks[id] ~= nil then return momTracks[id] or nil end
			local anim8r = momHum:FindFirstChildOfClass("Animator")
			if not anim8r then anim8r = Instance.new("Animator"); anim8r.Parent = momHum end
			local a = Instance.new("Animation"); a.AnimationId = id
			local ok, tr = pcall(function() return anim8r:LoadAnimation(a) end)
			if ok and tr then
				tr.Looped = true
				tr.Priority = Enum.AnimationPriority.Movement
				momTracks[id] = tr
				return tr
			end
			momTracks[id] = false
			return nil
		end

		local ignore = { mom, char }
		local function groundAt(p)
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Exclude
			rp.FilterDescendantsInstances = ignore
			local h = Workspace:Raycast(p + Vector3.new(0, 30, 0), Vector3.new(0, -140, 0), rp)
			return h and h.Position.Y or p.Y
		end

		local spawnMom = findAny(MOM_SPAWN_PART, "BasePart", { Workspace })
		local startPos = spawnMom and spawnMom.Position or (base - fwd * 55)

		local toYou = Vector3.new(base.X - startPos.X, 0, base.Z - startPos.Z)
		local fwd = toYou.Magnitude > 0.1 and toYou.Unit or fwd
		local stopPos  = base - fwd * 6.5

		momRoot.CFrame = CFrame.lookAt(startPos, startPos + fwd)
		RunService.RenderStepped:Wait()
		RunService.RenderStepped:Wait()
		local yOff = momRoot.Position.Y - charBottomY(mom)

		local function placeMom(p, dir)
			local at = Vector3.new(p.X, groundAt(p) + yOff, p.Z)
			momRoot.CFrame = CFrame.lookAt(at, at + dir)
		end
		placeMom(startPos, fwd)

		-- "!" sopra la testa
		local bb = Instance.new("BillboardGui")
		bb.Adornee = momHead
		bb.Size = UDim2.fromScale(3, 3)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		bb.Parent = playerGui

		-- "!" Arcade dorato; il cartello e' in stud, quindi l'ombra a pixel
		-- si sposta in scala e non di pochi pixel
		local ex = Pix.text(bb, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), {
			text = "!", color = Pix.C.gold, anchor = Vector2.new(0.5, 0.5),
		})
		ex.shadow.Position = UDim2.fromScale(0.07, 0.07)
		local exScale = Instance.new("UIScale")
		exScale.Scale = 0
		exScale.Parent = ex.holder

		camMode = "cine"
		camLerp = 1
		cineFn = function()
			local p = momHead.Position
			return CFrame.lookAt(p + fwd * 10 + Vector3.new(0, 1.8, 0), p + Vector3.new(0, 0.2, 0))
		end
		camera.FieldOfView = 55
		-- Suono del "!": se l'audio non e' ancora pronto aspetta (max 1s)
		local waitT = os.clock()
		while not alertSfx.IsLoaded and os.clock() - waitT < 1 do task.wait() end
		alertSfx.TimePosition = 0
		alertSfx:Play()

		vpAnimate(0.25, function(t) exScale.Scale = 1.4 * (1 - (1 - t) ^ 3) end)
		vpAnimate(0.15, function(t) exScale.Scale = 1.4 - 0.4 * t end)
		Debris:AddItem(bb, 1.6)
		task.wait(0.5)

		camLerp = 1
		local run = momAnim(MOM_RUN_ANIM)
		if run then run:Play(0.2) end
		local travel = math.clamp((startPos - stopPos).Magnitude / 22, 1.3, 3.5)
		task.delay(travel - 0.55, function()
			local turnCF = CFrame.lookAt(standCF.Position,
				Vector3.new(stopPos.X, standCF.Position.Y, stopPos.Z))
			vpAnimate(0.55, function(t)
				hrp.CFrame = standCF:Lerp(turnCF, t * t * (3 - 2 * t))
			end)
		end)
		vpAnimate(travel, function(t)
			placeMom(startPos:Lerp(stopPos, 1 - (1 - t) ^ 2), fwd)
		end)
		if run then run:Stop(0.3) end

		local function twoShot()
			local a, b = head.Position, momHead.Position
			local mid = a:Lerp(b, 0.5)
			local axis = b - a
			axis = Vector3.new(axis.X, 0, axis.Z)
			axis = axis.Magnitude > 0.01 and axis.Unit or fwd
			return CFrame.lookAt(mid + axis:Cross(Vector3.yAxis) * 6.5 + Vector3.new(0, 1.3, 0), mid)
		end
		local function closeOn(getPos, sign, dist, fov)
			cineFn = function()
				local p = getPos()
				return CFrame.lookAt(p + fwd * sign * dist + Vector3.new(0, 0.3, 0), p)
			end
			TweenService:Create(camera, TweenInfo.new(0.6), { FieldOfView = fov or 45 }):Play()
		end
		local momPos = function() return momHead.Position end
		local myPos  = function() return head.Position end

		camLerp = 0.07
		cineFn = twoShot
		TweenService:Create(camera, TweenInfo.new(0.8), { FieldOfView = 50 }):Play()
		boxShow(true)
		task.wait(0.45)

		say("There you are! Oh, thank goodness.")
		closeOn(momPos, 1, 3.4, 42)
		say("I've been looking for you everywhere. The docks, the market, Kenta's shop...")
		say("And the whole time you were out here. Asleep. In the sand.")
		closeOn(myPos, -1, 3.2, 42)
		say("...")
		cineFn = twoShot
		TweenService:Create(camera, TweenInfo.new(0.6), { FieldOfView = 50 }):Play()
		say("Don't give me that look, you've got half the beach in your hair.")
		say("Come on. Home, before it gets dark and the wild ones come out.")
		say("Your room's exactly how you left it. Which is to say, a mess.")
		boxShow(false)
		task.wait(0.4)

		local walk = momAnim(MOM_RUN_ANIM)
		if walk then walk:Play(0.25); walk:AdjustSpeed(0.75) end

		-- Anche il nostro personaggio si gira e cammina dietro alla mamma
		local myWalk
		do
			local hum = char:FindFirstChildOfClass("Humanoid")
			local anim8r = hum and (hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum))
			if anim8r then
				local a = Instance.new("Animation"); a.AnimationId = MOM_RUN_ANIM
				local ok, tr = pcall(function() return anim8r:LoadAnimation(a) end)
				if ok and tr then
					tr.Looped = true
					tr.Priority = Enum.AnimationPriority.Action
					myWalk = tr
				end
			end
		end
		local myStart = hrp.Position
		local myYOff  = myStart.Y - groundAt(myStart)
		local myEnd   = stopPos - fwd * 14
		local function placeMe(p)
			local at = Vector3.new(p.X, groundAt(p) + myYOff, p.Z)
			hrp.CFrame = CFrame.lookAt(at, at - fwd)
		end

		camLerp = 0.05
		-- Di lato: si vedono tutti e due che se ne vanno
		local sideDir = fwd:Cross(Vector3.yAxis)
		cineFn = function()
			local mid = head.Position:Lerp(momHead.Position, 0.5)
			return CFrame.lookAt(mid + sideDir * 11 + fwd * 3 + Vector3.new(0, 2.4, 0), mid)
		end
		task.delay(1.8, function()
			fade.BackgroundColor3 = Color3.new(0, 0, 0)
			TweenService:Create(fade, TweenInfo.new(1.3), { BackgroundTransparency = 0 }):Play()
		end)
		task.delay(0.35, function()
			if myWalk then myWalk:Play(0.2); myWalk:AdjustSpeed(0.8) end
			vpAnimate(2.75, function(t)
				placeMe(myStart:Lerp(myEnd, t))
			end)
		end)
		vpAnimate(3.1, function(t)
			placeMom(stopPos:Lerp(stopPos - fwd * 28, t), -fwd)
		end)
		if walk then walk:Stop(0.3) end
		if myWalk then myWalk:Stop(0.2) end
		task.wait(0.4)
	else
		fade.BackgroundColor3 = Color3.new(0, 0, 0)
		TweenService:Create(fade, TweenInfo.new(1.2), { BackgroundTransparency = 0 }):Play()
		task.wait(1.4)
	end

	if mom then mom:Destroy(); mom = nil end
	if waves then TweenService:Create(waves, TweenInfo.new(1.5), { Volume = 0 }):Play() end
	setEyes(1, 0.3)

	-- ============================================================ A CASA
	-- scritta sopra il nero (ZIndex 10)
	local cardLayer = Pix.canvas(wg, 12)
	local card = Pix.text(cardLayer, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(760, 28), {
		text = "A short walk home later...", color = Pix.C.textDim, anchor = Vector2.new(0.5, 0.5),
	}).main
	card.TextTransparency = 1

	TweenService:Create(card, TweenInfo.new(1), { TextTransparency = 0 }):Play()
	task.wait(2.2)
	TweenService:Create(card, TweenInfo.new(0.7), { TextTransparency = 1 }):Play()
	task.wait(0.8)
	cardLayer:Destroy()

	local room = findAny(ROOM_PART_NAME, "BasePart", { Workspace })
	if room then
		local rl = room.CFrame.LookVector
		local rfwd = Vector3.new(rl.X, 0, rl.Z)
		rfwd = rfwd.Magnitude > 0.01 and rfwd.Unit or Vector3.new(0, 0, -1)

		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = { char }
		local rhit = Workspace:Raycast(room.Position + Vector3.new(0, room.Size.Y / 2 + 3, 0),
			Vector3.new(0, -60, 0), rp)
		local ry = rhit and rhit.Position.Y or (room.Position.Y + room.Size.Y / 2)
		local rbase = Vector3.new(room.Position.X, ry, room.Position.Z)

		hrp.CFrame = CFrame.lookAt(rbase, rbase + rfwd) + Vector3.new(0, 4, 0)
		snapToGround(hrp, char, ry)

		local kk = 0
		camMode = "cine"
		camLerp = 1
		cineFn = function()
			local p = hrp.Position + Vector3.new(0, 1.4, 0)
			local side = rfwd:Cross(Vector3.yAxis) * (4 * (1 - kk))
			return CFrame.lookAt(p - rfwd * (8 - 2 * kk) + side + Vector3.new(0, 5 - 1.4 * kk, 0), p)
		end
		camera.CFrame = cineFn()
		camera.FieldOfView = 58

		TweenService:Create(fade, TweenInfo.new(1.8), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(camera, TweenInfo.new(3.2), { FieldOfView = 70 }):Play()
		vpAnimate(3.2, function(t) kk = 1 - (1 - t) ^ 3 end)
	else
		warn("[MainMenu] Part '" .. ROOM_PART_NAME .. "' non trovata: resti sulla spiaggia.")
		TweenService:Create(fade, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
		task.wait(1.3)
	end

	camConn:Disconnect()
	dlgConn:Disconnect()
	hrp.Anchored = false
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
	hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
	hum:ChangeState(Enum.HumanoidStateType.Running)
	if animate then animate.Enabled = true end
	handBack()

	-- ---- nome del luogo: stesso box piccolo delle zone (AreaNameDisplay) ----
	local areaScript = plr:FindFirstChild("PlayerScripts") and plr.PlayerScripts:FindFirstChild("AreaNameDisplay")
	local areaEvent  = areaScript and areaScript:WaitForChild("ShowAreaName", 3)
	if areaEvent then
		task.delay(0.5, function() areaEvent:Fire(ROOM_LABEL) end)
		task.delay(1, function() if wg and wg.Parent then wg:Destroy() end end)
	else task.spawn(function()
		-- riquadro pixel art: e' fatto di tanti Frame, sfuma tutto insieme in un CanvasGroup
		local banner = Instance.new("CanvasGroup")
		banner.AnchorPoint = Vector2.new(0.5, 0.5)
		banner.Position = UDim2.fromScale(0.5, 0.45)
		banner.Size = UDim2.fromScale(0.3, 0.1)
		banner.BackgroundTransparency = 1
		banner.GroupTransparency = 1
		banner.Parent = Pix.canvas(wg, 20)

		local bScale = Instance.new("UIScale")
		bScale.Scale = 0.8
		bScale.Parent = banner

		local panel = Pix.box(banner, UDim2.new(), UDim2.fromScale(1, 1), "panel")
		Pix.text(panel.content, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.86, 0.6), {
			text = ROOM_LABEL, anchor = Vector2.new(0.5, 0.5),
		})

		task.wait(0.5)
		TweenService:Create(bScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(banner, TweenInfo.new(0.3), { GroupTransparency = 0 }):Play()

		task.wait(2.6)
		local out = TweenInfo.new(0.35)
		TweenService:Create(bScale, out, { Scale = 0.9 }):Play()
		TweenService:Create(banner, out, { GroupTransparency = 1 }):Play()
		task.wait(0.5)
		wg:Destroy()
	end) end
end

local function runIntro()
	menuActive = false
	local PokeballsUi = plr.PlayerGui:WaitForChild("BloxmonHUD")
	PokeballsUi.Enabled = false

	-- via il titolo sotto lo sfondo
	Title.leave(0.45)
	TweenService:Create(bg, TweenInfo.new(0.45), { BackgroundTransparency = 0 }):Play()
	task.wait(0.5)
	Title.stopScene()

	introHolder.Visible = true
	TweenService:Create(introHolder, TweenInfo.new(0.7), { BackgroundTransparency = 0 }):Play()
	task.wait(0.7)

	TweenService:Create(skyStrip, TweenInfo.new(0.8), { BackgroundTransparency = 0.15 }):Play()

	local model = loadProfessor()
	TweenService:Create(profViewport, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { ImageTransparency = 0 }):Play()

	local WORLD_CAMERAS = {}
	local isWorldCam = false
	local bobbing = true
	if model then
		task.spawn(function()
			local t0 = os.clock()
			while bobbing do
				local t = os.clock() - t0
				if camGoal then
					local e      = os.clock() - (camT0 or t0)
					local style  = camStyle or "static"
					local target = camGoal

					if style == "push" then
						target = camGoal * CFrame.new(0, 0, -math.min(e * 0.20, 1.3))
					elseif style == "pull" then
						target = camGoal * CFrame.new(0, 0, math.min(e * 0.26, 2.0))
					elseif style == "rise" then
						target = camGoal * CFrame.new(0, math.min(e * 0.22, 1.2), -math.min(e * 0.12, 0.7))
					elseif style == "orbit" and camFocus then
						local ang = math.rad(math.clamp(e * 2.6, 0, 16))
						local off = CFrame.Angles(0, ang, 0) * (camGoal.Position - camFocus)
						target = CFrame.lookAt(camFocus + off, camFocus)
					end

					local sway = CFrame.new(
						math.sin(t * 0.43) * 0.16 + math.sin(t * 1.19) * 0.05,
						math.sin(t * 0.61) * 0.12 + math.sin(t * 1.57) * 0.04,
						0
					) * CFrame.Angles(0, 0, math.rad(math.sin(t * 0.37) * 0.4))

					target = target * sway

					if isWorldCam then
						camera.CFrame      = camera.CFrame:Lerp(target, 0.07)
						camera.FieldOfView = camera.FieldOfView + (camFov - camera.FieldOfView) * 0.06
					else
						profCam.CFrame      = profCam.CFrame:Lerp(target, 0.07)
						profCam.FieldOfView = profCam.FieldOfView + (camFov - profCam.FieldOfView) * 0.06
					end
				end
				RunService.RenderStepped:Wait()
			end
		end)
	end

	task.wait(0.7)

	-- box, targhetta e testo compaiono insieme
	TweenService:Create(introGroup, TweenInfo.new(0.4), { GroupTransparency = 0 }):Play()

	task.wait(0.4)

	introSkipGroup.Visible = true
	TweenService:Create(introSkipGroup, TweenInfo.new(0.4), { GroupTransparency = 0 }):Play()

	local page = 0
	local speciesName = nil
	local token = 0
	local typing = false
	local skipRequested = false
	local advanceEvent = Instance.new("BindableEvent")

	local function getToken() return token end

	local inputConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.Return
			or input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.E then
			advanceEvent:Fire()
		end
	end)

	local skipBtnConn = introSkip.hit.MouseButton1Click:Connect(function()
		skipRequested = true
		advanceEvent:Fire()
	end)

	while true do
		page += 1
		local entry = INTRO_SCRIPT[page]
		if not entry then break end
		if skipRequested then break end

		if entry.camera and frames[entry.camera] then
			setShot(entry.camera, entry.style)

			isWorldCam = WORLD_CAMERAS[entry.camera] == true

			if isWorldCam then
				camera.CFrame = frames[entry.camera]
				TweenService:Create(bg,           TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
				TweenService:Create(introHolder,  TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
				TweenService:Create(skyStrip,     TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
				TweenService:Create(profViewport, TweenInfo.new(0.5), { ImageTransparency = 1 }):Play()
			else
				TweenService:Create(bg,           TweenInfo.new(0.5), { BackgroundTransparency = 0 }):Play()
				TweenService:Create(introHolder,  TweenInfo.new(0.5), { BackgroundTransparency = 0 }):Play()
				TweenService:Create(skyStrip,     TweenInfo.new(0.5), { BackgroundTransparency = 0.15 }):Play()
				TweenService:Create(profViewport, TweenInfo.new(0.5), { ImageTransparency = 0 }):Play()
			end
		end

		if entry.spawn and not monModel then
			task.wait(0.5)
			speciesName = spawnBloxmon()
			task.wait(0.3)
		end

		local pageText = entry.text
		if string.find(pageText, "%%s") then
			pageText = string.format(pageText, speciesName or "Bloxmon")
		end

		token += 1
		typing = true
		introArrow.Visible = false

		local myToken = token
		local completed = typeWrite(introText, pageText, myToken, getToken, entry.soundId)
		typing = false

		if completed then
			introArrow.Visible = true
		end

		advanceEvent.Event:Wait()
		if skipRequested then break end

		if typing then
			introSound:Stop()
			token += 1
			introText.Text = pageText
			introText.MaxVisibleGraphemes = -1
			introArrow.Visible = true
			advanceEvent.Event:Wait()
			if skipRequested then break end
		end
	end

	inputConn:Disconnect()
	skipBtnConn:Disconnect()
	introSkipGroup.Visible = false
	bobbing = false
	introSound:Stop()

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 20
	flash.Parent = gui

	TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 0 }):Play()
	task.wait(0.55)

	introHolder.Visible = false
	if model then model:Destroy() end
	if monModel then monModel:Destroy(); monModel = nil end
	profModel = nil

	finished = true
	wakeUpSequence()
	flash:Destroy()
	PokeballsUi.Enabled = true
end

activate = function()
	local btn = buttons[selectedIndex]
	if not btn or not menuActive or Title.busy() then return end
	if not btn.enabled then
		Title.denied()
		return
	end

	Title.confirm()

	if btn.id == "new" then
		menuActive = false
		task.spawn(runIntro)

	elseif btn.id == "continue" then
		menuActive = false
		task.spawn(releaseControl)

	elseif btn.id == "afk" then
		Title.afk()

	elseif btn.id == "credits" then
		Title.credits()
	end
end

-- ============================================================ AVVIO

local function openMenu()
	task.spawn(function()
		local ok, party = pcall(function() return Remotes.GetParty:InvokeServer() end)
		hasSave = (ok and type(party) == "table" and #party > 0) or false
		-- Totale: squadra + PC
		local total = hasSave and #party or 0
		local countFn = hasSave and ReplicatedStorage:WaitForChild("GetMonCount", 5)
		if countFn then
			local okN, n = pcall(function() return countFn:InvokeServer() end)
			if okN and type(n) == "number" and n >= total then total = n end
		end
		Title.setSave(hasSave, total)
		if hasSave then selectedIndex = 2 end
		refreshSelection()
	end)

	gui.Enabled = true
	toggleGameGuis(false)
	lockPlayer(true)
	camera.CameraType = Enum.CameraType.Scriptable

	bg.BackgroundTransparency = 1
	Title.open()
end

-- ============================================================ LOADING
-- Nello stile pixel art della squadra a schermo: sfondo bordeaux scuro,
-- logo Arcade dorato, Ball che dondola, barra dorata e consigli.

do
	local CFG = TITLE_CFG
	local PC  = Pix.C
	local SC  = UDim2.fromScale

	local function go(o, t, props, style)
		TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props):Play()
	end

	local loadGui = Pix.make("ScreenGui", {
		Name = "LoadingGui", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 200,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)

	local root = Pix.make("CanvasGroup", {
		Size = SC(1, 1), BackgroundColor3 = PC.white, BorderSizePixel = 0,
		Active = true,   -- i clic non passano al titolo che carica sotto
	}, loadGui)
	Pix.make("UIGradient", { Rotation = 90, Color = ColorSequence.new(PC.slot, PC.ink) }, root)

	-- strisce oblique che scorrono, come i banner
	local stripes = Pix.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = SC(0.5, 0.5), Size = SC(2, 2),
		BackgroundTransparency = 1, Rotation = 30,
	}, root)
	for i = 0, 24 do
		Pix.make("Frame", {
			Position = SC(i * 0.045, 0), Size = SC(0.014, 1), BackgroundColor3 = PC.white,
			BackgroundTransparency = 0.95, BorderSizePixel = 0,
		}, stripes)
	end
	TweenService:Create(stripes, TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ Position = SC(0.545, 0.5) }):Play()

	local layer = Pix.canvas(root, 2)

	-- logo
	local logo = Pix.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = SC(0.5, 0.36), Size = SC(0.55, 0.17),
		BackgroundTransparency = 1,
	}, layer)
	pixLogo(logo, CFG.title, 1)

	-- Ball che dondola
	local ball = Pix.ball(layer, SC(0.5, 0.58), SC(0.1, 0.1), 3)
	local ballShadow = Pix.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = SC(0.5, 0.645), Size = SC(0.08, 0.012),
		SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundColor3 = PC.ink,
		BackgroundTransparency = 0.4, BorderSizePixel = 0,
	}, layer)

	-- barra
	local bar = Pix.bar(layer, SC(0.5, 0.735), SC(0.34, 0.028), PC.gold, 2, Vector2.new(0.5, 0.5))

	local loadLabel = Pix.text(layer, SC(0.5, 0.685), SC(0.3, 0.04), {
		text = "Loading", anchor = Vector2.new(0.5, 0.5), max = 34,
	}).main

	-- Arcade e' larga: i consigli lunghi vanno a capo invece di rimpicciolirsi
	local tip = Pix.text(layer, SC(0.5, 0.82), SC(0.62, 0.06), {
		anchor = Vector2.new(0.5, 0.5), color = PC.textDim, wrap = true, max = 24,
	}).main
	tip.TextTransparency = 1

	task.spawn(function()
		local loading = true

		lockPlayer(true)
		toggleGameGuis(false)

		task.spawn(function()
			local n = 0
			while loading do
				n = (n + 1) % 4
				loadLabel.Text = "Loading" .. string.rep(".", n)
				task.wait(0.35)
			end
		end)

		-- dondola come una ball appena lanciata
		task.spawn(function()
			while loading do
				go(ball, 0.18, { Rotation = -22 })
				task.wait(0.18)
				go(ball, 0.28, { Rotation = 22 })
				task.wait(0.28)
				go(ball, 0.18, { Rotation = 0 })
				task.wait(0.18)
				go(ball, 0.12, { Position = SC(0.5, 0.565) }, Enum.EasingStyle.Quad)
				go(ballShadow, 0.12, { Size = SC(0.065, 0.01) })
				task.wait(0.12)
				go(ball, 0.14, { Position = SC(0.5, 0.58) }, Enum.EasingStyle.Quad)
				go(ballShadow, 0.14, { Size = SC(0.08, 0.012) })
				task.wait(0.5)
			end
		end)

		task.spawn(function()
			local tips = CFG.loadingTips or {}
			if #tips == 0 then return end
			local i = math.random(1, #tips)
			while loading do
				tip.Text = "TIP: " .. tips[i]
				go(tip, 0.4, { TextTransparency = 0 })
				task.wait(3.2)
				go(tip, 0.4, { TextTransparency = 1 })
				task.wait(0.45)
				i = i % #tips + 1
			end
		end)

		-- barra: sale mentre il gioco carica, poi si riempie
		local t0 = os.clock()
		local p  = 0
		while not game:IsLoaded() do
			p = 0.6 * (1 - math.exp(-(os.clock() - t0) / 2))
			bar.set(p)
			RunService.Heartbeat:Wait()
		end
		-- Il menu parte SOTTO il caricamento: la scena del titolo si costruisce
		-- qui dietro e si scopre solo quando gira liscia (prima andava a scatti).
		openMenu()
		local ContentProvider = game:GetService("ContentProvider")
		local from, t1 = p, os.clock()
		local smoothFrames, shown = 0, p
		while os.clock() - t1 < 15 do
			local dt = RunService.Heartbeat:Wait()
			smoothFrames = (dt < 1 / 40) and smoothFrames + 1 or 0
			local ready = os.clock() - t1 > 2 and smoothFrames >= 45
				and ContentProvider.RequestQueueSize == 0
			local a = math.min((os.clock() - t1) / 4, 1)
			local goal = from + ((ready and 1 or 0.92) - from) * (a * a * (3 - 2 * a))
			shown = math.max(shown, goal)
			bar.set(shown)
			if ready and a >= 1 then break end
		end
		bar.set(1)
		loading = false

		go(root, 0.6, { GroupTransparency = 1 })
		task.wait(0.65)
		loadGui:Destroy()
	end)
end
