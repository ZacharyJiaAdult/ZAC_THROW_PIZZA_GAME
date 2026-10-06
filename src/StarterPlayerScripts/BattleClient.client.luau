local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("BattleRemotes")
local stateEvent = remotes:WaitForChild("State")
local throwEvent = remotes:WaitForChild("Throw")
local startEvent = remotes:WaitForChild("Start")
local profileEvent = remotes:WaitForChild("Profile")
local buyEvent = remotes:WaitForChild("BuyCrate")
local equipEvent = remotes:WaitForChild("Equip")
local crateEvent = remotes:WaitForChild("CrateResult")
local travelEvent = remotes:WaitForChild("Travel")
local botMenuEvent = remotes:WaitForChild("BotMenu")
local chooseBotEvent = remotes:WaitForChild("ChooseBot")
local Config = require(ReplicatedStorage:WaitForChild("BattleConfig"))
local Items = require(ReplicatedStorage:WaitForChild("BattleItems"))
local Characters = require(ReplicatedStorage:WaitForChild("BattleCharacters"))
local buyCharEvent = remotes:WaitForChild("BuyCharacter")
local buyCharRobuxEvent = remotes:WaitForChild("BuyCharacterRobux")
local equipCharEvent = remotes:WaitForChild("EquipCharacter")
local charResultEvent = remotes:WaitForChild("CharacterResult")
local dodgeEvent = remotes:WaitForChild("Dodge")

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local gui = make("ScreenGui", { Name = "BattleHud", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

local roundLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(320, 40),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextSize = 30,
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.3,
	Text = "Pizza Battle",
}, gui)

local function makeBar(side)
	local bg = make("Frame", {
		AnchorPoint = Vector2.new(side, 0),
		Position = UDim2.new(side, side == 0 and 20 or -20, 0, 60),
		Size = UDim2.fromOffset(320, 30),
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		Visible = false,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, bg)
	local stroke = make("UIStroke", { Color = Color3.fromRGB(255, 220, 60), Thickness = 3, Enabled = false }, bg)
	local fill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(80, 200, 80),
	}, bg)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, fill)
	local text = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
		ZIndex = 2,
	}, bg)
	make("UITextSizeConstraint", { MaxTextSize = 18 }, text)
	text.TextScaled = true
	return { bg = bg, fill = fill, text = text, stroke = stroke }
end

local bars = { makeBar(0), makeBar(1) }

local message = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -110),
	Size = UDim2.fromOffset(640, 50),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 28,
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.3,
}, gui)

local throwButton = make("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -30),
	Size = UDim2.fromOffset(260, 60),
	BackgroundColor3 = Color3.fromRGB(240, 130, 40),
	Font = Enum.Font.GothamBlack,
	TextSize = 24,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "THROW PIZZA",
	Visible = false,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, throwButton)

-- Shown to the defender for a moment when a throw is on its way: press it to take zero damage.
local dodgeButton = make("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromOffset(340, 90),
	BackgroundColor3 = Color3.fromRGB(60, 140, 235),
	Font = Enum.Font.GothamBlack,
	TextSize = 36,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "DODGE!",
	Visible = false,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 16) }, dodgeButton)
make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 4 }, dodgeButton)
dodgeButton.Activated:Connect(function()
	dodgeButton.Visible = false
	dodgeEvent:FireServer()
end)

-- Title screen: the player enters the game by pressing START ----------------------

local titleGui = make("ScreenGui", {
	Name = "TitleScreen",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 10,
}, player:WaitForChild("PlayerGui"))

local backdrop = make("CanvasGroup", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
}, titleGui)
make("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(200, 70, 40), Color3.fromRGB(70, 15, 10)),
	Rotation = 90,
}, backdrop)

make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.35),
	Size = UDim2.fromOffset(700, 100),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextSize = 72,
	TextColor3 = Color3.fromRGB(255, 220, 60),
	TextStrokeTransparency = 0,
	Text = "PIZZA BATTLE",
}, backdrop)

make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.47),
	Size = UDim2.fromOffset(700, 40),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 26,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Throw pizza. Roll the d20. Win the duel.",
}, backdrop)

