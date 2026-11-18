-- CardVisualBuilder: helper gaya kartu koleksi modern.
-- Memberi Part kartu bingkai tepi bercahaya (neon rainbow gradient border)
-- dan lencana Rarity di sudut kiri atas, pada sisi depan dan belakang kartu.

local CardVisualBuilder = {}

-- Singkatan nama rarity untuk lencana
local RARITY_BADGE = {
	Common = "CMN",
	Rare = "RARE",
	Epic = "EPIC",
	Legendary = "LEGEND",
}

-- Warna gradien cerah untuk teks lencana tiap rarity
local RARITY_GRADIENT = {
	Common = ColorSequence.new(
		Color3.fromRGB(230, 230, 230),
		Color3.fromRGB(150, 150, 150)
	),
	Rare = ColorSequence.new(
		Color3.fromRGB(80, 180, 255),
		Color3.fromRGB(0, 90, 255)
	),
	Epic = ColorSequence.new(
		Color3.fromRGB(220, 120, 255),
		Color3.fromRGB(130, 0, 255)
	),
	Legendary = ColorSequence.new(
		Color3.fromRGB(255, 220, 80),
		Color3.fromRGB(255, 130, 0)
	),
}

-- Gradien neon warna-warni untuk bingkai tepi kartu:
-- Cyan -> Kuning -> Magenta -> Ungu
local NEON_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 255)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(255, 0, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(128, 0, 255)),
})

-- Pasang satu set dekorasi (bingkai neon + lencana rarity) pada satu SurfaceGui
local function decorateFace(gui, rarity)
	-- Bingkai penuh tepi kartu
	local border = Instance.new("Frame")
	border.Name = "NeonBorder"
	border.Size = UDim2.new(1, 0, 1, 0)
	border.BackgroundTransparency = 0.85
	border.BorderSizePixel = 0
	border.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = border

	local stroke = Instance.new("UIStroke")
	stroke.Name = "NeonStroke"
	stroke.Thickness = 10
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = border

	local strokeGradient = Instance.new("UIGradient")
	strokeGradient.Name = "NeonGradient"
	strokeGradient.Color = NEON_GRADIENT
	strokeGradient.Parent = stroke

	-- Lencana Rarity di sudut kiri atas kartu
	local badge = Instance.new("TextLabel")
	badge.Name = "RarityBadge"
	badge.Position = UDim2.new(0.08, 0, 0.05, 0)
	badge.Size = UDim2.new(0.6, 0, 0.18, 0)
	badge.BackgroundTransparency = 1
	badge.Font = Enum.Font.FredokaOne
	badge.TextScaled = true
	badge.TextXAlignment = Enum.TextXAlignment.Left
	badge.Text = RARITY_BADGE[rarity] or rarity:upper()
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Parent = gui

	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Thickness = 4
	badgeStroke.Color = Color3.new(0, 0, 0)
	badgeStroke.Parent = badge

	local badgeGradient = Instance.new("UIGradient")
	badgeGradient.Color = RARITY_GRADIENT[rarity] or ColorSequence.new(
		Color3.new(1, 1, 1),
		Color3.fromRGB(180, 180, 180)
	)
	badgeGradient.Parent = badge
end

-- Terapkan gaya kartu koleksi pada Part kartu (sisi depan dan belakang).
-- Part harus sudah punya Size, Color, dan CFrame final sebelum dipanggil.
function CardVisualBuilder.apply(cardPart, rarity)
	if not cardPart or not cardPart:IsA("BasePart") then return end
	rarity = rarity or "Common"

	for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "CardFaceGui_" .. face.Name
		gui.Face = face
		gui.LightInfluence = 0
		gui.AlwaysOnTop = false
		gui.Parent = cardPart
		decorateFace(gui, rarity)
	end
end

return CardVisualBuilder