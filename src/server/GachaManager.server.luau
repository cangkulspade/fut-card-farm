local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local CardVisualBuilder = require(ServerStorage:FindFirstChild("CardVisualBuilder"))

-- ===== Konfigurasi Gacha =====
-- Bobot dasar tiap rarity (persen). Setiap Luck Level menggeser peluang:
-- Common -3, Rare +1.5, Epic +1, Legendary +0.5 per level (maks level 20).
local BASE_WEIGHTS = {
	Common = 70,
	Rare = 22,
	Epic = 7,
	Legendary = 1,
}
local LUCK_SHIFT = {
	Common = -3,
	Rare = 1.5,
	Epic = 1,
	Legendary = 0.5,
}
local MAX_LUCK_LEVEL = 20

-- Biaya upgrade luck PROGRESIF berlipat, dimulai dari $100:
-- level 1 = $100, lalu berikutnya 1.6x lipat (dibulatkan ke 5).
local UPGRADE_BASE_COST = 100
local UPGRADE_COST_GROWTH = 1.6

local function getUpgradeCost(level)
	return math.floor((UPGRADE_BASE_COST * (UPGRADE_COST_GROWTH ^ (level - 1))) / 5 + 0.5) * 5
end

local tycoonSystem = Workspace:FindFirstChild("TycoonSystem")
local gachaMachine = tycoonSystem and tycoonSystem:FindFirstChild("CardGachaMachine")
local rollBtn = gachaMachine and gachaMachine:FindFirstChild("RollButton")
local luckPad = gachaMachine and gachaMachine:FindFirstChild("LuckUpgradePad")
local backdropBoard = gachaMachine and gachaMachine:FindFirstChild("MainBackdropBoard")
local rollPrompt = rollBtn and rollBtn:FindFirstChild("RollPrompt")
local upgradePrompt = luckPad and luckPad:FindFirstChild("UpgradePrompt")
local leftSpawn = gachaMachine and gachaMachine:FindFirstChild("LeftSpawnPoint")
local centerDisplay = gachaMachine and gachaMachine:FindFirstChild("CenterDisplayPoint")
local rightDisposal = gachaMachine and gachaMachine:FindFirstChild("RightDisposalPoint")

if not gachaMachine or not rollPrompt or not upgradePrompt or not backdropBoard
	or not leftSpawn or not centerDisplay or not rightDisposal then
	warn("GachaManager: Komponen CardGachaMachine tidak lengkap.")
	return
end

-- Rotasi murni papan belakang mesin: kartu selalu sejajar sempurna
-- dengan papan (tegak lurus, tanpa kemiringan) selama meluncur.
local machineRotation = backdropBoard.CFrame.Rotation

-- Inisialisasi atribut: Luck Level mulai dari 1, biaya upgrade mulai $100
gachaMachine:SetAttribute("LuckLevel", 1)
gachaMachine:SetAttribute("UpgradeCost", 100)

local cardsFolder = ServerStorage:FindFirstChild("Cards")
if not cardsFolder then
	warn("GachaManager: Folder ServerStorage.Cards tidak ditemukan.")
	return
end

-- Kartu yang sedang dipamerkan di tengah conveyor + data rarity-nya
local displayedCard = nil
local displayedRarity = nil
-- Kunci agar animasi tidak tumpang tindih
local animating = false

-- Hitung bobot rarity berdasarkan Luck Level saat ini
local function getWeights()
	local level = gachaMachine:GetAttribute("LuckLevel") or 1
	local weights = {}
	local total = 0
	for rarity, base in pairs(BASE_WEIGHTS) do
		local w = base + LUCK_SHIFT[rarity] * (level - 1)
		if w < 0 then w = 0 end
		weights[rarity] = w
		total += w
	end
	return weights, total
end

-- Update teks prompt upgrade sesuai level & biaya saat ini
local function updatePrompts()
	local level = gachaMachine:GetAttribute("LuckLevel") or 1
	local cost = gachaMachine:GetAttribute("UpgradeCost") or getUpgradeCost(level)
	upgradePrompt.ActionText = string.format("Upgrade Luck ($%d)", cost)
	upgradePrompt.ObjectText = string.format("Luck Level %d", level)
end

-- Fungsi mendapatkan Cash pemain dari leaderstats
local function getPlayerCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return nil end
	local cash = leaderstats:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then return cash end
	return nil
end

-- Roll rarity secara weighted random
local function rollRarity()
	local weights, total = getWeights()
	local roll = math.random() * total
	local cumulative = 0
	for rarity, w in pairs(weights) do
		cumulative += w
		if roll <= cumulative then
			return rarity
		end
	end
	return "Common"
end

-- Cari template kartu sesuai rarity
local function findTemplate(rarity)
	for _, tool in ipairs(cardsFolder:GetChildren()) do
		if tool:IsA("Tool") and tool:GetAttribute("Rarity") == rarity then
			return tool
		end
	end
	return nil
end