local startButton = make("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.65),
	Size = UDim2.fromOffset(280, 80),
	BackgroundColor3 = Color3.fromRGB(240, 130, 40),
	Font = Enum.Font.GothamBlack,
	TextSize = 36,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "START",
}, backdrop)
make("UICorner", { CornerRadius = UDim.new(0, 16) }, startButton)

local started = false
startButton.Activated:Connect(function()
	if started then
		return
	end
	started = true
	startEvent:FireServer()
	local fade = TweenService:Create(backdrop, TweenInfo.new(0.5), { GroupTransparency = 1 })
	fade.Completed:Connect(function()
		titleGui:Destroy()
	end)
	fade:Play()
end)

-- Coins, abilities and the crate shop ------------------------------------------------

local profile = { coins = 0, armour = {}, abilities = {}, characters = {} }
local armedAbility = nil

local coinsLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 48),
	Size = UDim2.fromOffset(200, 24),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 20,
	TextColor3 = Color3.fromRGB(255, 220, 60),
	TextStrokeTransparency = 0.4,
	Text = "Coins: 0",
}, gui)

local abilityRow = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -165),
	Size = UDim2.fromOffset(800, 44),
	BackgroundTransparency = 1,
	Visible = false,
}, gui)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
}, abilityRow)

local function refreshAbilities()
	for _, child in abilityRow:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	if armedAbility and (profile.abilities[armedAbility] or 0) <= 0 then
		armedAbility = nil
	end
	local ids = {}
	for id, count in profile.abilities do
		if count > 0 and Items.List[id] then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	for _, id in ids do
		local armed = armedAbility == id
		local button = make("TextButton", {
			Size = UDim2.fromOffset(190, 44),
			BackgroundColor3 = armed and Color3.fromRGB(255, 200, 40) or Color3.fromRGB(50, 50, 60),
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextColor3 = armed and Color3.new(0, 0, 0) or Color3.new(1, 1, 1),
			Text = `{Items.List[id].name} x{profile.abilities[id]}`,
		}, abilityRow)
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, button)
		button.Activated:Connect(function()
			armedAbility = if armedAbility == id then nil else id
			refreshAbilities()
		end)
	end
end

local shop = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(700, 440),
	BackgroundColor3 = Color3.fromRGB(35, 30, 40),
	Visible = false,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 14) }, shop)
make("UIStroke", { Color = Color3.fromRGB(240, 130, 40), Thickness = 3 }, shop)
make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 50),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextSize = 30,
	TextColor3 = Color3.fromRGB(255, 220, 60),
	Text = "CRATE SHOP",
}, shop)
local closeButton = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = Color3.fromRGB(180, 50, 50),
	Font = Enum.Font.GothamBlack,
	TextSize = 22,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "X",
}, shop)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, closeButton)

for i, crate in Items.Crates do
	local card = make("Frame", {
		Position = UDim2.fromOffset(20 + (i - 1) * 220, 60),
		Size = UDim2.fromOffset(210, 145),
		BackgroundColor3 = Color3.fromRGB(55, 48, 62),
	}, shop)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, card)
	make("TextLabel", {
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		TextColor3 = crate.color,
		Text = crate.name,
	}, card)
	make("TextLabel", {
		Position = UDim2.fromOffset(0, 45),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		TextWrapped = true,
		Text = crate.blurb,
	}, card)
	local buy = make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(180, 40),
		BackgroundColor3 = Color3.fromRGB(240, 130, 40),
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		Text = `Buy - {crate.price} coins`,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, buy)
	buy.Activated:Connect(function()
		buyEvent:FireServer(crate.id)
	end)
end

local resultLabel = make("TextLabel", {
	Position = UDim2.fromOffset(20, 215),
	Size = UDim2.new(1, -40, 0, 30),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 20,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Buy a crate to win armour and abilities!",
}, shop)

local inventory = make("Frame", {
	Position = UDim2.fromOffset(20, 255),
	Size = UDim2.new(1, -40, 1, -265),
	BackgroundTransparency = 1,
}, shop)
make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, inventory)

