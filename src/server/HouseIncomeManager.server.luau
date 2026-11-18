local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local CardVisualBuilder = require(ServerStorage:FindFirstChild("CardVisualBuilder"))

local tycoonSystem = Workspace:FindFirstChild("TycoonSystem")
local openBase = tycoonSystem and tycoonSystem:FindFirstChild("OpenBase")
local cardSlotsFolder = openBase and openBase:FindFirstChild("CardSlots")

if not cardSlotsFolder then
	warn("HouseIncomeManager: Folder CardSlots tidak ditemukan di Workspace.TycoonSystem.OpenBase.")
	return
end

-- ===== Konfigurasi =====
local MAX_CARD_LEVEL = 50

-- Fallback penghasilan berdasarkan nama kartu (jika atribut kosong)
local NAME_INCOME_FALLBACK = {
	CommonCard = 15,
	RareCard = 45,
	EpicCard = 120,
	LegendaryCard = 350,
}
local NAME_RARITY_FALLBACK = {
	CommonCard = "Common",
	RareCard = "Rare",
	EpicCard = "Epic",
	LegendaryCard = "Legendary",
}

-- Biaya upgrade: minimal $50, skala dengan penghasilan dasar dan level kartu
local function getUpgradeCost(baseIncome, level)
	return math.max(50, math.floor(baseIncome * 3 * level))
end

-- Penghasilan kartu: penghasilan dasar dikali level kartu (Lv.50 = 50x lipat)
local function getCurrentIncome(baseIncome, level)
	return math.floor(baseIncome * level + 0.5)
end

-- Pemilik kartu per slot (untuk menambahkan income ke Cash-nya)
local slotOwners = {}

-- Fungsi menambah Cash ke leaderstats pemain
local function addCash(player, amount)
	if not player then return end
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end
	local cash = leaderstats:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then
		cash.Value += amount
	end
end

-- Ambil semua panel upgrade (depan & belakang) dari sebuah slot
local function getPanels(slot)
	local panels = {}
	for _, child in ipairs(slot:GetDescendants()) do
		if child:IsA("BasePart") and (child.Name == "UpgradePanel" or child.Name == "BackUpgradePanel") then
			table.insert(panels, child)
		end
	end
	return panels
end

-- Update teks semua panel upgrade
local function updatePanelLabels(slot)
	for _, panel in ipairs(getPanels(slot)) do
		local gui = panel:FindFirstChild("PanelGui")
		local label = gui and gui:FindFirstChild("PanelLabel")
		if label then
			if slot:GetAttribute("IsOccupied") then
				local level = slot:GetAttribute("CardLevel") or 1
				local cost = slot:GetAttribute("UpgradeCost") or 0
				if level >= MAX_CARD_LEVEL then
					label.Text = "MAX Lv 50"
					label.TextColor3 = Color3.fromRGB(255, 215, 60)
				else
					label.Text = string.format("Lv.%d / $%d", level, cost)
					label.TextColor3 = Color3.new(1, 1, 1)
				end
			else
				label.Text = "SLOT KOSONG"
				label.TextColor3 = Color3.new(1, 1, 1)
			end
		end
	end
end

-- Update teks billboard informasi di atas kartu
local function updateCardBillboard(slot)
	local displayed = slot:FindFirstChild("DisplayedCard", true)
	local billboard = displayed and displayed:FindFirstChild("CardInfo")
	local infoLabel = billboard and billboard:FindFirstChild("InfoLabel")
	if not infoLabel then return end

	local rarity = slot:GetAttribute("Rarity") or "?"
	local level = slot:GetAttribute("CardLevel") or 1
	local income = slot:GetAttribute("CurrentIncome") or 0
	infoLabel.Text = string.format("%s Lv.%d  +$%d/s", rarity, level, income)
end

