--[[
	Crea gli Accessory R6 degli zaini.

	Uso (Roblox Studio):
	  1. Importa con il 3D Importer i file zaino2_accessory.fbx ... zaino5_accessory.fbx
	     (Scale Unit / File Dimensions: "Stud").
	  2. Lascia i modelli importati in Workspace.
	  3. Incolla questo script nella Command Bar (View > Command Bar) e premi Invio.

	Risultato: ReplicatedStorage.Zaini contiene gli Accessory "Zaino2" ... "Zaino5",
	pronti per Humanoid:AddAccessory() su un personaggio R6 (si agganciano al
	BodyBackAttachment del Torso).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dati calcolati in Blender: dimensione del mesh (stud) e posizione del suo centro
-- rispetto al centro del Torso R6 (spazio Roblox: X destra, Y su, Z dietro).
local ZAINI = {
	Zaino2 = { size = Vector3.new(1.7703, 1.9, 1.4762), center = Vector3.new(0, 0.05, 0.5916) },
	Zaino3 = { size = Vector3.new(2.1, 1.0321, 1.6033), center = Vector3.new(0, -0.35, 0.5603) },
	Zaino4 = { size = Vector3.new(2.138, 1.9, 1.4955), center = Vector3.new(0, 0.05, 0.791) },
	Zaino5 = { size = Vector3.new(1.8641, 1.9, 2.0473), center = Vector3.new(0, 0.05, 0.8111) },
}

-- Posizione del BodyBackAttachment sul Torso R6
local BODY_BACK = Vector3.new(0, 0, 0.5)

local folder = ReplicatedStorage:FindFirstChild("Zaini") or Instance.new("Folder")
folder.Name = "Zaini"
folder.Parent = ReplicatedStorage

for name, data in pairs(ZAINI) do
	local mesh = workspace:FindFirstChild(name .. "Handle", true)
	if not (mesh and mesh:IsA("MeshPart")) then
		warn("MeshPart non trovato: " .. name .. "Handle (hai importato " .. name:lower() .. "_accessory.fbx?)")
		continue
	end

	local old = folder:FindFirstChild(name)
	if old then
		old:Destroy()
	end

	local handle = mesh:Clone()
	handle.Name = "Handle"
	handle.Size = data.size
	handle.Anchored = false
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CFrame = CFrame.new()

	local attachment = Instance.new("Attachment")
	attachment.Name = "BodyBackAttachment"
	attachment.Position = BODY_BACK - data.center
	attachment.Parent = handle

	local accessory = Instance.new("Accessory")
	accessory.Name = name
	accessory.AccessoryType = Enum.AccessoryType.Back
	handle.Parent = accessory
	accessory.Parent = folder

	print("Creato accessorio " .. name)
end