local function refreshShop()
	coinsLabel.Text = `Coins: {profile.coins}`
	for _, child in inventory:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local armourRow = make("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 }, inventory)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, armourRow)
	make("TextLabel", {
		Size = UDim2.fromOffset(70, 40),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "Armour:",
	}, armourRow)
	local armourIds = {}
	for id in profile.armour do
		table.insert(armourIds, id)
	end
	table.sort(armourIds)
	if #armourIds == 0 then
		make("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(200, 40),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 16,
			TextColor3 = Color3.fromRGB(170, 170, 170),
			Text = "none yet",
		}, armourRow)
	end
	for _, id in armourIds do
		local item = Items.List[id]
		local equipped = profile.equipped == id
		local button = make("TextButton", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(140, 40),
			BackgroundColor3 = equipped and Color3.fromRGB(70, 130, 70) or Color3.fromRGB(55, 48, 62),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = Items.RarityColors[item.rarity],
			Text = `{equipped and "[ON] " or ""}{item.name} (-{item.reduction})`,
		}, armourRow)
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, button)
		button.Activated:Connect(function()
			equipEvent:FireServer(id)
		end)
	end

	local abilityIds = {}
	for id, count in profile.abilities do
		if count > 0 and Items.List[id] then
			table.insert(abilityIds, id)
		end
	end
	table.sort(abilityIds)
	local parts = {}
	for _, id in abilityIds do
		table.insert(parts, `{Items.List[id].name} x{profile.abilities[id]}`)
	end
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "Abilities (arm one on your turn): " .. (#parts > 0 and table.concat(parts, ", ") or "none yet"),
	}, inventory)
end

local shopButton = make("TextButton", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 20, 1, -20),
	Size = UDim2.fromOffset(130, 50),
	BackgroundColor3 = Color3.fromRGB(70, 130, 220),
	Font = Enum.Font.GothamBlack,
	TextSize = 22,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "SHOP",
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, shopButton)

shopButton.Activated:Connect(function()
	shop.Visible = not shop.Visible
	refreshShop()
end)
closeButton.Activated:Connect(function()
	shop.Visible = false
end)

-- Special characters: buy with coins or Robux, then equip ---------------------------------

local charPanel = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(640, 500),
	BackgroundColor3 = Color3.fromRGB(35, 30, 40),
	Visible = false,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 14) }, charPanel)
make("UIStroke", { Color = Color3.fromRGB(240, 130, 40), Thickness = 3 }, charPanel)
make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 50),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextSize = 30,
	TextColor3 = Color3.fromRGB(255, 220, 60),
	Text = "SPECIAL CHARACTERS",
}, charPanel)
local charClose = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = Color3.fromRGB(180, 50, 50),
	Font = Enum.Font.GothamBlack,
	TextSize = 22,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "X",
}, charPanel)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, charClose)
local charResultLabel = make("TextLabel", {
	Position = UDim2.fromOffset(20, 52),
	Size = UDim2.new(1, -40, 0, 36),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextWrapped = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Each character has one special ability.",
}, charPanel)
local charList = make("ScrollingFrame", {
	Position = UDim2.fromOffset(20, 96),
	Size = UDim2.new(1, -40, 1, -116),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, charPanel)
make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, charList)

local function refreshCharacters()
	for _, child in charList:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local owned = profile.characters or {}
	for order, character in Characters.List do
		local isOwned = owned[character.id] == true
		local isEquipped = profile.character == character.id
		local row = make("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 74),
			BackgroundColor3 = isEquipped and Color3.fromRGB(50, 80, 55) or Color3.fromRGB(55, 48, 62),
		}, charList)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, row)
		make("Frame", {
			Size = UDim2.new(0, 8, 1, 0),
			BackgroundColor3 = character.color,
			BorderSizePixel = 0,
		}, row)
		make("TextLabel", {
			Position = UDim2.fromOffset(20, 6),
			Size = UDim2.new(1, -190, 0, 24),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = character.color,
			Text = `{character.name}  -  {character.abilityName}`,
		}, row)
		make("TextLabel", {
			Position = UDim2.fromOffset(20, 32),
			Size = UDim2.new(1, -190, 0, 36),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 15,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.new(1, 1, 1),
			Text = character.desc,
		}, row)

		local function rowButton(y, text, color, onClick)
			local button = make("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, y),
				Size = UDim2.fromOffset(150, 28),
				BackgroundColor3 = color,
				Font = Enum.Font.GothamBold,
				TextSize = 14,
				TextColor3 = Color3.new(1, 1, 1),
				Text = text,
				AutoButtonColor = onClick ~= nil,
			}, row)
			make("UICorner", { CornerRadius = UDim.new(0, 8) }, button)
			if onClick then
				button.Activated:Connect(onClick)
			end
		end

		if isOwned then
			if isEquipped then
				rowButton(23, "EQUIPPED", Color3.fromRGB(70, 130, 70), nil)
			else
				rowButton(23, "EQUIP", Color3.fromRGB(70, 130, 220), function()
					equipCharEvent:FireServer(character.id)
				end)
			end
		else
			rowButton(8, `{character.price} coins`, Color3.fromRGB(240, 130, 40), function()
				buyCharEvent:FireServer(character.id)
			end)
			if character.robuxProductId ~= 0 then
				rowButton(40, `R$ {character.robuxPrice}`, Color3.fromRGB(60, 160, 90), function()
					buyCharRobuxEvent:FireServer(character.id)
				end)
			else
				rowButton(40, "R$ (not set up)", Color3.fromRGB(90, 90, 100), nil)
			end
		end
	end