-- Buat visual kartu BERDIRI TEGAK vertikal (portrait) di conveyor:
-- lebar 2.8, tinggi 4.4, tebal 0.25, melayang di atas jalur rel.
local function createCardVisual(template)
	local handle = template:FindFirstChild("Handle")
	local cardColor = (handle and handle:IsA("BasePart")) and handle.Color or Color3.new(1, 1, 1)

	local visual = Instance.new("Part")
	visual.Name = "GachaCardVisual"
	-- Bentuk PORTRAIT 1.5x: lebar 4.2, tinggi 6.6, tebal 0.3
	visual.Size = Vector3.new(4.2, 6.6, 0.3)
	visual.Color = cardColor
	visual.Material = Enum.Material.SmoothPlastic
	visual.Anchored = true
	visual.CanCollide = false
	-- Gaya kartu koleksi: bingkai neon + lencana rarity
	CardVisualBuilder.apply(visual, template:GetAttribute("Rarity") or "Common")
	-- Posisi awal di LeftSpawnPoint, orientasi dikunci ke rotasi papan mesin
	visual.CFrame = CFrame.new(leftSpawn.Position) * machineRotation
	visual.Parent = gachaMachine
	return visual
end

-- ===== RollButton: roll gacha gratis dengan auto-discard =====
rollPrompt.Triggered:Connect(function(player)
	if animating then return end

	local rarity = rollRarity()
	local template = findTemplate(rarity)
	if not template then
		warn("GachaManager: Template kartu rarity " .. rarity .. " tidak ditemukan.")
		return
	end

	local newCard = createCardVisual(template)
	if not newCard then return end

	animating = true

	-- AUTO-DISCARD: kartu lama di tengah meluncur ke lorong pembuangan kanan
	local oldCard = displayedCard
	displayedCard = nil
	displayedRarity = nil
	if oldCard and oldCard.Parent then
		local prompt = oldCard:FindFirstChildOfClass("ProximityPrompt")
		if prompt then prompt:Destroy() end
		local disposeTween = TweenService:Create(
			oldCard,
			TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{CFrame = CFrame.new(rightDisposal.Position) * machineRotation}
		)
		disposeTween:Play()
		disposeTween.Completed:Once(function()
			if oldCard.Parent then
				oldCard:Destroy()
			end
		end)
	end

	-- Kartu baru meluncur penuh dari lorong kiri ke tengah
	local enterTween = TweenService:Create(
		newCard,
		TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{CFrame = CFrame.new(centerDisplay.Position) * machineRotation}
	)
	enterTween:Play()
	enterTween.Completed:Once(function()
		animating = false

		if newCard.Parent then
			local takePrompt = Instance.new("ProximityPrompt")
			takePrompt.Name = "TakePrompt"
			takePrompt.ActionText = "Ambil Kartu"
			takePrompt.ObjectText = rarity .. " Card"
			takePrompt.HoldDuration = 0.15
			takePrompt.MaxActivationDistance = 11
			takePrompt.RequiresLineOfSight = false
			takePrompt.UIOffset = Vector2.new(0, -35)
			takePrompt.Parent = newCard

			takePrompt.Triggered:Connect(function(taker)
				if displayedCard ~= newCard then return end

				local realTemplate = findTemplate(displayedRarity or rarity)
				if realTemplate then
					local clonedCard = realTemplate:Clone()

				-- Pastikan atribut CashPerSecond & Rarity selalu tersalin
				if clonedCard:GetAttribute("CashPerSecond") == nil then
					clonedCard:SetAttribute("CashPerSecond", realTemplate:GetAttribute("CashPerSecond") or 15)
				end
				if clonedCard:GetAttribute("Rarity") == nil then
					clonedCard:SetAttribute("Rarity", displayedRarity or rarity or "Common")
				end

					-- Pastikan Handle kartu yang dipegang punya visual lengkap
				-- (bingkai neon + lencana rarity di sisi depan & belakang)
					local clonedHandle = clonedCard:FindFirstChild("Handle")
				if clonedHandle and clonedHandle:IsA("BasePart")
					and not clonedHandle:FindFirstChild("CardFaceGui_Front") then
					CardVisualBuilder.apply(clonedHandle, displayedRarity or rarity)
				end

					clonedCard.Parent = taker:FindFirstChild("Backpack")

					local character = taker.Character
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid:EquipTool(clonedCard)
					end
				end

				if newCard.Parent then
					newCard:Destroy()
				end
				displayedCard = nil
				displayedRarity = nil
			end)

			displayedCard = newCard
			displayedRarity = rarity
			-- Kartu DIAM TOTAL (100% statis) begitu tiba di tengah mesin.
		end
		end)
end)

-- ===== LuckUpgradePad: upgrade luck dengan harga berlipat =====
upgradePrompt.Triggered:Connect(function(player)
	local luckLevel = gachaMachine:GetAttribute("LuckLevel") or 1
	local currentUpgradeCost = gachaMachine:GetAttribute("UpgradeCost") or getUpgradeCost(luckLevel)

	if luckLevel >= MAX_LUCK_LEVEL then
		return
	end

	local cash = getPlayerCash(player)
	if not cash then return end

	if cash.Value < currentUpgradeCost then
		return
	end

	-- Kurangi Cash, naikkan luckLevel, hitung ulang biaya upgrade berikutnya
	cash.Value -= currentUpgradeCost
	local newLevel = luckLevel + 1
	gachaMachine:SetAttribute("LuckLevel", newLevel)
	gachaMachine:SetAttribute("UpgradeCost", getUpgradeCost(newLevel))
	updatePrompts()
end)

updatePrompts()