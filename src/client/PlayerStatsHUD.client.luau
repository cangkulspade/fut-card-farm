local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- ===== Bangun HUD (dibuat via kode agar selalu ada di setiap pemain) =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TycoonHUD"
screenGui.ResetOnSpawn = false -- HUD permanen, tidak hilang saat respawn
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "HUDFrame"
frame.AnchorPoint = Vector2.new(1, 1)
frame.Position = UDim2.new(1, -12, 1, -12) -- pojok kanan bawah
frame.Size = UDim2.new(0, 220, 0, 84)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
frame.BackgroundTransparency = 0.25
frame.BorderSizePixel = 0
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = BrickColor.new("Royal purple").Color
stroke.Thickness = 2
stroke.Parent = frame

local cashLabel = Instance.new("TextLabel")
cashLabel.Name = "CashLabel"
cashLabel.Size = UDim2.new(1, -20, 0.5, -4)
cashLabel.Position = UDim2.new(0, 10, 0, 4)
cashLabel.BackgroundTransparency = 1
cashLabel.TextScaled = true
cashLabel.Font = Enum.Font.GothamBold
cashLabel.TextColor3 = Color3.fromRGB(85, 255, 127)
cashLabel.TextXAlignment = Enum.TextXAlignment.Left
cashLabel.Text = "Cash: $0"
cashLabel.Parent = frame

local luckLabel = Instance.new("TextLabel")
luckLabel.Name = "LuckLabel"
luckLabel.Size = UDim2.new(1, -20, 0.5, -4)
luckLabel.Position = UDim2.new(0, 10, 0.5, 0)
luckLabel.BackgroundTransparency = 1
luckLabel.TextScaled = true
luckLabel.Font = Enum.Font.GothamBold
luckLabel.TextColor3 = BrickColor.new("Gold").Color
luckLabel.TextXAlignment = Enum.TextXAlignment.Left
luckLabel.Text = "Luck Level: 1"
luckLabel.Parent = frame

-- ===== Fungsi update HUD =====
local function updateCash()
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash then
		cashLabel.Text = string.format("Cash: $%d", cash.Value)
	end
end

local gachaMachine = Workspace:FindFirstChild("TycoonSystem")
	and Workspace.TycoonSystem:FindFirstChild("CardGachaMachine")

local function updateLuck()
	if gachaMachine then
		local level = gachaMachine:GetAttribute("LuckLevel") or 1
		luckLabel.Text = string.format("Luck Level: %d", level)
	end
end

-- ===== Terhubung ke sumber data =====
-- Cash: pantau leaderstats muncul lalu setiap perubahan nilai
local function hookLeaderstats()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		-- leaderstats belum dibuat: tunggu muncul lalu hook
		local conn
		conn = player.ChildAdded:Connect(function(child)
			if child.Name == "leaderstats" then
				conn:Disconnect()
				hookLeaderstats()
			end
		end)
		return
	end
	local cash = leaderstats:FindFirstChild("Cash")
	if cash then
		updateCash()
		cash.Changed:Connect(updateCash)
	else
		leaderstats.ChildAdded:Connect(function(child)
			if child.Name == "Cash" then
				updateCash()
				child.Changed:Connect(updateCash)
			end
		end)
	end
end
hookLeaderstats()

-- Luck Level: pantau perubahan atribut pada mesin gacha
if gachaMachine then
	updateLuck()
	gachaMachine:GetAttributeChangedSignal("LuckLevel"):Connect(updateLuck)
end

updateCash()
updateLuck()