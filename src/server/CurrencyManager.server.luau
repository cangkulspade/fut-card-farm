local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local cashStore = DataStoreService:GetDataStore("PlayerCash_V1")
local STARTING_CASH = 100

-- Muat data Cash pemain dari DataStore (dengan pcall agar aman jika gagal)
local function loadCash(player)
	local success, savedCash = pcall(function()
		return cashStore:GetAsync("Cash_" .. player.UserId)
	end)

	if success and typeof(savedCash) == "number" then
		return math.floor(savedCash)
	end

	if not success then
		warn("Gagal memuat data Cash untuk " .. player.Name .. ", menggunakan nilai awal.")
	end

	return STARTING_CASH
end

-- Simpan data Cash pemain ke DataStore (dengan pcall agar aman jika gagal)
local function saveCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	local cash = leaderstats:FindFirstChild("Cash")
	if not cash then
		return
	end

	local success, err = pcall(function()
		cashStore:SetAsync("Cash_" .. player.UserId, cash.Value)
	end)

	if not success then
		warn("Gagal menyimpan data Cash untuk " .. player.Name .. ": " .. tostring(err))
	end
end

local function onPlayerAdded(player)
	-- Buat folder leaderstats di dalam Player
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	-- Buat IntValue Cash dengan nilai awal (atau nilai tersimpan jika ada)
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = loadCash(player)
	cash.Parent = leaderstats
end

local function onPlayerRemoving(player)
	saveCash(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Simpan semua pemain saat server ditutup
game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		saveCash(player)
	end
end)

-- Tangani pemain yang sudah ada saat script dimulai
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end