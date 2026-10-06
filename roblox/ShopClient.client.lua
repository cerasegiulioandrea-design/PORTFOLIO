--[[
	ShopClient.client.lua
	Percorso: StarterPlayer/StarterPlayerScripts/ShopClient  (LocalScript)

	GUI del negozio in stile Poké Mart:
	  - box messaggi del commesso in basso, col suo nome sulla targhetta
	  - menu BUY / SELL / EXIT
	  - lista articoli con prezzo, descrizione dell'articolo selezionato
	  - barra quantita' con pulsante BUY/SELL esplicito

	Pixel art come la squadra a schermo (PartyHUD), col kit Pix: tutto sta
	dentro un Pix.canvas, quindi i riquadri restano in scale (frazioni dello
	schermo) e gli offset sono pixel a 1080p che scalano con lo schermo.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TextService       = game:GetService("TextService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes      = require(ReplicatedStorage:WaitForChild("Remotes"))
local ItemDatabase = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ItemDatabase"))

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

local BOX_IMAGE = "rbxassetid://105630568407213"
local SYMBOL    = "₽"
local ROW_H     = 62 -- altezza di una riga della lista (pixel a 1080p)

local C = Pix.C

local function format(amount)
	local s = tostring(math.floor(tonumber(amount) or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- Quadratino col colore dell'articolo: luce e ombra ricavate dal colore stesso
local function swatchStyle(color)
	return { color, color:Lerp(C.white, 0.35), color:Lerp(C.ink, 0.35) }
end

-- Cifra in Arcade preceduta da una monetina d'oro col ₽ (Arcade non ce l'ha).
-- d = lato della moneta. Ritorna il Pix.text della cifra.
local function coinAmount(parent, pos, size, d, opts)
	local holder = Pix.make("Frame", {
		Position = pos, Size = size, AnchorPoint = opts.anchor or Vector2.zero,
		BackgroundTransparency = 1, ZIndex = opts.z or 3,
	}, parent)
	local coin = Pix.box(holder, UDim2.fromScale(0, 0.5), UDim2.fromOffset(d, d), "gold", 1, Vector2.new(0, 0.5))
	Pix.text(coin.box, UDim2.fromScale(0.5, 0.5), UDim2.new(1, -2 * Pix.P, 1, -2 * Pix.P), {
		text = SYMBOL, font = Pix.SYMBOL, color = Pix.textOn("gold"), shadowColor = C.goldLight,
		anchor = Vector2.new(0.5, 0.5), z = 4,
	})
	return Pix.text(holder, UDim2.fromOffset(d + 8, 0), UDim2.new(1, -(d + 8), 1, 0), {
		text = opts.text or "0", color = opts.color or C.text, max = opts.max,
		alignX = Enum.TextXAlignment.Left,
	})
end

-- Piccolo "pop" quando un riquadro compare o cambia
local function pop(scale)
	scale.Scale = 0.94
	Pix.tw(scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- ============================================================================
-- STRUTTURA
-- ============================================================================

local gui = Instance.new("ScreenGui")
gui.Name           = "ShopGui"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.DisplayOrder   = 45
gui.Enabled        = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = playerGui

-- Velo a tutto schermo: non e' un riquadro, resta un Frame semplice sotto al canvas
local dim = Instance.new("Frame")
dim.Size                   = UDim2.fromScale(1, 1)
dim.BackgroundColor3       = Color3.fromRGB(6, 8, 16)
dim.BackgroundTransparency = 0.5
dim.BorderSizePixel        = 0
dim.Parent                 = gui

local canvas = Pix.canvas(gui, 2)

-- --------------------------------------------------------- SOLDI (alto destra)
local money = Pix.box(canvas, UDim2.fromScale(0.975, 0.03), UDim2.fromScale(0.20, 0.075), "panel", 3, Vector2.new(1, 0))

Pix.text(money.content, nil, UDim2.fromScale(0.6, 0.38), {
	text = "MONEY", color = C.textDim, alignX = Enum.TextXAlignment.Left, max = 18,
})

local moneyValue = coinAmount(money.content, UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.56), 28, {
	anchor = Vector2.new(0, 1), max = 32,
}).main

-- ---------------------------------------------------------- LISTA (destra)
-- Finestra col titolo (cambia a ogni schermata) e la X rossa per chiudere
local listWin = Pix.window(canvas, UDim2.fromScale(0.975, 0.125), UDim2.fromScale(0.40, 0.56), "", {
	anchor = Vector2.new(1, 0), band = 0.12, close = true, z = 3,
})

-- Titoli lunghi e corti della stessa misura (l'ombra deve restare allineata)
for _, l in ipairs({ listWin.title.main, listWin.title.shadow }) do
	Pix.make("UITextSizeConstraint", { MaxTextSize = 28 }, l)
end
local listHeader = listWin.title.main

local closeButton = listWin.close
closeButton.hit.Name = "CloseShop"

local listWell = Pix.box(listWin.content, nil, nil, "slot", 1)

local scroller = Pix.make("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 2 * Pix.P, ScrollBarImageColor3 = C.bodyLight,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
}, listWell.content)

-- Margine ai lati: il bordino dorato e il "pop" delle righe non vanno tagliati
-- (il pop allarga la riga del 5%, quindi il margine cresce con la larghezza)
Pix.make("UIPadding", {
	PaddingLeft = UDim.new(0.025, 6), PaddingRight = UDim.new(0.025, 6),
	PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
}, scroller)

Pix.make("UIListLayout", {
	Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, scroller)

-- ------------------------------------------------------- DESCRIZIONE (sx)
local info = Pix.box(canvas, UDim2.fromScale(0.025, 0.40), UDim2.fromScale(0.44, 0.30), "panel", 3)
local infoPanel = info.box
infoPanel.Visible = false
local infoPop = Pix.make("UIScale", { Scale = 1 }, infoPanel)

local infoDot = Pix.box(info.content, nil, UDim2.fromOffset(72, 72), swatchStyle(C.gold), 1)

local infoStrip = Pix.box(info.content, UDim2.fromOffset(81, 0), UDim2.new(1, -81, 0, 72), "slot", 1)
local infoName = Pix.text(infoStrip.content, UDim2.fromScale(0.03, 0.12), UDim2.fromScale(0.94, 0.76), {
	alignX = Enum.TextXAlignment.Left, max = 34,
}).main

local infoDesc = Pix.text(info.content, UDim2.fromOffset(6, 86), UDim2.new(1, -12, 1, -92), {
	color = C.textDim, wrap = true, max = 24,
	alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top,
}).main

-- ---------------------------------------------------------- MESSAGGI (basso)
-- Come il box della storia: riquadro bordeaux, testo in un incavo e la
-- targhetta d'oro col nome del commesso a cavallo del bordo
local msg = Pix.box(canvas, UDim2.fromScale(0.025, 0.965), UDim2.fromScale(0.50, 0.21), "panel", 3, Vector2.new(0, 1))

local msgWell = Pix.box(msg.content, UDim2.fromOffset(0, 20), UDim2.new(1, 0, 1, -20), "slot", 1)
local msgText = Pix.text(msgWell.content, UDim2.fromOffset(14, 10), UDim2.new(1, -28, 1, -20), {
	wrap = true, max = 30, min = 8,
	alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top,
}).main

-- Stesse misure della targhetta della storia, larga quanto il nome
local TAG_H, TAG_TX = 40, 24
local clerkTag = Pix.box(msg.box, UDim2.fromOffset(28, 0), UDim2.fromOffset(120, TAG_H), "gold", 5, Vector2.new(0, 0.5))
local clerkName = Pix.text(clerkTag.content, UDim2.fromScale(0.5, 0.5), UDim2.new(1, -12, 0, TAG_TX), {
	text = "Clerk", anchor = Vector2.new(0.5, 0.5), max = TAG_TX,
	color = Pix.textOn("gold"), shadowColor = C.goldLight,
}).main
local function fitClerkTag()
	local w = TextService:GetTextSize(clerkName.Text, TAG_TX, Pix.FONT, Vector2.new(2000, 200)).X
	clerkTag.box.Size = UDim2.fromOffset(math.max(80, w + 30), TAG_H)
end
clerkName:GetPropertyChangedSignal("Text"):Connect(fitClerkTag)
fitClerkTag()

-- ------------------------------------------------------ BARRA QUANTITÀ
local qty = Pix.box(canvas, UDim2.fromScale(0.975, 0.965), UDim2.fromScale(0.44, 0.15), "panel", 3, Vector2.new(1, 1))
local qtyBox = qty.box
qtyBox.Visible = false
local qtyPop = Pix.make("UIScale", { Scale = 1 }, qtyBox)

local function stepButton(text, xPos)
	return Pix.button(qty.content, UDim2.fromScale(xPos, 0.5), UDim2.fromScale(0.085, 0.5), {
		text = text, anchor = Vector2.new(0.5, 0.5), max = 30, z = 2,
	})
end

local qtyDown = stepButton("-", 0.075)
local qtyUp   = stepButton("+", 0.30)

local qtyWell = Pix.box(qty.content, UDim2.fromScale(0.1875, 0.5), UDim2.fromScale(0.12, 0.5), "slot", 1, Vector2.new(0.5, 0.5))
local qtyCount = Pix.text(qtyWell.content, nil, nil, { text = "1", max = 30 }).main

local qtyTotal = coinAmount(qty.content, UDim2.fromScale(0.37, 0.5), UDim2.fromScale(0.25, 0.42), 30, {
	anchor = Vector2.new(0, 0.5), max = 32,
}).main

local confirmButton = Pix.button(qty.content, UDim2.fromScale(0.76, 0.5), UDim2.fromScale(0.26, 0.58), {
	text = "BUY", style = "green", anchor = Vector2.new(0.5, 0.5), max = 34, z = 2,
})

local cancelButton = Pix.button(qty.content, UDim2.fromScale(0.945, 0.5), UDim2.fromScale(0.08, 0.45), {
	text = "X", style = "red", anchor = Vector2.new(0.5, 0.5), max = 26, z = 2,
})
-- Quadrato, ma non piu' largo dello spazio accanto a BUY (sui 4:3 si toccavano)
Pix.make("UIAspectRatioConstraint", { AspectRatio = 1 }, cancelButton.root)

-- ============================================================================
-- STATO
-- ============================================================================

local state = {
	open      = false,
	shopId    = nil,
	clerk     = "Clerk",
	mode      = "menu", -- menu | buy | sell
	stock     = {},
	inventory = {},
	money     = 0,
	sellRatio = 0.5,
	pending   = nil, -- { itemId, unit, max, isSell }
	qty       = 1,
}

local function say(text, color)
	msgText.Text = text or ""
	msgText.TextColor3 = color or C.text
end

local function setMoney(amount)
	state.money = math.floor(tonumber(amount) or 0)
	moneyValue.Text = format(state.money)
end

-- Via le righe (sono Frame), non lo UIListLayout e il padding
local function clearList()
	for _, child in ipairs(scroller:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

local function showInfo(item)
	if not item then
		infoPanel.Visible = false
		return
	end
	infoPanel.Visible = true
	Pix.paint(infoDot, swatchStyle(item.color or C.gold))
	infoName.Text = item.name
	infoDesc.Text = item.description or ""
	pop(infoPop)
end

-- Riga della lista. price = nil per le voci di menu, back = riga per tornare indietro.
local function makeRow(order, text, price, onClick, accent, back)
	local style = back and "slot" or "panel"
	-- La riga sta in un Frame fisso della lista: cosi' il pop parte dal centro
	-- e non sposta le righe sotto
	local cell = Pix.make("Frame", {
		Size = UDim2.new(1, 0, 0, ROW_H), BackgroundTransparency = 1, LayoutOrder = order,
	}, scroller)
	local row = Pix.button(cell, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), {
		style = style, manual = true, anchor = Vector2.new(0.5, 0.5),
	})
	local c = row.pb.content

	if back then
		Pix.arrow(c, UDim2.new(0, 16, 0.5, 0), 4, C.textDim, 4, 180)
	elseif accent then
		Pix.box(c, UDim2.new(0, 2, 0.5, 0), UDim2.fromOffset(26, 26), swatchStyle(accent), 4, Vector2.new(0, 0.5))
	end

	Pix.text(c, UDim2.new(0, 44, 0.5, 0), UDim2.new(price and 0.62 or 1, -50, 0.6, 0), {
		text = text, anchor = Vector2.new(0, 0.5), alignX = Enum.TextXAlignment.Left,
		color = back and C.textDim or C.text, max = 28, z = 4,
	})

	if price then
		coinAmount(c, UDim2.new(0.66, 0, 0.5, 0), UDim2.new(0.34, -6, 0.6, 0), 24, {
			text = format(price), anchor = Vector2.new(0, 0.5), color = C.gold, max = 28, z = 4,
		})
	end

	-- Sotto il mouse: bordino dorato e riga piu' chiara
	row.hit.MouseEnter:Connect(function()
		row.setHot(true)
		if not back then row.setStyle("hover") end
	end)
	row.hit.MouseLeave:Connect(function()
		row.setHot(false)
		row.setStyle(style)
	end)
	row.hit.MouseButton1Click:Connect(onClick)

	return row
end

-- ============================================================================
-- SCHERMATE
-- ============================================================================

local showMenu, showBuy, showSell, showQuantity, closeShop

local function refreshQty()
	local p = state.pending
	if not p then return end

	local total = p.unit * state.qty

	qtyCount.Text = tostring(state.qty)
	qtyTotal.Text = format(total)

	local tooExpensive = (not p.isSell) and total > state.money
	qtyTotal.TextColor3 = tooExpensive and C.hpRed or C.text

	-- Troppo caro: grigio ma cliccabile come prima, tanto decide il server
	confirmButton.label.main.Text = p.isSell and "SELL" or "BUY"
	confirmButton.setStyle(tooExpensive and "off" or (p.isSell and "gold" or "green"))
end

showMenu = function()
	state.mode    = "menu"
	state.pending = nil
	qtyBox.Visible = false
	showInfo(nil)
	clearList()

	listHeader.Text = "WHAT WOULD YOU LIKE?"
	say("Welcome! How can I help you today?")

	makeRow(1, "BUY",  nil, showBuy,  C.green)
	makeRow(2, "SELL", nil, showSell, C.gold)
end

showBuy = function()
	state.mode = "buy"
	qtyBox.Visible = false
	state.pending = nil
	clearList()

	listHeader.Text = "FOR SALE"
	say("Take a look at what we've got.")

	if #state.stock == 0 then
		Pix.text(scroller, nil, UDim2.new(1, 0, 0, ROW_H), {
			text = "Nothing in stock.", color = C.textDim, max = 24,
		}).holder.LayoutOrder = 1
	end

	local order = 0
	for _, itemId in ipairs(state.stock) do
		local item = ItemDatabase.Get(itemId)
		if item then
			order += 1
			local price = math.floor(item.price or 0)
			makeRow(order, item.name, price, function()
				showInfo(item)
				showQuantity(itemId, price, 99, false)
			end, item.color)
		end
	end

	order += 1
	makeRow(order, "BACK", nil, showMenu, nil, true)
end

showSell = function()
	state.mode = "sell"
	qtyBox.Visible = false
	state.pending = nil
	clearList()

	listHeader.Text = "YOUR ITEMS"
	say("Anything you'd like to part with?")

	local order = 0
	for itemId, count in pairs(state.inventory) do
		local item = ItemDatabase.Get(itemId)
		local sellable = item and count > 0
			and (item.price or 0) > 0
			and item.pocket ~= "key" and item.category ~= "key"

		if sellable then
			order += 1
			local unit = math.max(1, math.floor(item.price * state.sellRatio))
			makeRow(order, string.format("%s  x%d", item.name, count), unit, function()
				showInfo(item)
				showQuantity(itemId, unit, count, true)
			end, item.color)
		end
	end

	if order == 0 then
		Pix.text(scroller, nil, UDim2.new(1, 0, 0, ROW_H), {
			text = "You have nothing I can buy.", color = C.textDim, max = 24,
		}).holder.LayoutOrder = 1
	end

	order += 1
	makeRow(order, "BACK", nil, showMenu, nil, true)
end

showQuantity = function(itemId, unit, max, isSell)
	local item = ItemDatabase.Get(itemId)
	if not item then return end

	state.pending = { itemId = itemId, unit = unit, max = math.max(1, max), isSell = isSell }
	state.qty     = 1

	qtyBox.Visible  = true
	-- Se la barra era sparita sotto il mouse (BUY, X) il MouseLeave non e'
	-- arrivato: via il bordino dorato rimasto acceso
	for _, b in ipairs({ qtyDown, qtyUp, confirmButton, cancelButton }) do b.setHot(false) end
	pop(qtyPop)
	listHeader.Text = isSell and "SELLING" or "BUYING"
	say(item.name .. " — how many?")

	refreshQty()
end

local function stepQty(delta)
	local p = state.pending
	if not p then return end
	state.qty = math.clamp(state.qty + delta, 1, math.min(p.max, 99))
	refreshQty()
end

qtyUp.hit.MouseButton1Click:Connect(function() stepQty(1) end)
qtyDown.hit.MouseButton1Click:Connect(function() stepQty(-1) end)

cancelButton.hit.MouseButton1Click:Connect(function()
	if state.pending and state.pending.isSell then showSell() else showBuy() end
end)

confirmButton.hit.MouseButton1Click:Connect(function()
	local p = state.pending
	if not p or not Remotes.ShopAction then return end

	Remotes.ShopAction:FireServer({
		type   = p.isSell and "sell" or "buy",
		itemId = p.itemId,
		count  = state.qty,
	})
end)

-- ============================================================================
-- APERTURA / CHIUSURA
-- ============================================================================

closeShop = function()
	if not state.open then return end
	state.open    = false
	state.pending = nil

	player:SetAttribute("ShopOpen", false)
	gui.Enabled = false

	if Remotes.ShopAction then
		Remotes.ShopAction:FireServer({ type = "close" })
	end
end

local function openShop(data)
	if type(data) ~= "table" then return end

	state.open      = true
	state.shopId    = data.shopId
	state.clerk     = data.clerk or "Clerk"
	state.stock     = data.stock or {}
	state.inventory = data.inventory or {}
	state.sellRatio = data.sellRatio or 0.5

	setMoney(data.money)
	clerkName.Text = tostring(state.clerk)
	player:SetAttribute("ShopOpen", true)
	gui.Enabled = true
	closeButton.setHot(false) -- come sopra, se l'ultima volta si e' chiuso con la X
	pop(listWin.pop)

	showMenu()
end

if Remotes.ShopOpen then
	Remotes.ShopOpen.OnClientEvent:Connect(openShop)
else
	warn("[ShopClient] Remotes.ShopOpen mancante.")
end

if Remotes.ShopResult then
	Remotes.ShopResult.OnClientEvent:Connect(function(result)
		if type(result) ~= "table" then return end

		local wasSell = state.pending and state.pending.isSell

		setMoney(result.money)
		say(result.message, result.success and C.hpGreen or C.hpRed)

		if result.success then
			if wasSell then showSell() else showBuy() end
		end
	end)
end

-- L'inventario aggiornato arriva dal server dopo ogni acquisto o vendita
if Remotes.InventoryUpdate then
	Remotes.InventoryUpdate.OnClientEvent:Connect(function(inventory)
		state.inventory = inventory or {}
		if state.open and state.mode == "sell" and not state.pending then
			showSell()
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not state.open then return end
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.ButtonB then
		if state.pending then
			if state.pending.isSell then showSell() else showBuy() end
		elseif state.mode == "menu" then
			closeShop()
		else
			showMenu()
		end
	end
end)

closeButton.hit.MouseButton1Click:Connect(function()
	closeShop()
end)

player.CharacterAdded:Connect(function()
	if state.open then closeShop() end
end)