-- Setup satu slot: mendukung Model pedestal maupun BasePart tunggal
local function setupSlot(slot)
	-- Tentukan bagian dudukan utama (topPart)
	local topPart
	if slot:IsA("Model") then
		topPart = slot:FindFirstChild("PedestalTop")
			or (slot.PrimaryPart and slot.PrimaryPart:IsA("BasePart") and slot.PrimaryPart)
			or slot:FindFirstChildWhichIsA("BasePart")
	elseif slot:IsA("BasePart") then
		topPart = slot
	end
	if not topPart then
		warn("HouseIncomeManager: Slot " .. slot.Name .. " tidak punya dudukan BasePart.")
		return
	end

	-- Cari prompt penempatan secara rekursif: bernama PlacePrompt,
	-- atau ProximityPrompt pertama yang bukan UpgradeCardPrompt
	local placePrompt = slot:FindFirstChild("PlacePrompt", true)
	if not placePrompt or not placePrompt:IsA("ProximityPrompt") then
		for _, desc in ipairs(slot:GetDescendants()) do
			if desc:IsA("ProximityPrompt") and desc.Name ~= "UpgradeCardPrompt" then
				placePrompt = desc
				break
			end
		end
	end
	if not placePrompt then
		warn("HouseIncomeManager: Slot " .. slot.Name .. " tidak punya PlacePrompt.")
		return
	end

	-- Pastikan prompt siap dipicu saat slot kosong
	if slot:GetAttribute("IsOccupied") ~= true then
		placePrompt.Enabled = true
	end
	placePrompt.RequiresLineOfSight = false
	placePrompt.MaxActivationDistance = 10

	placePrompt.Triggered:Connect(function(player)
		-- Slot harus kosong
		if slot:GetAttribute("IsOccupied") == true then
			warn("Slot " .. slot.Name .. " sudah terisi kartu!")
			return
		end

		-- Pemain harus memegang Tool
		local character = player.Character
		local equippedTool = character and character:FindFirstChildWhichIsA("Tool")
		if not equippedTool then
			warn("Pemain harus memegang kartu untuk menaruhnya!")
			return
		end

		-- Baca atribut, dengan fallback berdasarkan nama kartu agar tidak pernah gagal
		local income = equippedTool:GetAttribute("CashPerSecond")
		local rarity = equippedTool:GetAttribute("Rarity")
		if income == nil then
			income = NAME_INCOME_FALLBACK[equippedTool.Name] or 15
			warn("HouseIncomeManager: CashPerSecond kosong pada " .. equippedTool.Name .. ", memakai fallback " .. income)
		end
		if rarity == nil then
			rarity = NAME_RARITY_FALLBACK[equippedTool.Name] or "Common"
		end

		local handle = equippedTool:FindFirstChild("Handle")

		-- Simpan data kartu ke atribut slot
		slot:SetAttribute("IsOccupied", true)
		slot:SetAttribute("BaseIncome", income)
		slot:SetAttribute("CurrentIncome", income)
		slot:SetAttribute("CardLevel", 1)
		slot:SetAttribute("UpgradeCost", getUpgradeCost(income, 1))
		slot:SetAttribute("Rarity", rarity)

		-- Matikan prompt penempatan, aktifkan semua prompt upgrade
		placePrompt.Enabled = false
		for _, panel in ipairs(getPanels(slot)) do
			local prompt = panel:FindFirstChild("UpgradeCardPrompt")
			if prompt then
				prompt.Enabled = true
			end
		end
		slotOwners[slot] = player

		-- Visual kartu berdiri vertikal statis di atas dudukan,
		-- menghadap lorong tengah lantai (X = 0)
		if handle and handle:IsA("BasePart") then
			local displayCard = Instance.new("Part")
			displayCard.Name = "DisplayedCard"
			displayCard.Size = Vector3.new(5.6, 8.8, 0.35)
			displayCard.Color = handle.Color
			displayCard.Material = Enum.Material.SmoothPlastic
			displayCard.Anchored = true
			displayCard.CanCollide = false

			local cardPos = topPart.Position + Vector3.new(0, (topPart.Size.Y / 2) + 5.9, 0)
			displayCard.CFrame = CFrame.lookAt(cardPos, Vector3.new(0, cardPos.Y, cardPos.Z))
			displayCard.Parent = slot

			-- Gaya kartu koleksi: bingkai neon + lencana rarity (depan & belakang)
			CardVisualBuilder.apply(displayCard, rarity)

			-- BillboardGui informasi pendapatan
			local billboard = Instance.new("BillboardGui")
			billboard.Name = "CardInfo"
			billboard.AlwaysOnTop = true
			billboard.StudsOffset = Vector3.new(0, 5.2, 0)
			billboard.Size = UDim2.new(0, 150, 0, 42)
			billboard.Parent = displayCard

			local infoLabel = Instance.new("TextLabel")
			infoLabel.Name = "InfoLabel"
			infoLabel.Size = UDim2.new(1, 0, 1, 0)
			infoLabel.BackgroundTransparency = 1
			infoLabel.Font = Enum.Font.GothamBold
			infoLabel.TextScaled = true
			infoLabel.TextColor3 = Color3.new(1, 1, 1)
			infoLabel.TextStrokeTransparency = 0.35
			infoLabel.Text = string.format("%s Lv.1  +$%d/s", rarity, income)
			infoLabel.Parent = billboard
		end

		updatePanelLabels(slot)

		-- Hancurkan Tool dari tangan pemain setelah kartu visual muncul
		equippedTool:Destroy()
	end)

	-- Upgrade kartu: dipicu dari panel depan maupun belakang
	for _, panel in ipairs(getPanels(slot)) do
		local prompt = panel:FindFirstChild("UpgradeCardPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				if not slot:GetAttribute("IsOccupied") then return end

				local level = slot:GetAttribute("CardLevel") or 1
				if level >= MAX_CARD_LEVEL then return end

				local cost = slot:GetAttribute("UpgradeCost") or 0
				local leaderstats = player:FindFirstChild("leaderstats")
				local cash = leaderstats and leaderstats:FindFirstChild("Cash")
				if not cash or not cash:IsA("IntValue") or cash.Value < cost then
					return
				end

				cash.Value -= cost
				local newLevel = level + 1
				local base = slot:GetAttribute("BaseIncome") or 0
				slot:SetAttribute("CardLevel", newLevel)
				slot:SetAttribute("CurrentIncome", getCurrentIncome(base, newLevel))
				slot:SetAttribute("UpgradeCost", getUpgradeCost(base, newLevel))

				updatePanelLabels(slot)
				updateCardBillboard(slot)
			end)
		end
	end
end

-- Setup semua slot yang ada
for _, slot in ipairs(cardSlotsFolder:GetChildren()) do
	task.spawn(setupSlot, slot)
end

-- Handle slot yang ditambahkan di kemudian hari
cardSlotsFolder.ChildAdded:Connect(setupSlot)

-- Loop income: setiap 1 detik, tambahkan CurrentIncome tiap slot ke Cash pemiliknya
task.spawn(function()
	while true do
		task.wait(1)

		for slot, owner in pairs(slotOwners) do
			local income = slot:GetAttribute("CurrentIncome")
			if income and income > 0 then
				-- Pastikan pemain masih ada di server
				if owner.Parent then
					addCash(owner, income)
				else
				slotOwners[slot] = nil
				end
				end
			end
		end
	end)