--[[
	ShopClient.client.lua
	Percorso: StarterPlayer/StarterPlayerScripts/ShopClient  (LocalScript)

	GUI del negozio in stile Poké Mart:
	  - box messaggi del commesso in basso
	  - menu BUY / SELL / EXIT
	  - lista articoli con prezzo, descrizione dell'articolo selezionato
	  - barra quantita' con pulsante BUY/SELL esplicito

	Tutto in scale, niente offset.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes      = require(ReplicatedStorage:WaitForChild("Remotes"))
local ItemDatabase = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ItemDatabase"))

local BOX_IMAGE = "rbxassetid://105630568407213"
local SYMBOL    = "₽"

local C = {
	panel   = Color3.fromRGB(250, 250, 252),
	row     = Color3.fromRGB(238, 240, 248),
	rowHov  = Color3.fromRGB(220, 228, 250),
	line    = Color3.fromRGB(52, 58, 78),
	text    = Color3.fromRGB(28, 30, 42),
	textDim = Color3.fromRGB(112, 120, 146),
	gold    = Color3.fromRGB(246, 196, 62),
	green   = Color3.fromRGB(46, 168, 96),
	red     = Color3.fromRGB(206, 62, 54),
	off     = Color3.fromRGB(150, 155, 175),
}

local function format(amount)
	local s = tostring(math.floor(tonumber(amount) or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(r or 0.18, 0)
	c.Parent = parent
	return c
end

local function outline(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color        = color or C.line
	s.Thickness    = thickness or 2
	s.Transparency = 0.2
	s.Parent       = parent
	return s
end

local function label(parent, text, opts)
	opts = opts or {}
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size           = opts.size or UDim2.fromScale(1, 1)
	l.Position       = opts.pos or UDim2.new()
	l.AnchorPoint    = opts.anchor or Vector2.new(0, 0)
	l.Font           = opts.font or Enum.Font.GothamMedium
	l.TextColor3     = opts.color or C.text
	l.TextScaled     = true
	l.Text           = text or ""
	l.TextXAlignment = opts.align or Enum.TextXAlignment.Left
	l.TextYAlignment = opts.valign or Enum.TextYAlignment.Center
	l.Parent         = parent

	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 8
	limit.MaxTextSize = opts.maxSize or 20
	limit.Parent      = l

	return l
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
gui.Parent         = playerGui

local dim = Instance.new("Frame")
dim.Size                   = UDim2.fromScale(1, 1)
dim.BackgroundColor3       = Color3.fromRGB(6, 8, 16)
dim.BackgroundTransparency = 0.5
dim.BorderSizePixel        = 0
dim.Parent                 = gui

-- --------------------------------------------------------- SOLDI (alto destra)
local moneyBox = Instance.new("Frame")
moneyBox.AnchorPoint      = Vector2.new(1, 0)
moneyBox.Size             = UDim2.fromScale(0.20, 0.075)
moneyBox.Position         = UDim2.fromScale(0.975, 0.03)
moneyBox.BackgroundColor3 = C.panel
moneyBox.BorderSizePixel  = 0
moneyBox.Parent           = gui
corner(moneyBox, 0.22)
outline(moneyBox)

label(moneyBox, "MONEY", {
	size = UDim2.fromScale(0.5, 0.34), pos = UDim2.fromScale(0.07, 0.14),
	font = Enum.Font.GothamBold, color = C.textDim, maxSize = 13,
})

local moneyValue = label(moneyBox, SYMBOL .. " 0", {
	size = UDim2.fromScale(0.86, 0.42), pos = UDim2.fromScale(0.93, 0.62),
	anchor = Vector2.new(1, 0.5), font = Enum.Font.FredokaOne,
	align = Enum.TextXAlignment.Right, maxSize = 26,
})

-- Chiusura in alto a destra, sopra il box dei soldi
local closeButton = Instance.new("TextButton")
closeButton.Name             = "CloseShop"
closeButton.AnchorPoint      = Vector2.new(1, 0)
closeButton.Size             = UDim2.fromScale(0.045, 0.075)
closeButton.Position         = UDim2.fromScale(0.975, 0.115)
closeButton.BackgroundColor3 = C.panel
closeButton.Text             = ""
closeButton.AutoButtonColor  = false
closeButton.ZIndex           = 5
closeButton.Parent           = gui
corner(closeButton, 1)

local closeRatio = Instance.new("UIAspectRatioConstraint")
closeRatio.AspectRatio = 1
closeRatio.Parent      = closeButton

local closeStroke = outline(closeButton, C.line, 2)

local closeIcon = label(closeButton, "✕", {
	font = Enum.Font.GothamBold, color = C.textDim,
	align = Enum.TextXAlignment.Center, maxSize = 30,
})
closeIcon.ZIndex = 6

local closeScale = Instance.new("UIScale")
closeScale.Parent = closeButton

closeButton.MouseEnter:Connect(function()
	TweenService:Create(closeScale, TweenInfo.new(0.12), { Scale = 1.12 }):Play()
	TweenService:Create(closeButton, TweenInfo.new(0.12), { BackgroundColor3 = C.red }):Play()
	closeIcon.TextColor3   = Color3.new(1, 1, 1)
	closeStroke.Color      = C.red
end)
closeButton.MouseLeave:Connect(function()
	TweenService:Create(closeScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	TweenService:Create(closeButton, TweenInfo.new(0.12), { BackgroundColor3 = C.panel }):Play()
	closeIcon.TextColor3   = C.textDim
	closeStroke.Color      = C.line
end)

-- ---------------------------------------------------------- LISTA (destra)
local listPanel = Instance.new("Frame")
listPanel.AnchorPoint      = Vector2.new(1, 0)
listPanel.Size             = UDim2.fromScale(0.40, 0.56)
listPanel.Position         = UDim2.fromScale(0.975, 0.125)
listPanel.BackgroundColor3 = C.panel
listPanel.BorderSizePixel  = 0
listPanel.Parent           = gui
corner(listPanel, 0.05)
outline(listPanel)

local listHeader = label(listPanel, "", {
	size = UDim2.fromScale(0.88, 0.09), pos = UDim2.fromScale(0.06, 0.03),
	font = Enum.Font.GothamBold, color = C.textDim, maxSize = 14,
})

local scroller = Instance.new("ScrollingFrame")
scroller.Size                   = UDim2.fromScale(0.9, 0.83)
scroller.Position               = UDim2.fromScale(0.05, 0.13)
scroller.BackgroundTransparency = 1
scroller.BorderSizePixel        = 0
scroller.ScrollBarThickness     = 4
scroller.ScrollBarImageColor3   = C.line
scroller.AutomaticCanvasSize    = Enum.AutomaticSize.Y
scroller.CanvasSize             = UDim2.new()
scroller.Parent                 = listPanel

local scrollLayout = Instance.new("UIListLayout")
scrollLayout.Padding   = UDim.new(0.012, 0)
scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
scrollLayout.Parent    = scroller

-- ------------------------------------------------------- DESCRIZIONE (sx)
local infoPanel = Instance.new("Frame")
infoPanel.Size             = UDim2.fromScale(0.44, 0.30)
infoPanel.Position         = UDim2.fromScale(0.025, 0.40)
infoPanel.BackgroundColor3 = C.panel
infoPanel.BorderSizePixel  = 0
infoPanel.Visible          = false
infoPanel.Parent           = gui
corner(infoPanel, 0.08)
outline(infoPanel)

local infoDot = Instance.new("Frame")
infoDot.Size             = UDim2.fromScale(0.11, 0.22)
infoDot.Position         = UDim2.fromScale(0.06, 0.12)
infoDot.BackgroundColor3 = C.gold
infoDot.BorderSizePixel  = 0
infoDot.Parent           = infoPanel
corner(infoDot, 1)

local infoRatio = Instance.new("UIAspectRatioConstraint")
infoRatio.AspectRatio = 1
infoRatio.Parent      = infoDot

local infoName = label(infoPanel, "", {
	size = UDim2.fromScale(0.68, 0.16), pos = UDim2.fromScale(0.21, 0.13),
	font = Enum.Font.FredokaOne, maxSize = 22,
})

local infoDesc = label(infoPanel, "", {
	size = UDim2.fromScale(0.88, 0.5), pos = UDim2.fromScale(0.06, 0.4),
	color = C.textDim, valign = Enum.TextYAlignment.Top, maxSize = 15,
})
infoDesc.TextWrapped = true

-- ---------------------------------------------------------- MESSAGGI (basso)
local msgBox = Instance.new("Frame")
msgBox.BackgroundColor3       = Color3.new(1, 1, 1)
msgBox.BackgroundTransparency = 0
msgBox.BorderSizePixel        = 0
msgBox.AnchorPoint            = Vector2.new(0, 1)
msgBox.Size                   = UDim2.fromScale(0.52, 0.21)
msgBox.Position               = UDim2.fromScale(0.025, 0.965)
msgBox.Parent                 = gui
corner(msgBox, 0.14)

local msgStroke = Instance.new("UIStroke")
msgStroke.Color           = Color3.new(0, 0, 0)
msgStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
msgStroke.Thickness       = 3
msgStroke.Parent          = msgBox

msgBox:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	msgStroke.Thickness = math.max(2, msgBox.AbsoluteSize.Y * 0.035)
end)

local msgPad = Instance.new("UIPadding")
msgPad.PaddingLeft   = UDim.new(0.055, 0)
msgPad.PaddingRight  = UDim.new(0.055, 0)
msgPad.PaddingTop    = UDim.new(0.17, 0)
msgPad.PaddingBottom = UDim.new(0.16, 0)
msgPad.Parent        = msgBox

local msgText = label(msgBox, "", {
	valign = Enum.TextYAlignment.Top, color = Color3.new(0, 0, 0), maxSize = 20,
})
msgText.TextWrapped = true

-- ------------------------------------------------------ BARRA QUANTITÀ
local qtyBox = Instance.new("Frame")
qtyBox.AnchorPoint      = Vector2.new(1, 1)
qtyBox.Size             = UDim2.fromScale(0.44, 0.15)
qtyBox.Position         = UDim2.fromScale(0.975, 0.965)
qtyBox.BackgroundColor3 = C.panel
qtyBox.BorderSizePixel  = 0
qtyBox.Visible          = false
qtyBox.Parent           = gui
corner(qtyBox, 0.12)
outline(qtyBox)

local function stepButton(text, xPos)
	local b = Instance.new("TextButton")
	b.AnchorPoint      = Vector2.new(0.5, 0.5)
	b.Size             = UDim2.fromScale(0.085, 0.5)
	b.Position         = UDim2.fromScale(xPos, 0.5)
	b.BackgroundColor3 = C.row
	b.Text             = text
	b.TextColor3       = C.text
	b.TextScaled       = true
	b.Font             = Enum.Font.GothamBold
	b.AutoButtonColor  = false
	b.Parent           = qtyBox
	corner(b, 0.3)
	outline(b, C.line, 1)

	b.MouseEnter:Connect(function() b.BackgroundColor3 = C.rowHov end)
	b.MouseLeave:Connect(function() b.BackgroundColor3 = C.row end)
	return b
end

local qtyDown = stepButton("−", 0.075)
local qtyUp   = stepButton("+", 0.30)

local qtyCount = label(qtyBox, "1", {
	size = UDim2.fromScale(0.12, 0.5), pos = UDim2.fromScale(0.1875, 0.5),
	anchor = Vector2.new(0.5, 0.5), font = Enum.Font.FredokaOne,
	align = Enum.TextXAlignment.Center, maxSize = 30,
})

local qtyTotal = label(qtyBox, SYMBOL .. " 0", {
	size = UDim2.fromScale(0.22, 0.42), pos = UDim2.fromScale(0.50, 0.5),
	anchor = Vector2.new(0.5, 0.5), font = Enum.Font.FredokaOne,
	align = Enum.TextXAlignment.Center, maxSize = 24,
})

local confirmButton = Instance.new("TextButton")
confirmButton.AnchorPoint      = Vector2.new(0.5, 0.5)
confirmButton.Size             = UDim2.fromScale(0.26, 0.58)
confirmButton.Position         = UDim2.fromScale(0.76, 0.5)
confirmButton.BackgroundColor3 = C.green
confirmButton.Text             = "BUY"
confirmButton.TextColor3       = Color3.new(1, 1, 1)
confirmButton.TextScaled       = true
confirmButton.Font             = Enum.Font.FredokaOne
confirmButton.AutoButtonColor  = false
confirmButton.Parent           = qtyBox
corner(confirmButton, 0.28)

local confirmLimit = Instance.new("UITextSizeConstraint")
confirmLimit.MinTextSize = 10
confirmLimit.MaxTextSize = 24
confirmLimit.Parent      = confirmButton

local confirmScale = Instance.new("UIScale")
confirmScale.Parent = confirmButton

confirmButton.MouseEnter:Connect(function()
	TweenService:Create(confirmScale, TweenInfo.new(0.12), { Scale = 1.06 }):Play()
end)
confirmButton.MouseLeave:Connect(function()
	TweenService:Create(confirmScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
end)

local cancelButton = Instance.new("TextButton")
cancelButton.AnchorPoint      = Vector2.new(0.5, 0.5)
cancelButton.Size             = UDim2.fromScale(0.08, 0.4)
cancelButton.Position         = UDim2.fromScale(0.945, 0.5)
cancelButton.BackgroundColor3 = C.row
cancelButton.Text             = "✕"
cancelButton.TextColor3       = C.textDim
cancelButton.TextScaled       = true
cancelButton.Font             = Enum.Font.GothamBold
cancelButton.AutoButtonColor  = false
cancelButton.Parent           = qtyBox
corner(cancelButton, 1)

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
	msgText.TextColor3 = color or Color3.new(0, 0, 0)
end

local function setMoney(amount)
	state.money = math.floor(tonumber(amount) or 0)
	moneyValue.Text = SYMBOL .. " " .. format(state.money)
end

local function clearList()
	for _, child in ipairs(scroller:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end
	end
end

local function showInfo(item)
	if not item then
		infoPanel.Visible = false
		return
	end
	infoPanel.Visible        = true
	infoDot.BackgroundColor3 = item.color or C.gold
	infoName.Text            = item.name
	infoDesc.Text            = item.description or ""
end

-- Riga della lista. price = nil per le voci di menu.
local function makeRow(order, text, price, onClick, accent)
	local row = Instance.new("TextButton")
	row.Size             = UDim2.new(1, 0, 0.145, 0)
	row.BackgroundColor3 = C.row
	row.Text             = ""
	row.AutoButtonColor  = false
	row.LayoutOrder      = order
	row.Parent           = scroller
	corner(row, 0.22)
	local rowStroke = outline(row, C.line, 1)
	rowStroke.Transparency = 0.7

	if accent then
		local bar = Instance.new("Frame")
		bar.Size             = UDim2.fromScale(0.014, 0.62)
		bar.Position         = UDim2.fromScale(0.025, 0.5)
		bar.AnchorPoint      = Vector2.new(0, 0.5)
		bar.BackgroundColor3 = accent
		bar.BorderSizePixel  = 0
		bar.Parent           = row
		corner(bar, 1)
	end

	label(row, text, {
		size = UDim2.fromScale(price and 0.6 or 0.85, 0.55),
		pos = UDim2.fromScale(0.06, 0.5), anchor = Vector2.new(0, 0.5),
		font = Enum.Font.FredokaOne, maxSize = 20,
	})

	if price then
		label(row, SYMBOL .. " " .. format(price), {
			size = UDim2.fromScale(0.34, 0.5), pos = UDim2.fromScale(0.94, 0.5),
			anchor = Vector2.new(1, 0.5), font = Enum.Font.GothamBold,
			align = Enum.TextXAlignment.Right, color = C.textDim, maxSize = 18,
		})
	end

	row.MouseEnter:Connect(function()
		row.BackgroundColor3 = C.rowHov
		rowStroke.Transparency = 0.1
	end)
	row.MouseLeave:Connect(function()
		row.BackgroundColor3 = C.row
		rowStroke.Transparency = 0.7
	end)
	row.MouseButton1Click:Connect(onClick)

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
	qtyTotal.Text = SYMBOL .. " " .. format(total)

	local tooExpensive = (not p.isSell) and total > state.money
	qtyTotal.TextColor3 = tooExpensive and C.red or C.text

	confirmButton.Text = p.isSell and "SELL" or "BUY"
	confirmButton.BackgroundColor3 = tooExpensive and C.off
		or (p.isSell and C.gold or C.green)
	confirmButton.TextColor3 = p.isSell and Color3.fromRGB(60, 45, 10) or Color3.new(1, 1, 1)
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
		label(scroller, "Nothing in stock.", {
			size = UDim2.new(1, 0, 0.15, 0), align = Enum.TextXAlignment.Center,
			color = C.textDim, maxSize = 17,
		}).LayoutOrder = 1
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
	makeRow(order, "← BACK", nil, showMenu, C.textDim)
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
		label(scroller, "You have nothing I can buy.", {
			size = UDim2.new(1, 0, 0.15, 0), align = Enum.TextXAlignment.Center,
			color = C.textDim, maxSize = 17,
		}).LayoutOrder = 1
	end

	order += 1
	makeRow(order, "← BACK", nil, showMenu, C.textDim)
end

showQuantity = function(itemId, unit, max, isSell)
	local item = ItemDatabase.Get(itemId)
	if not item then return end

	state.pending = { itemId = itemId, unit = unit, max = math.max(1, max), isSell = isSell }
	state.qty     = 1

	qtyBox.Visible  = true
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

qtyUp.MouseButton1Click:Connect(function() stepQty(1) end)
qtyDown.MouseButton1Click:Connect(function() stepQty(-1) end)

cancelButton.MouseButton1Click:Connect(function()
	if state.pending and state.pending.isSell then showSell() else showBuy() end
end)

confirmButton.MouseButton1Click:Connect(function()
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
	player:SetAttribute("ShopOpen", true)
	gui.Enabled = true

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
		say(result.message, result.success and C.green or C.red)

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

closeButton.MouseButton1Click:Connect(function()
	closeShop()
end)

player.CharacterAdded:Connect(function()
	if state.open then closeShop() end
end)