end

local charButton = make("TextButton", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 170, 1, -20),
	Size = UDim2.fromOffset(190, 50),
	BackgroundColor3 = Color3.fromRGB(200, 90, 60),
	Font = Enum.Font.GothamBlack,
	TextSize = 20,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "CHARACTERS",
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, charButton)
charButton.Activated:Connect(function()
	charPanel.Visible = not charPanel.Visible
	refreshCharacters()
end)
charClose.Activated:Connect(function()
	charPanel.Visible = false
end)

charResultEvent.OnClientEvent:Connect(function(result)
	if result.error then
		charResultLabel.Text = result.error
		charResultLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
	else
		charResultLabel.Text = result.message or ""
		charResultLabel.TextColor3 = Color3.fromRGB(120, 230, 140)
	end
end)

profileEvent.OnClientEvent:Connect(function(data)
	profile = data
	refreshShop()
	refreshAbilities()
	refreshCharacters()
end)

crateEvent.OnClientEvent:Connect(function(result)
	if result.error then
		resultLabel.Text = result.error
		resultLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
		return
	end
	local item = Items.List[result.itemId]
	local text = `You got {item.name} ({item.rarity})!`
	if result.refund then
		text ..= ` Duplicate: {result.refund} coins back.`
	end
	resultLabel.Text = text
	resultLabel.TextColor3 = Items.RarityColors[item.rarity]
end)

-- Spectating: jump to the stands to watch matches, and back to the lobby ---------------

local watching = false
local watchButton = make("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -20, 1, -20),
	Size = UDim2.fromOffset(210, 50),
	BackgroundColor3 = Color3.fromRGB(110, 90, 200),
	Font = Enum.Font.GothamBlack,
	TextSize = 20,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "WATCH MATCHES",
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, watchButton)

-- Arena status from the lobby messages: arenaList[id] = { busy = bool, label = "A vs B" }
local arenaList = {}

local picker = make("Frame", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -20, 1, -80),
	Size = UDim2.fromOffset(300, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Visible = false,
}, gui)
make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, picker)

local function refreshPicker()
	for _, child in picker:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for id = 1, Config.ArenaCount do
		local info = arenaList[id]
		local busy = info and info.busy
		local button = make("TextButton", {
			LayoutOrder = id,
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = busy and Color3.fromRGB(150, 80, 60) or Color3.fromRGB(60, 60, 80),
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextWrapped = true,
			TextColor3 = Color3.new(1, 1, 1),
			Text = busy and `Arena {id}: {info.label}` or `Arena {id}: empty`,
		}, picker)
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, button)
		button.Activated:Connect(function()
			picker.Visible = false
			travelEvent:FireServer("stands", id)
			watching = true
			watchButton.Text = "BACK TO LOBBY"
		end)
	end
end

watchButton.Activated:Connect(function()
	if watching then
		travelEvent:FireServer("lobby")
		watching = false
		watchButton.Text = "WATCH MATCHES"
		return
	end
	picker.Visible = not picker.Visible
	if picker.Visible then
		refreshPicker()
	end
end)

