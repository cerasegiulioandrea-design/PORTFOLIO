--[[
	QuestMarker.client.lua

	Indicatore dell'obiettivo corrente. Legge l'attributo replicato
	"StoryStage" e accende un faro luminoso sul bersaglio giusto.
	Scheda, freccia e cartello in pixel art come la squadra a schermo
	(PartyHUD), col kit Pix.

	PER AGGIUNGERE UNA TAPPA: una riga in OBJECTIVES.
	  target = nome esatto del Model o della BasePart nel Workspace
	  enter  = prefisso della coppia di teleport (<prefisso>1 fuori, <prefisso>2 dentro)
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local TextService       = game:GetService("TextService")

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

-- Misure dei pezzi 2D in pixel a 1080p (il cartello in pixel "di progetto":
-- uno UIScale lo adatta al billboard, che cambia grandezza con la distanza)
local CARD_W, CARD_H = 420, 72     -- scheda dell'obiettivo
local SIGN_W, SIGN_H = 270, 102    -- cartello: stesse proporzioni del billboard (9 x 3.4)

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

local screenGui, edgeArrow, edgePulse, edgeLabel, objCard, objTitle, objHint
local hasObjective = false

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
	bb.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	bb.Parent      = signAnchor
	table.insert(current.fx, bb)

	-- Il cartello e' disegnato a misura fissa e scalato come uno sprite:
	-- cosi' bordi e ombre restano in proporzione a ogni distanza
	local fitArea = Pix.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, bb)
	local sign = Pix.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(SIGN_W, SIGN_H), BackgroundTransparency = 1,
	}, fitArea)
	local signScale = Pix.make("UIScale", { Scale = 1 }, sign)
	local function fitSign()
		-- Prima del primo disegno il billboard misura 0: non azzerare la scala
		local h = fitArea.AbsoluteSize.Y
		if h > 0 then signScale.Scale = h / SIGN_H end
	end
	fitArea:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitSign)
	fitSign()

	-- Riquadro largo quanto serve al nome (Arcade e' a larghezza fissa,
	-- "Exit" non deve stare in un cartello enorme); i nomi lunghi vanno a capo:
	-- su una riga sola "... — Entrance" diventerebbe minuscolo
	local function textW(s, px)
		return TextService:GetTextSize(s, px, Pix.FONT, Vector2.new(4096, 4096)).X
	end
	local panelW = math.min(math.max(textW(label, 30), textW("9999 studs", 20)) + 28, SIGN_W)
	local panel = Pix.box(sign, UDim2.new(0.5, 0, 0.5, -6), UDim2.fromOffset(panelW, 70), "panel", 2, Vector2.new(0.5, 0.5))
	Pix.text(panel.content, UDim2.fromOffset(4, 2), UDim2.new(1, -8, 0, 30), {
		text = label, color = Pix.C.gold, wrap = true,
	})
	local distText = Pix.text(panel.content, UDim2.fromOffset(4, 36), UDim2.new(1, -8, 0, 20), {
		color = Pix.C.text,
	})
	-- Freccetta sotto il riquadro che punta giu' al bersaglio
	Pix.arrow(sign, UDim2.new(0.5, 0, 0.5, 35), 3, Pix.C.gold, 1, 90)

	current.sign      = signAnchor
	current.signCF    = signAnchor.CFrame
	current.distLabel = distText.main
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
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent         = player:WaitForChild("PlayerGui")

	local canvas = Pix.canvas(screenGui)

	-- Freccetta pixel dentro un holder che si posiziona e ruota come prima
	-- (0 = verso destra); lo UIScale la fa pulsare
	edgeArrow = Pix.make("Frame", {
		Name = "EdgeArrow", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(60, 60),
		BackgroundTransparency = 1, Visible = false,
	}, canvas)
	edgePulse = Pix.make("UIScale", { Scale = 1 }, edgeArrow)
	Pix.arrow(edgeArrow, UDim2.fromScale(0.5, 0.5), 8, Pix.C.gold, 1)

	edgeLabel = Pix.text(canvas, UDim2.new(), UDim2.fromScale(0.16, 0.028), {
		anchor = Vector2.new(0.5, 0.5), color = Pix.C.text,
	}).holder
	edgeLabel.Visible = false

	-- La barra in alto di Roblox non scala con lo schermo: la scheda resta
	-- sempre OBJ_POS.Y pixel veri sotto il bordo (come prima), in una fascia
	-- col suo canvas
	local objArea = Pix.make("Frame", {
		Position = UDim2.fromOffset(0, OBJ_POS.Y.Offset), Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, ZIndex = 2,
	}, screenGui)

	-- Scheda dell'obiettivo. CanvasGroup: e' fatta di tanti Frame e deve
	-- entrare e sfumare tutta insieme
	objCard = Pix.make("CanvasGroup", {
		Name = "Objective", Position = UDim2.fromOffset(OBJ_POS.X.Offset, 0),
		Size = UDim2.fromOffset(CARD_W, CARD_H), BackgroundTransparency = 1, Visible = false,
	}, Pix.canvas(objArea))
	local card = Pix.box(objCard, UDim2.new(), UDim2.fromScale(1, 1), "panel")

	-- Rombo d'oro (due freccette schiena contro schiena, sovrapposte di un
	-- pixel per non lasciare fessure) nel riquadro incavato, come la gemma
	-- dello strumento nella squadra
	local well = Pix.box(card.content, UDim2.fromScale(0, 0.5), UDim2.fromOffset(44, 44), "slot", 1, Vector2.new(0, 0.5))
	Pix.arrow(well.content, UDim2.new(0.5, -7, 0.5, 0), 4, Pix.C.gold, 1, 180)
	Pix.arrow(well.content, UDim2.new(0.5, 7, 0.5, 0), 4, Pix.C.gold, 1, 0)

	objTitle = Pix.text(card.content, UDim2.fromOffset(54, 2), UDim2.new(1, -58, 0, 20), {
		color = Pix.C.gold, alignX = Enum.TextXAlignment.Left,
	})
	objTitle.holder.Name = "ObjectiveTitle"

	objHint = Pix.text(card.content, UDim2.fromOffset(54, 26), UDim2.new(1, -58, 0, 32), {
		color = Pix.C.text, alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top,
		wrap = true, max = 14,
	})
	objHint.holder.Name = "ObjectiveHint"
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
	if objCard then
		objCard.Visible = hasObjective and not hidden()
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
	edgePulse.Scale    = 1 + math.sin(t * 5) * 0.08

	edgeLabel.Visible = false
end)

-- ============================================================================
-- CAMBIO OBIETTIVO
-- ============================================================================

local shownStage = nil

local function showObjective(objective, stage)
	if not objTitle then return end
	-- Senza obiettivo la scheda si nasconde
	hasObjective = objective ~= nil
	objTitle.main.Text = objective and string.upper(objective.label or objective.target) or ""
	objHint.main.Text  = objective and (objective.hint or "") or ""

	if shownStage == stage then return end
	shownStage = stage

	-- La scheda intera entra da sinistra e compare
	local goal = UDim2.fromOffset(OBJ_POS.X.Offset, 0)
	objCard.Position = goal - UDim2.fromOffset(40, 0)
	objCard.GroupTransparency = 1
	Pix.tw(objCard, 0.5, { Position = goal }, Enum.EasingStyle.Back)
	Pix.tw(objCard, 0.35, { GroupTransparency = 0 })
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