-- Respawning (for example after a match) puts you back at the lobby
player.CharacterAdded:Connect(function()
	watching = false
	watchButton.Text = "WATCH MATCHES"
end)

-- Bot kiosk: choose how tough PizzaBot is ------------------------------------------------

local botMenu = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(540, 150 + #Config.BotLevels * 78),
	BackgroundColor3 = Color3.fromRGB(35, 30, 40),
	Visible = false,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 14) }, botMenu)
make("UIStroke", { Color = Color3.fromRGB(240, 130, 40), Thickness = 3 }, botMenu)
make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 56),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextSize = 28,
	TextColor3 = Color3.fromRGB(255, 220, 60),
	Text = "CHOOSE BOT DIFFICULTY",
}, botMenu)

for i, level in Config.BotLevels do
	local reward = math.floor(Config.WinCoins * level.coinMult + 0.5)
	local button = make("TextButton", {
		Position = UDim2.fromOffset(20, 60 + (i - 1) * 78),
		Size = UDim2.new(1, -40, 0, 70),
		BackgroundColor3 = level.color,
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextWrapped = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = `{level.name}: {level.desc}\nWin = {reward} coins`,
	}, botMenu)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, button)
	button.Activated:Connect(function()
		botMenu.Visible = false
		chooseBotEvent:FireServer(level.id)
	end)
end

local cancelBot = make("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(160, 40),
	BackgroundColor3 = Color3.fromRGB(90, 90, 100),
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Cancel",
}, botMenu)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, cancelBot)
cancelBot.Activated:Connect(function()
	botMenu.Visible = false
	chooseBotEvent:FireServer("cancel")
end)

botMenuEvent.OnClientEvent:Connect(function()
	botMenu.Visible = true
end)

local turnToken = 0

throwButton.Activated:Connect(function()
	turnToken += 1
	throwButton.Visible = false
	abilityRow.Visible = false
	throwEvent:FireServer(armedAbility)
	armedAbility = nil
	refreshAbilities()
end)

stateEvent.OnClientEvent:Connect(function(state)
	turnToken += 1
	message.Text = state.message or ""

	if state.arenas then
		arenaList = {}
		for _, info in state.arenas do
			arenaList[info.id] = info
		end
	end

	local prefix = state.arenaId and `Arena {state.arenaId} - ` or ""
	if state.round and state.round > 0 then
		roundLabel.Text = prefix
			.. (state.round > state.maxRounds and "SUDDEN DEATH" or `Round {state.round} / {state.maxRounds}`)
	elseif state.arenaId then
		roundLabel.Text = `Arena {state.arenaId}`
	else
		roundLabel.Text = "Pizza Battle"
	end

	for i, bar in bars do
		local fighter = state.fighters and state.fighters[i]
		bar.bg.Visible = fighter ~= nil
		if fighter then
			local ratio = math.clamp(fighter.hp / fighter.maxHp, 0, 1)
			bar.text.Text = `{fighter.name}  {fighter.hp}/{fighter.maxHp}  dodge x{fighter.dodges or 0}`
			if fighter.userId == player.UserId then
				dodgeButton.Text = `DODGE! ({fighter.dodges or 0} left)`
			end
			bar.stroke.Enabled = state.phase == "turn" and state.turnUserId == fighter.userId
			TweenService:Create(bar.fill, TweenInfo.new(0.4), {
				Size = UDim2.fromScale(ratio, 1),
				BackgroundColor3 = Color3.fromHSV(0.33 * ratio, 0.75, 0.85),
			}):Play()
		end
	end

	local myTurn = state.phase == "turn" and state.turnUserId == player.UserId
	throwButton.Visible = myTurn
	dodgeButton.Visible = state.phase == "dodge" and state.turnUserId == player.UserId
	abilityRow.Visible = myTurn
	if not myTurn then
		armedAbility = nil
	end
	refreshAbilities()
	if myTurn then
		local token = turnToken
		task.spawn(function()
			for seconds = state.turnSeconds, 1, -1 do
				if token ~= turnToken then
					return
				end
				throwButton.Text = `THROW PIZZA ({seconds})`
				task.wait(1)
			end
		end)
	end
end)
