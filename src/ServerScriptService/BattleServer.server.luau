local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage:WaitForChild("BattleConfig"))
local Items = require(ReplicatedStorage:WaitForChild("BattleItems"))
local Characters = require(ReplicatedStorage:WaitForChild("BattleCharacters"))
local ArenaMap = require(script.Parent:WaitForChild("ArenaMap"))

local remotes = Instance.new("Folder")
remotes.Name = "BattleRemotes"
local function makeRemote(name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
	return event
end
local stateEvent = makeRemote("State")
local throwEvent = makeRemote("Throw")
local startEvent = makeRemote("Start")
local profileEvent = makeRemote("Profile")
local buyEvent = makeRemote("BuyCrate")
local equipEvent = makeRemote("Equip")
local crateEvent = makeRemote("CrateResult")
local travelEvent = makeRemote("Travel")
local botMenuEvent = makeRemote("BotMenu")
local chooseBotEvent = makeRemote("ChooseBot")
local buyCharEvent = makeRemote("BuyCharacter")
local buyCharRobuxEvent = makeRemote("BuyCharacterRobux")
local equipCharEvent = makeRemote("EquipCharacter")
local charResultEvent = makeRemote("CharacterResult")
local dodgeEvent = makeRemote("Dodge")
local adminEvent = makeRemote("AdminGrant")
local ffaThrowEvent = makeRemote("FFAThrow")
local ffaDodgeEvent = makeRemote("FFADodge")
local ffaAbilityEvent = makeRemote("FFAAbility")
local ffaNukeEvent = makeRemote("FFANuke")
local nukeFlashEvent = makeRemote("NukeFlash")
remotes.Parent = ReplicatedStorage

local PAD_OFFSET = 18

local map = ArenaMap.build(Config.ArenaCount)
local arenas = map.arenas
local zone = map.zone

-- Player state ---------------------------------------------------------------

local ready = {} -- pressed START on the title screen
local inZone = {} -- standing in the Waiting Area
local zoneSince = {} -- when they stepped in (queue order)
local botChoice = {} -- level id picked at the bot kiosk
local reserved = {} -- in a match countdown or a match
local fightingArena = {} -- the arena a player is fighting in
local viewing = {} -- the arena whose HUD a player sees (fighting or standing in its stands)
local pendingInfo = {} -- countdown info shown to players about to fight
local inFFAZone = {} -- standing in the Free For All waiting area
local ffaZoneSince = {} -- when they stepped in (queue order)
local ffaPending = {} -- seconds left on the Free For All countdown, for players in it
local ffaPlayers = {} -- player -> { match, fighter } while they are in a Free For All
local ffaBots = 0 -- bots requested for the next Free For All (set at its kiosk)

-- Shop profiles are saved to a DataStore. Studio needs "Enable Studio Access to API Services" in Game
-- Settings > Security, and the place must be published. If loading fails the profile still works for the
-- session but is not saved, so a failed load can never overwrite saved data with defaults.
local storeOk, profileStore = pcall(function()
	return DataStoreService:GetDataStore("PizzaBattleProfiles_v1")
end)
if not storeOk then
	warn("DataStore unavailable, progress will not be saved: " .. tostring(profileStore))
	profileStore = nil
end
local profiles = {}
local loaded = {} -- player -> true once their saved data was loaded (or loading gave up)

local function newProfile()
	return {
		coins = Config.StartingCoins,
		armour = {},
		abilities = {},
		characters = { [Characters.Default] = true },
		character = Characters.Default,
		receipts = {},
	}
end

local function getProfile(player)
	local profile = profiles[player]
	if not profile then
		profile = newProfile()
		profiles[player] = profile
	end
	return profile
end

-- Admins can grant the Head Chef to anyone. Kept on the server so the list is never sent to clients.
-- The place owner (when the place belongs to a user) is always an admin.
local ADMIN_USER_IDS = { 11769949215, 7029100460 } -- @bottleo_waer, @Boss_zacharys

-- The owner (the account that owns the place) alone can claim the Administrator Trophy.
local OWNER_USER_IDS = { 11769949215, 7029100460 } -- @bottleo_waer, @Boss_zacharys

local function isOwner(player)
	if table.find(OWNER_USER_IDS, player.UserId) then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId
end

local function isAdmin(player)
	if table.find(ADMIN_USER_IDS, player.UserId) then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId
end

-- Administrators wear a gold "ADMIN" title above their head, and "[ADMIN]" shows before their name in matches.
local function addAdminTitle(character)
	local head = character:WaitForChild("Head", 10)
	if not head or head:FindFirstChild("AdminTitle") then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "AdminTitle"
	tag.Size = UDim2.fromOffset(120, 30)
	tag.StudsOffset = Vector3.new(0, 4.6, 0) -- above the special character's name tag
	tag.AlwaysOnTop = true
	tag.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(25, 20, 10)
	label.BackgroundTransparency = 0.25
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 215, 80)
	-- whoever has claimed the Administrator Trophy wears the longer title
	local holder = Players:GetPlayerFromCharacter(character)
	local trophy = holder and profiles[holder] and profiles[holder].trophy
	label.Text = trophy and "ADMINISTRATOR" or "ADMIN"
	if trophy then
		tag.Size = UDim2.fromOffset(210, 30)
		label.TextColor3 = Color3.fromRGB(255, 240, 160)
	end
	label.Parent = tag

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 215, 80)
	stroke.Thickness = 2
	stroke.Parent = label
end

local function trackAdminTitle(player)
	if not isAdmin(player) then
		return
	end
	if player.Character then
		task.spawn(addAdminTitle, player.Character)
	end
	player.CharacterAdded:Connect(addAdminTitle)
end
local function refreshAdminTitle(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local old = head and head:FindFirstChild("AdminTitle")
	if old then
		old:Destroy()
	end
	if character and isAdmin(player) then
		task.spawn(addAdminTitle, character)
	end
end

Players.PlayerAdded:Connect(trackAdminTitle)
for _, player in Players:GetPlayers() do
	task.spawn(trackAdminTitle, player)
end

local function sendProfile(player)
	if player.Parent == Players then
		local profile = getProfile(player)
		profile.isAdmin = isAdmin(player) -- tells the client whether to show the admin panel (never saved)
		profileEvent:FireClient(player, profile)
	end
end

local function profileKey(player)
	return `player_{player.UserId}`
end

local function saveProfile(player)
	local profile = profiles[player]
	if not profile or profile.noSave or not profileStore then
		return false
	end
	local ok, err = pcall(function()
		profileStore:SetAsync(profileKey(player), {
			coins = profile.coins,
			armour = profile.armour,
			equipped = profile.equipped,
			abilities = profile.abilities,
			characters = profile.characters,
			character = profile.character,
			receipts = profile.receipts,
			trophy = profile.trophy,
			starterClaimed = profile.starterClaimed,
		})
	end)
	if not ok then
		warn(`Saving {player.Name} failed: {err}`)
	end
	return ok
end

local function loadProfile(player)
	local ok, data = pcall(function()
		if not profileStore then
			error("no DataStore")
		end
		return profileStore:GetAsync(profileKey(player))
	end)
	if loaded[player] or player.Parent ~= Players then
		return
	end
	local profile = getProfile(player)
	if ok then
		if typeof(data) == "table" then
			profile.coins = data.coins or profile.coins
			profile.armour = data.armour or profile.armour
			profile.equipped = data.equipped
			profile.abilities = data.abilities or profile.abilities
			profile.characters = data.characters or profile.characters
			profile.characters[Characters.Default] = true
			profile.character = data.character or profile.character
			if not profile.characters[profile.character] then
				profile.character = Characters.Default
			end
			profile.receipts = data.receipts or profile.receipts
			profile.trophy = data.trophy
			profile.starterClaimed = data.starterClaimed
			if profile.trophy then
				task.spawn(refreshAdminTitle, player)
			end
		end
	else
		profile.noSave = true
		warn(`Loading {player.Name} failed, their progress will not be saved: {data}`)
	end
	loaded[player] = true
end

startEvent.OnServerEvent:Connect(function(player)
	local waited = 0
	while not loaded[player] and waited < 10 and player.Parent == Players do
		task.wait(0.2)
		waited += 0.2
	end
	if not loaded[player] then
		loaded[player] = true
		getProfile(player).noSave = true
	end
	ready[player] = true
	sendProfile(player)
end)

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadProfile, player)
end)
for _, player in Players:GetPlayers() do
	task.spawn(loadProfile, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveProfile(player)
	ready[player] = nil
	loaded[player] = nil
	inZone[player] = nil
	zoneSince[player] = nil
	botChoice[player] = nil
	reserved[player] = nil
	fightingArena[player] = nil
	viewing[player] = nil
	pendingInfo[player] = nil
	inFFAZone[player] = nil
	ffaZoneSince[player] = nil
	ffaPending[player] = nil
	ffaPlayers[player] = nil
	profiles[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			saveProfile(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		saveProfile(player)
	end
end)

local function rollCrate(crate)
	local total = 0
	for _, weight in crate.weights do
		total += weight
	end
	local pick = math.random() * total
	local rarity = "Common"
	for _, name in Items.Rarities do
		pick -= crate.weights[name]
		if pick <= 0 then
			rarity = name
			break
		end
	end
	local pool = {}
	for id, item in Items.List do
		if item.rarity == rarity and not item.notInCrates then
			table.insert(pool, id)
		end
	end
	table.sort(pool)
	return pool[math.random(#pool)]
end

buyEvent.OnServerEvent:Connect(function(player, crateId)
	local crate = typeof(crateId) == "string" and Items.getCrate(crateId)
	if not crate then
		return
	end
	local profile = getProfile(player)
	if profile.coins < crate.price then
		crateEvent:FireClient(player, { error = "Not enough coins!" })
		return
	end
	profile.coins -= crate.price

	-- Special crates sometimes drop a whole character instead of an item.
	local special = crate.special
	if special and math.random() < special.chance then
		local character = Characters.ById[special.characters[math.random(#special.characters)]]
		local refund
		if profile.characters[character.id] then
			refund = special.refund
			profile.coins += refund
		else
			profile.characters[character.id] = true
			profile.character = character.id
		end
		crateEvent:FireClient(player, { characterId = character.id, refund = refund })
		sendProfile(player)
		task.spawn(saveProfile, player)
		return
	end

	local itemId = rollCrate(crate)
	local item = Items.List[itemId]
	local refund
	if item.kind == "armour" then
		if profile.armour[itemId] then
			refund = Items.DuplicateRefund
			profile.coins += refund
		else
			profile.armour[itemId] = true
			profile.equipped = profile.equipped or itemId
		end
	else
		profile.abilities[itemId] = (profile.abilities[itemId] or 0) + 1
	end
	crateEvent:FireClient(player, { itemId = itemId, refund = refund })
	sendProfile(player)
end)

equipEvent.OnServerEvent:Connect(function(player, itemId)
	local profile = getProfile(player)
	if typeof(itemId) == "string" and profile.armour[itemId] then
		profile.equipped = itemId
		sendProfile(player)
	end
end)

-- Special characters ---------------------------------------------------------

-- Coin purchase: the character is unlocked and equipped straight away.
buyCharEvent.OnServerEvent:Connect(function(player, charId)
	local character = typeof(charId) == "string" and Characters.ById[charId]
	if not character then
		return
	end
	if character.coinsLocked then
		charResultEvent:FireClient(player, { error = `{character.name} can't be bought with coins.` })
		return
	end
	local profile = getProfile(player)
	if profile.characters[charId] then
		charResultEvent:FireClient(player, { message = `You already own {character.name}.` })
		return
	end
	if profile.coins < character.price then
		charResultEvent:FireClient(player, { error = "Not enough coins!" })
		return
	end
	profile.coins -= character.price
	profile.characters[charId] = true
	profile.character = charId
	charResultEvent:FireClient(player, {
		message = `Unlocked {character.name}! {character.abilityName}: {character.desc}`,
	})
	sendProfile(player)
	task.spawn(saveProfile, player)
end)

equipCharEvent.OnServerEvent:Connect(function(player, charId)
	local profile = getProfile(player)
	if typeof(charId) == "string" and profile.characters[charId] then
		profile.character = charId
		sendProfile(player)
	end
end)

-- Admin grant: an admin gives or takes the Head Chef for any player in the server.
adminEvent.OnServerEvent:Connect(function(admin, targetUserId, grant, charId)
	if not isAdmin(admin) or typeof(targetUserId) ~= "number" or typeof(grant) ~= "boolean" then
		return
	end
	-- only characters that are not for sale (coinsLocked) can be handed out this way
	local granted = typeof(charId) == "string" and Characters.ById[charId]
	if not granted or not granted.coinsLocked then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target then
		charResultEvent:FireClient(admin, { error = "That player is no longer in the server." })
		return
	end
	local profile = getProfile(target)
	if grant then
		profile.characters[granted.id] = true
	else
		profile.characters[granted.id] = nil
		if profile.character == granted.id then
			profile.character = Characters.Default
		end
	end
	sendProfile(target)
	task.spawn(saveProfile, target)
	charResultEvent:FireClient(admin, {
		message = `{grant and "Gave" or "Took"} {granted.name} {grant and "to" or "from"} {target.DisplayName}.`,
	})
	if target ~= admin then
		charResultEvent:FireClient(target, {
			message = grant and `An admin gave you {granted.name}!` or `An admin removed {granted.name}.`,
		})
	end
end)

-- Administrator Trophy: only the owner can claim it. It unlocks every character that is not for sale
-- and upgrades the owner's title to ADMINISTRATOR.
map.trophyPrompt.Triggered:Connect(function(player)
	if not isOwner(player) then
		charResultEvent:FireClient(player, { error = "Only the owner can claim the Administrator Trophy." })
		return
	end
	local profile = getProfile(player)
	local unlocked = {}
	for _, character in Characters.List do
		if character.coinsLocked then
			profile.characters[character.id] = true
			table.insert(unlocked, character.name)
		end
	end
	profile.trophy = true
	refreshAdminTitle(player)
	sendProfile(player)
	task.spawn(saveProfile, player)
	charResultEvent:FireClient(player, {
		message = `ADMINISTRATOR TROPHY claimed! Unlocked: {table.concat(unlocked, ", ")}.`,
	})
end)

-- Starter Pack present: gives the default unit and starter gear from Config.StarterPack, once per player.
map.presentPrompt.Triggered:Connect(function(player)
	local profile = getProfile(player)
	if profile.starterClaimed then
		charResultEvent:FireClient(player, { message = "You already opened your Starter Pack." })
		return
	end
	local pack = Config.StarterPack
	local lines = {}
	local starter = Characters.ById[pack.character]
	if starter then
		profile.characters[starter.id] = true
		table.insert(lines, starter.name)
	end
	for _, itemId in pack.armour do
		local item = Items.List[itemId]
		if item then
			profile.armour[itemId] = true
			profile.equipped = profile.equipped or itemId
			table.insert(lines, item.name)
		end
	end
	for itemId, count in pack.abilities do
		local item = Items.List[itemId]
		if item then
			profile.abilities[itemId] = (profile.abilities[itemId] or 0) + count
			table.insert(lines, `{count}x {item.name}`)
		end
	end
	profile.starterClaimed = true
	sendProfile(player)
	task.spawn(saveProfile, player)
	charResultEvent:FireClient(player, { message = `Starter Pack opened! You got: {table.concat(lines, ", ")}.` })
end)

-- Robux purchase: a developer product, granted in ProcessReceipt below.
buyCharRobuxEvent.OnServerEvent:Connect(function(player, charId)
	local character = typeof(charId) == "string" and Characters.ById[charId]
	if not character then
		return
	end
	if getProfile(player).characters[charId] then
		charResultEvent:FireClient(player, { message = `You already own {character.name}.` })
	elseif character.adminOnly then
		charResultEvent:FireClient(player, { error = `{character.name} can only be given by an admin.` })
	elseif character.crateOnly then
		charResultEvent:FireClient(player, { error = `{character.name} only drops from the Purple Chest.` })
	elseif character.robuxProductId == 0 then
		charResultEvent:FireClient(player, { error = "Robux purchase isn't set up for this character yet." })
	else
		MarketplaceService:PromptProductPurchase(player, character.robuxProductId)
	end
end)

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local character = Characters.byProduct(receipt.ProductId)
	if not player or not character then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = getProfile(player)
	local purchaseKey = tostring(receipt.PurchaseId)
	if profile.receipts[purchaseKey] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted
	end

	profile.receipts[purchaseKey] = true
	profile.characters[character.id] = true
	profile.character = character.id
	-- The purchase must be saved before it is confirmed, otherwise a crash could lose a paid unlock.
	if not saveProfile(player) then
		profile.receipts[purchaseKey] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	charResultEvent:FireClient(player, {
		message = `Unlocked {character.name}! {character.abilityName}: {character.desc}`,
	})
	sendProfile(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Match state for HUDs -------------------------------------------------------

-- Each arena keeps its own latest state; only players fighting in it or standing in its stands get it.
local function sendToViewers(arena, state)
	arena.latest = state
	for _, p in Players:GetPlayers() do
		if viewing[p] == arena then
			stateEvent:FireClient(p, state)
		end
	end
end

local function idleState(arena)
	local name = arena.name or `Arena {arena.id}`
	return { phase = "lobby", arenaId = arena.id, arenaName = arena.name, message = `{name}: no match right now` }
end

local function send(phase, match, message, turnUserId)
	local fighters = {}
	for _, f in match.fighters do
		table.insert(fighters, { userId = f.userId, name = f.name, hp = f.hp, maxHp = f.maxHp, dodges = f.dodges, activeId = f.activeId, activeLabel = f.activeLabel, activeLeft = f.activeLeft })
	end
	sendToViewers(match.arena, {
		phase = phase,
		arenaId = match.arena.id,
		round = match.round,
		maxRounds = Config.MaxRounds,
		fighters = fighters,
		turnUserId = turnUserId,
		turnSeconds = Config.TurnSeconds,
		message = message,
	})
end

-- Fighters (a real player or a practice bot) ---------------------------------

local function getBotLevel(id)
	for _, level in Config.BotLevels do
		if level.id == id then
			return level
		end
	end
	return nil
end

local function newFighter(player)
	local profile = getProfile(player)
	local character = Characters.ById[profile.character]
	return {
		player = player,
		name = (isAdmin(player) and "[ADMIN] " or "") .. player.DisplayName,
		userId = player.UserId,
		hp = Config.StartingHealth + (character and character.bonusHp or 0),
		maxHp = Config.StartingHealth + (character and character.bonusHp or 0),
		armour = Items.armourReduction(profile.equipped) + (character and character.armourBonus or 0),
		char = character, -- the special character, which carries the ability fields
		dodges = Config.DodgesPerMatch,
		activeId = character and character.active and character.active.id,
		activeLabel = character and character.active and character.active.label,
		activeLeft = character and character.active and character.active.uses or 0,
	}
end

local function makeBot(level)
	local model = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	model.Name = "PizzaBot"
	model.Parent = workspace
	return {
		isBot = true,
		model = model,
		name = `PizzaBot ({level.name})`,
		userId = -1,
		hp = level.hp,
		maxHp = level.hp,
		armour = level.armour,
		rollMode = level.rollMode,
		coinMult = level.coinMult,
		dodges = Config.DodgesPerMatch,
		dodgeChance = level.dodgeChance,
	}
end

local function getCharacter(f)
	if f.isBot then
		return f.model
	end
	return f.player.Character
end

local function getRoot(f)
	local character = getCharacter(f)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function isReady(f)
	if not f.isBot and f.player.Parent ~= Players then
		return false
	end
	return getRoot(f) ~= nil
end

-- Special characters recolour the avatar and wear a name tag. Respawning restores the normal look.
local function applyLook(f)
	local character = f.player.Character
	local special = f.char
	if not character or not special or special.id == Characters.Default then
		return
	end
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors.TorsoColor3 = special.color
		bodyColors.LeftArmColor3 = special.color
		bodyColors.RightArmColor3 = special.color
	end
	local head = character:FindFirstChild("Head")
	if head then
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(240, 40)
		tag.StudsOffset = Vector3.new(0, 3.2, 0)
		tag.AlwaysOnTop = true
		tag.Parent = head
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = special.color
		label.TextStrokeTransparency = 0
		label.Text = `{special.name} - {special.abilityName}`
		label.Parent = tag
	end
end

local function placeFighter(f, side, arena)
	local root = getRoot(f)
	if not root then
		return false
	end
	local pos = arena.center + Vector3.new(side * PAD_OFFSET, 4, 0)
	local lookAt = arena.center + Vector3.new(-side * PAD_OFFSET, 4, 0)
	getCharacter(f):PivotTo(CFrame.lookAt(pos, lookAt))
	root.Anchored = true
	if not f.isBot then
		applyLook(f)
	end
	return true
end

local function flash(f)
	local character = getCharacter(f)
	if not character then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 60, 60)
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.Parent = character
	task.delay(0.4, function()
		highlight:Destroy()
	end)
end

local function knockOut(f)
	local character = getCharacter(f)
	local root = getRoot(f)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid then
		root.Anchored = false
		humanoid.Health = 0
	end
end

-- Turn actions ---------------------------------------------------------------

-- Waits for the throw button. Returns the ability the player armed, if any. A bot just pauses.
local function waitForThrow(f)
	if f.isBot then
		task.wait(1.5)
		return nil
	end
	local player = f.player
	local thrown = false
	local chosen
	local conn = throwEvent.OnServerEvent:Connect(function(sender, abilityId)
		if sender == player then
			thrown = true
			if typeof(abilityId) == "string" then
				chosen = abilityId
			end
		end
	end)
	local started = os.clock()
	while not thrown and player.Parent == Players and os.clock() - started < Config.TurnSeconds do
		task.wait(0.1)
	end
	conn:Disconnect()
	return chosen
end

local function rollDice(f, ability)
	local root = getRoot(f)
	local base = (root and root.Position or Vector3.zero) + Vector3.new(0, 6, 0)

	local die = Instance.new("Part")
	die.Name = "D20"
	die.Size = Vector3.new(3, 3, 3)
	die.Material = Enum.Material.SmoothPlastic
	die.Color = Color3.fromRGB(245, 245, 245)
	die.Anchored = true
	die.CanCollide = false
	die.CFrame = CFrame.new(base)
	die.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(110, 70)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = die
	gui.Parent = die

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(255, 220, 60)
	label.TextStrokeTransparency = 0
	label.Parent = gui

	local roll = math.random(1, Config.DieSides)
	if f.char and f.char.rerollAtOrBelow and roll <= f.char.rerollAtOrBelow then
		roll = math.random(1, Config.DieSides)
	end
	if ability == "DoubleDice" or f.rollMode == "advantage" then
		roll = math.max(roll, math.random(1, Config.DieSides))
	elseif f.rollMode == "disadvantage" then
		roll = math.min(roll, math.random(1, Config.DieSides))
	end
	if ability == "LuckyPepperoni" then
		roll = math.max(roll, Items.LuckyMin)
	end
	local started = os.clock()
	while os.clock() - started < Config.RollSeconds do
		label.Text = tostring(math.random(1, Config.DieSides))
		die.CFrame = CFrame.new(base) * CFrame.Angles(math.random() * 6.28, math.random() * 6.28, math.random() * 6.28)
		task.wait(0.07)
	end
	label.Text = tostring(roll)
	die.CFrame = CFrame.new(base)
	return roll, die
end

-- missed = true when the defender dodged: they sidestep and the pizza sails past.
local function throwPizza(from, to, missed)
	local fromRoot, toRoot = getRoot(from), getRoot(to)
	if not fromRoot or not toRoot then
		return
	end
	local startPos = fromRoot.Position + Vector3.new(0, 2, 0)
	local endPos = toRoot.Position + Vector3.new(0, 1, 0)

	local pizza = Instance.new("Part")
	pizza.Name = "Pizza"
	pizza.Shape = Enum.PartType.Cylinder
	pizza.Size = Vector3.new(0.4, 3, 3)
	pizza.Material = Enum.Material.SmoothPlastic
	pizza.Color = Color3.fromRGB(240, 170, 60)
	pizza.Anchored = true
	pizza.CanCollide = false
	pizza.Parent = workspace

	local defender = getCharacter(to)
	local restingPivot
	if missed and defender then
		restingPivot = defender:GetPivot()
		defender:PivotTo(restingPivot * CFrame.new(0, 0, 4))
	end

	local duration = 0.7
	local started = os.clock()
	while true do
		local alpha = (os.clock() - started) / duration
		if alpha >= 1 then
			break
		end
		local pos = startPos:Lerp(endPos, alpha) + Vector3.new(0, math.sin(alpha * math.pi) * 6, 0)
		pizza.CFrame = CFrame.new(pos) * CFrame.Angles(0, alpha * math.pi * 8, 0) * CFrame.Angles(0, 0, math.pi / 2)
		RunService.Heartbeat:Wait()
	end
	pizza:Destroy()
	if restingPivot and defender then
		defender:PivotTo(restingPivot)
	end
end

-- Match ----------------------------------------------------------------------

-- The Nuclear Bomb: everyone watching the arena gets a white flash...
local function nukeFlash(arena)
	for _, p in Players:GetPlayers() do
		if viewing[p] == arena then
			nukeFlashEvent:FireClient(p)
		end
	end
end

-- ...and a fireball, a shockwave ring and a mushroom cloud rise over the arena floor.
local function nukeEffect(position)
	local base = Vector3.new(position.X, 2, position.Z)
	local upright = CFrame.Angles(0, 0, math.pi / 2) -- cylinders lie along X; stand them up
	local function glow(shape, size, cframe, color)
		local p = Instance.new("Part")
		p.Shape = shape
		p.Size = size
		p.CFrame = cframe
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Parent = workspace
		return p
	end
	local blast = glow(Enum.PartType.Ball, Vector3.one * 6, CFrame.new(base + Vector3.new(0, 3, 0)), Color3.fromRGB(255, 240, 190))
	local ring = glow(Enum.PartType.Cylinder, Vector3.new(0.6, 8, 8), CFrame.new(base + Vector3.new(0, 1, 0)) * upright, Color3.fromRGB(255, 200, 120))
	local stem = glow(Enum.PartType.Cylinder, Vector3.new(2, 6, 6), CFrame.new(base + Vector3.new(0, 1, 0)) * upright, Color3.fromRGB(255, 150, 60))
	local cap = glow(Enum.PartType.Ball, Vector3.one * 4, CFrame.new(base + Vector3.new(0, 3, 0)), Color3.fromRGB(255, 120, 40))

	-- a blast for the look only: no pressure and no broken joints
	local boom = Instance.new("Explosion")
	boom.Position = base
	boom.BlastRadius = 20
	boom.BlastPressure = 0
	boom.DestroyJointRadiusPercent = 0
	boom.ExplosionType = Enum.ExplosionType.NoCraters
	boom.Parent = workspace

	local quick = TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local slow = TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(blast, quick, { Size = Vector3.one * 130, Transparency = 1 }):Play()
	TweenService:Create(ring, quick, { Size = Vector3.new(0.6, 240, 240), Transparency = 1 }):Play()
	TweenService:Create(stem, slow, {
		Size = Vector3.new(50, 15, 15),
		CFrame = CFrame.new(base + Vector3.new(0, 26, 0)) * upright,
	}):Play()
	TweenService:Create(cap, slow, {
		Size = Vector3.one * 50,
		CFrame = CFrame.new(base + Vector3.new(0, 56, 0)),
		Color = Color3.fromRGB(120, 50, 20),
		Transparency = 0.35,
	}):Play()
	task.delay(5.5, function()
		for _, p in { blast, ring, stem, cap } do
			p:Destroy()
		end
	end)
	task.wait(1.2)
end

-- Sauce Sorcerer's Meteor Pie: a flaming pizza falls from the sky onto the target.
local function meteorEffect(to)
	local root = getRoot(to)
	if not root then
		return
	end
	local target = root.Position
	local meteor = Instance.new("Part")
	meteor.Name = "MeteorPie"
	meteor.Shape = Enum.PartType.Ball
	meteor.Size = Vector3.new(9, 9, 9)
	meteor.Material = Enum.Material.Neon
	meteor.Color = Color3.fromRGB(255, 140, 40)
	meteor.Anchored = true
	meteor.CanCollide = false
	meteor.Position = target + Vector3.new(0, 80, 0)
	meteor.Parent = workspace
	local fire = Instance.new("Fire")
	fire.Size = 25
	fire.Heat = 10
	fire.Parent = meteor

	local fall = TweenService:Create(meteor, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = target,
	})
	fall:Play()
	fall.Completed:Wait()

	-- a blast for the look only: no pressure and no broken joints
	local blast = Instance.new("Explosion")
	blast.Position = target
	blast.BlastRadius = 14
	blast.BlastPressure = 0
	blast.DestroyJointRadiusPercent = 0
	blast.ExplosionType = Enum.ExplosionType.NoCraters
	blast.Parent = workspace
	meteor:Destroy()
end

-- Void Chef's Black Hole: a black sphere with a purple ring opens above the target and swallows them.
local function blackHoleEffect(to)
	local root = getRoot(to)
	if not root then
		return
	end
	local center = root.Position + Vector3.new(0, 3, 0)
	local hole = Instance.new("Part")
	hole.Name = "BlackHole"
	hole.Shape = Enum.PartType.Ball
	hole.Size = Vector3.one
	hole.Color = Color3.new(0, 0, 0)
	hole.Material = Enum.Material.SmoothPlastic
	hole.Anchored = true
	hole.CanCollide = false
	hole.Position = center
	hole.Parent = workspace
	local ring = Instance.new("Part")
	ring.Name = "BlackHoleRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.5, 1, 1)
	ring.Color = Color3.fromRGB(170, 80, 255)
	ring.Material = Enum.Material.Neon
	ring.Anchored = true
	ring.CanCollide = false
	ring.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(170, 80, 255)
	light.Range = 30
	light.Brightness = 4
	light.Parent = hole

	local grow = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(hole, grow, { Size = Vector3.one * 14 }):Play()
	TweenService:Create(ring, grow, { Size = Vector3.new(0.5, 24, 24) }):Play()
	task.wait(1.2)

	-- the victim is crushed down and pulled into the middle
	local character = getCharacter(to)
	if character then
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				TweenService:Create(d, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Size = d.Size * 0.05,
					Position = center,
				}):Play()
			end
		end
	end
	task.wait(0.9)
	local fade = TweenInfo.new(0.6)
	TweenService:Create(hole, fade, { Size = Vector3.one * 0.5, Transparency = 1 }):Play()
	TweenService:Create(ring, fade, { Size = Vector3.new(0.5, 1, 1), Transparency = 1 }):Play()
	task.delay(0.7, function()
		hole:Destroy()
		ring:Destroy()
	end)
end

-- Time Chef's Time Freeze: the frozen fighter is tinted icy blue until their skipped turn passes.
local function freezeEffect(f)
	local character = getCharacter(f)
	if not character then
		return
	end
	local ice = Instance.new("Highlight")
	ice.Name = "TimeFreezeIce"
	ice.FillColor = Color3.fromRGB(140, 220, 255)
	ice.FillTransparency = 0.35
	ice.OutlineColor = Color3.new(1, 1, 1)
	ice.Parent = character
end

local function thaw(f)
	local character = getCharacter(f)
	local ice = character and character:FindFirstChild("TimeFreezeIce")
	if ice then
		ice:Destroy()
	end
end

-- The Head Chef's Cleaver Slash: a glowing crescent is cut through the air above the two fighters.
local function slashEffect(from, to)
	local fromRoot, toRoot = getRoot(from), getRoot(to)
	if not fromRoot or not toRoot then
		return
	end
	local center = (fromRoot.Position + toRoot.Position) / 2 + Vector3.new(0, 4, 0)
	local flat = (toRoot.Position - fromRoot.Position) * Vector3.new(1, 0, 1)
	local along = flat.Magnitude > 0 and flat.Unit or Vector3.xAxis
	local lean = CFrame.fromAxisAngle(along, math.rad(30)) -- tilt the arc so it reads as a diagonal slash
	local radius = 13

	local function pointAt(angle)
		local offset = along * (radius * math.sin(angle)) + Vector3.new(0, radius * math.cos(angle) - radius * 0.4, 0)
		return center + lean:VectorToWorldSpace(offset)
	end

	local segments = {}
	local count = 18
	for i = 0, count do
		local angle = math.rad(-75 + 150 * (i / count))
		local pos = pointAt(angle)
		local tangent = pointAt(angle + 0.05) - pos
		local segment = Instance.new("Part")
		segment.Name = "SlashSegment"
		segment.Size = Vector3.new(0.7, 0.7, 3.4)
		segment.Material = Enum.Material.Neon
		segment.Color = Color3.fromRGB(255, 245, 200)
		segment.Anchored = true
		segment.CanCollide = false
		segment.CFrame = CFrame.lookAt(pos, pos + tangent)
		segment.Transparency = 1
		segment.Parent = workspace
		table.insert(segments, segment)
	end

	-- the slash sweeps across, then fades
	for _, segment in segments do
		segment.Transparency = 0
		task.wait(0.015)
	end
	task.wait(0.15)
	for _, segment in segments do
		TweenService:Create(segment, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	end
	task.delay(0.6, function()
		for _, segment in segments do
			segment:Destroy()
		end
	end)
end

-- Zombie Slayer's Cleave: the usual slash, then the victim splits at the waist and the halves fall apart.
local function cleaveEffect(from, to)
	slashEffect(from, to)
	local root = getRoot(to)
	local character = getCharacter(to)
	if not root or not character then
		return
	end
	local waist = root.Position.Y
	local side = root.CFrame.RightVector
	local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			local upper = d.Position.Y >= waist
			d.Anchored = true
			d.CanCollide = false
			local shift = side * (upper and 2.5 or -2.5) + Vector3.new(0, upper and 1 or -1, 0)
			local tilt = CFrame.Angles(0, 0, math.rad(upper and -35 or 35))
			TweenService:Create(d, info, { CFrame = (d.CFrame * tilt) + shift }):Play()
		end
	end
	task.wait(0.8)
end

-- Gives the defender a short window to dodge the throw that is about to land. A dodge uses one of
-- their charges and means zero damage. Bots dodge by chance instead of pressing a button.
local function askDodge(match, defender)
	if (defender.dodges or 0) <= 0 then
		return false
	end
	if defender.isBot then
		if math.random() >= (defender.dodgeChance or 0) then
			return false
		end
		defender.dodges -= 1
		return true
	end

	send("dodge", match, `{defender.name}: press DODGE!`, defender.userId)
	local player = defender.player
	local pressed = false
	local conn = dodgeEvent.OnServerEvent:Connect(function(sender)
		if sender == player then
			pressed = true
		end
	end)
	local started = os.clock()
	while not pressed and player.Parent == Players and os.clock() - started < Config.DodgeSeconds do
		task.wait(0.05)
	end
	conn:Disconnect()
	if pressed then
		defender.dodges -= 1
	end
	return pressed
end

local function runMatch(arena, a, b)
	local match = { arena = arena, round = 0, fighters = { a, b } }
	local fighters = match.fighters

	if not (placeFighter(a, -1, arena) and placeFighter(b, 1, arena)) then
		return
	end

	send("intro", match, `{a.name} vs {b.name}!`)
	task.wait(3)

	local winner, reason
	while not winner do
		match.round += 1
		for i, f in fighters do
			local foe = fighters[3 - i]
			if not isReady(f) then
				winner, reason = foe, "by forfeit"
				break
			elseif not isReady(foe) then
				winner, reason = f, "by forfeit"
				break
			end

			-- Time Freeze: a frozen fighter loses this turn
			if f.frozen then
				f.frozen = false
				thaw(f)
				send("hit", match, `{f.name} is frozen in time and loses a turn!`)
				task.wait(1.6)
				continue
			end

			if f.char and f.char.healPerTurn then
				f.hp = math.min(f.maxHp, f.hp + f.char.healPerTurn)
			end
			send("turn", match, `{f.name}: throw the pizza!`, f.userId)
			local ability = waitForThrow(f)

			-- Active character abilities. Each is used from a button, has `uses` charges per match,
			-- and cannot be dodged or blocked.
			if ability and f.activeId == ability and (f.activeLeft or 0) > 0 then
				f.activeLeft -= 1
				if ability == "CleaverSlash" then
					send("rolling", match, `{f.name} raises the Cleaver...`)
					task.wait(0.9)
					slashEffect(f, foe)
					foe.hp = 0
					flash(foe)
					send("hit", match, `{f.name} unleashes CLEAVER SLASH! {foe.name} is defeated in one blow!`)
					task.wait(1.2)
					knockOut(foe)
					winner, reason = f, "with a Cleaver Slash"
					break
				elseif ability == "BlackHole" then
					send("rolling", match, `{f.name} opens a BLACK HOLE...`)
					task.wait(0.9)
					blackHoleEffect(foe)
					foe.hp = 0
					send("hit", match, `{foe.name} is swallowed by the black hole!`)
					task.wait(1)
					knockOut(foe)
					winner, reason = f, "with a Black Hole"
					break
				elseif ability == "Cleave" then
					send("rolling", match, `{f.name} raises their blade...`)
					task.wait(0.9)
					cleaveEffect(f, foe)
					foe.hp = 0
					send("hit", match, `{f.name} CLEAVES {foe.name} clean in half!`)
					task.wait(1)
					knockOut(foe)
					winner, reason = f, "with a Cleave"
					break
				elseif ability == "MeteorPie" then
					send("rolling", match, `{f.name} conjures a METEOR PIE!`)
					task.wait(0.9)
					meteorEffect(foe)
					foe.hp = math.max(0, foe.hp - Config.MeteorDamage)
					flash(foe)
					send("hit", match, `A flaming pizza meteor hits {foe.name} for {Config.MeteorDamage} damage!`)
					task.wait(1.2)
					if foe.hp <= 0 then
						knockOut(foe)
						winner, reason = f, "with a Meteor Pie"
						break
					end
					continue -- the meteor is the whole turn
				elseif ability == "TimeFreeze" then
					send("rolling", match, `{f.name} stops time! {foe.name} will lose their next turn.`)
					task.wait(1.4)
					foe.frozen = true
					freezeEffect(foe)
					ability = nil -- the throw this turn still happens
				end
			end

			-- Only spend an ability the player actually owns.
			local abilityItem
			if ability then
				local profile = getProfile(f.player)
				local item = Items.List[ability]
				if item and item.kind == "ability" and (profile.abilities[ability] or 0) > 0 then
					profile.abilities[ability] -= 1
					sendProfile(f.player)
					abilityItem = item
				else
					ability = nil
				end
			end

			if abilityItem then
				if ability == "HealingSlice" then
					f.hp = math.min(f.maxHp, f.hp + Items.HealAmount)
				end
				send("rolling", match, `{f.name} uses {abilityItem.name}!`)
				task.wait(1.2)

				-- Nuclear Bomb: cannot be dodged or blocked, and ends the match
				if ability == "NuclearBomb" then
					nukeFlash(arena)
					nukeEffect(arena.center)
					foe.hp = 0
					flash(foe)
					send("hit", match, `{f.name} drops a NUCLEAR BOMB! {foe.name} is wiped out!`)
					task.wait(1.2)
					knockOut(foe)
					winner, reason = f, "with a Nuclear Bomb"
					break
				end
			end

			send("rolling", match, `{f.name} rolls the d{Config.DieSides}...`)
			local roll, die = rollDice(f, ability)
			send("rolling", match, `{f.name} rolled a {roll}!`)
			task.wait(0.6)
			die:Destroy()

			local dodged = not foe.frozen and askDodge(match, foe) -- a fighter frozen in time cannot dodge
			local damage = roll
			local notes = {}
			if ability == "ExtraCheese" then
				damage += Items.CheeseBonus
			end
			if f.char and f.char.critChance and math.random() < f.char.critChance then
				damage *= 2
				table.insert(notes, `{f.char.abilityName}: double damage!`)
			end
			local blocked = math.min(foe.armour, damage - 1) -- a hit always does at least 1
			damage -= blocked
			if blocked > 0 then
				table.insert(notes, `{blocked} blocked by armour`)
			end
			if foe.char and foe.char.firstHitBlocked and not foe.barrierUsed and not dodged then
				foe.barrierUsed = true
				damage = 0
				table.insert(notes, `{foe.char.abilityName} absorbed the hit!`)
			end
			if dodged then
				damage = 0
				notes = { `{foe.name} dodged! ({foe.dodges} dodges left)` }
			end

			throwPizza(f, foe, dodged)
			foe.hp = math.max(0, foe.hp - damage)
			if not dodged then
				flash(foe)
			end
			if f.char and f.char.lifesteal and damage > 0 then
				f.hp = math.min(f.maxHp, f.hp + f.char.lifesteal)
				table.insert(notes, `{f.char.abilityName}: +{f.char.lifesteal} HP`)
			end
			local note = #notes > 0 and ` ({table.concat(notes, ", ")})` or ""
			send("hit", match, `{f.name} hits {foe.name} for {damage} damage!{note}`)
			task.wait(1.2)

			if foe.hp <= 0 then
				knockOut(foe)
				winner, reason = f, "by knockout"
				break
			end
		end

		if not winner and match.round >= Config.MaxRounds then
			local hpA, hpB = a.hp, b.hp
			if hpA ~= hpB then
				winner, reason = hpA > hpB and a or b, `after {Config.MaxRounds} rounds`
			else
				send("hit", match, "Tied! Sudden death!")
				task.wait(2)
			end
		end
	end

	for i, f in fighters do
		if not f.isBot then
			local foe = fighters[3 - i]
			local amount = Config.LossCoins
			if f == winner then
				amount = foe.isBot and math.floor(Config.WinCoins * foe.coinMult + 0.5) or Config.WinCoins
			end
			getProfile(f.player).coins += amount
			sendProfile(f.player)
		end
	end

	send("over", match, `{winner.name} wins {reason}!`)
	task.wait(Config.ResultSeconds)

	for _, f in fighters do
		if not f.isBot and f.player.Parent == Players then
			f.player:LoadCharacter()
		end
	end
end

-- Free For All (real time) ---------------------------------------------------
-- No turns: everyone moves freely and throws pizzas on a cooldown. A pizza that reaches someone rolls the
-- d20 for damage. A dodge roll makes you take zero damage for a moment. Last one standing wins.

local ffaArena = map.ffa
local viewAreas = table.clone(arenas) -- every arena a player can watch, for the HUD
table.insert(viewAreas, ffaArena)

local function notify(f, text)
	if not f.isBot and f.player.Parent == Players then
		charResultEvent:FireClient(f.player, { error = text })
	end
end

-- A number or word that floats up from a fighter's head and fades.
local function floatText(f, text, color)
	local character = getCharacter(f)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(170, 50)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	TweenService:Create(gui, TweenInfo.new(0.9), { StudsOffset = Vector3.new(0, 6.5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1, function()
		gui:Destroy()
	end)
end

local function ffaSend(match, phase, message)
	if message then
		match.lastMessage = message
	end
	local list = {}
	for _, f in match.fighters do
		table.insert(list, {
			userId = f.userId,
			name = f.name,
			hp = f.hp,
			maxHp = f.maxHp,
			alive = f.alive,
			kills = f.kills,
			activeId = f.activeId,
			activeLabel = f.activeLabel,
			activeLeft = f.activeLeft,
		})
	end
	sendToViewers(match.arena, {
		phase = phase,
		ffa = true,
		arenaId = match.arena.id,
		arenaName = match.arena.name,
		fighters = list,
		timeLeft = math.max(0, math.ceil(match.endsAt - os.clock())),
		message = match.lastMessage,
	})
end

local function nearestEnemy(match, f, maxDistance)
	local root = getRoot(f)
	if not root then
		return nil
	end
	local best, bestDistance = nil, maxDistance
	for _, v in match.fighters do
		if v ~= f and v.alive then
			local vr = getRoot(v)
			if vr then
				local d = (vr.Position - root.Position).Magnitude
				if d < bestDistance then
					best, bestDistance = v, d
				end
			end
		end
	end
	return best
end

local function ffaEliminate(match, victim, killer)
	victim.alive = false
	victim.hp = 0
	if killer and killer ~= victim then
		killer.kills += 1
	end
	knockOut(victim)
	ffaSend(match, "ffa", `{killer and killer.name or "Someone"} eliminated {victim.name}!`)
	if not victim.isBot then
		-- an eliminated player respawns and watches from the stands
		local player = victim.player
		task.delay(3, function()
			if player.Parent ~= Players or not match.running then
				return
			end
			player:LoadCharacter()
			local character = player.Character or player.CharacterAdded:Wait()
			local root = character:WaitForChild("HumanoidRootPart", 5)
			if root and match.running then
				character:PivotTo(match.arena.standsSpot())
			end
		end)
	end
end

local function ffaRoll(attacker)
	local roll = math.random(1, Config.DieSides)
	if attacker.char and attacker.char.rerollAtOrBelow and roll <= attacker.char.rerollAtOrBelow then
		roll = math.random(1, Config.DieSides)
	end
	if attacker.rollMode == "advantage" then
		roll = math.max(roll, math.random(1, Config.DieSides))
	elseif attacker.rollMode == "disadvantage" then
		roll = math.min(roll, math.random(1, Config.DieSides))
	end
	return roll
end

-- A pizza reached `victim`: roll the d20 for damage (a dodge roll in progress means zero damage).
local function ffaHit(match, attacker, victim)
	if not victim.alive or not attacker.alive then
		return
	end
	local now = os.clock()
	-- bots dodge by chance; players dodge by pressing their roll key
	if victim.isBot and now >= victim.dodgeReadyAt and math.random() < (victim.dodgeChance or 0) then
		victim.dodgeReadyAt = now + Config.FFADodgeCooldown
		victim.rollingUntil = now + Config.FFADodgeSeconds
	end
	if now < victim.rollingUntil then
		floatText(victim, "DODGED!", Color3.fromRGB(120, 200, 255))
		return
	end

	local roll = ffaRoll(attacker)
	local damage = roll
	local tag = `d20: {roll}`
	if attacker.char and attacker.char.critChance and math.random() < attacker.char.critChance then
		damage *= 2
		tag ..= " CRIT!"
	end
	local blocked = math.min(victim.armour, damage - 1) -- a hit always does at least 1
	damage -= blocked
	if victim.char and victim.char.firstHitBlocked and not victim.barrierUsed then
		victim.barrierUsed = true
		damage = 0
		tag = `{victim.char.abilityName}!`
	end

	victim.hp = math.max(0, victim.hp - damage)
	flash(victim)
	floatText(victim, damage > 0 and `{tag}  -{damage}` or tag, Color3.fromRGB(255, 220, 60))
	if attacker.char and attacker.char.lifesteal and damage > 0 then
		attacker.hp = math.min(attacker.maxHp, attacker.hp + attacker.char.lifesteal)
	end

	if victim.hp <= 0 then
		ffaEliminate(match, victim, attacker)
	else
		ffaSend(match, "ffa")
	end
end

-- Launches a pizza in a straight horizontal line. It hits the first fighter it reaches, or splats on cover.
local function ffaThrow(match, f, direction)
	local now = os.clock()
	if not f.alive or now < f.throwReadyAt or now < f.frozenUntil then
		return
	end
	local root = getRoot(f)
	if not root then
		return
	end
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.1 then
		return
	end
	direction = direction.Unit
	f.throwReadyAt = now + Config.FFAThrowCooldown

	local origin = root.Position + Vector3.new(0, 1.5, 0) + direction * 2.5
	local pizza = Instance.new("Part")
	pizza.Name = "Pizza"
	pizza.Shape = Enum.PartType.Cylinder
	pizza.Size = Vector3.new(0.4, 3, 3)
	pizza.Material = Enum.Material.SmoothPlastic
	pizza.Color = Color3.fromRGB(240, 170, 60)
	pizza.Anchored = true
	pizza.CanCollide = false
	pizza.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.pi / 2)
	pizza.Parent = workspace

	task.spawn(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { getCharacter(f), pizza }
		local position, traveled, spin = origin, 0, 0
		while match.running and traveled < Config.FFAProjectileRange do
			local dt = RunService.Heartbeat:Wait()
			local step = direction * Config.FFAProjectileSpeed * dt
			local mid = position + step * 0.5
			for _, v in match.fighters do
				if v ~= f and v.alive then
					local vr = getRoot(v)
					if vr then
						local d = vr.Position - mid
						if Vector3.new(d.X, 0, d.Z).Magnitude < 3.2 and math.abs(d.Y) < 4 then
							pizza:Destroy()
							ffaHit(match, f, v)
							return
						end
					end
				end
			end
			if workspace:Raycast(position, step, params) then
				break -- splatted against a pillar or wall
			end
			position += step
			traveled += step.Magnitude
			spin += dt * 14
			pizza.CFrame = CFrame.new(position) * CFrame.Angles(0, spin, 0) * CFrame.Angles(0, 0, math.pi / 2)
		end
		pizza:Destroy()
	end)
end

-- Dodge roll: for a moment every hit does zero damage. Then it has to recharge.
local function ffaDodge(match, f)
	local now = os.clock()
	if not f.alive or now < f.dodgeReadyAt or now < f.frozenUntil then
		return
	end
	f.dodgeReadyAt = now + Config.FFADodgeCooldown
	f.rollingUntil = now + Config.FFADodgeSeconds
	local character = getCharacter(f)
	if character then
		local glow = Instance.new("Highlight")
		glow.Name = "RollGlow"
		glow.FillColor = Color3.fromRGB(120, 200, 255)
		glow.FillTransparency = 0.4
		glow.OutlineColor = Color3.new(1, 1, 1)
		glow.Parent = character
		task.delay(Config.FFADodgeSeconds, function()
			glow:Destroy()
		end)
	end
	floatText(f, "ROLL!", Color3.fromRGB(120, 200, 255))
end

-- Active character abilities, adapted to real time. None of them can be dodged.
local function ffaAbility(match, f)
	if not f.alive or (f.activeLeft or 0) <= 0 or os.clock() < f.frozenUntil then
		return
	end
	local id = f.activeId
	if id == "CleaverSlash" then
		local target = nearestEnemy(match, f, 35)
		if not target then
			notify(f, "No enemy within reach of the Cleaver!")
			return
		end
		f.activeLeft -= 1
		ffaSend(match, "ffa", `{f.name} swings the Cleaver!`)
		task.spawn(function()
			slashEffect(f, target)
			if target.alive and match.running then
				ffaEliminate(match, target, f)
			end
		end)
	elseif id == "BlackHole" then
		-- swallows every enemy near the caster
		local victims = {}
		for _, v in match.fighters do
			local vr = getRoot(v)
			local fr = getRoot(f)
			if v ~= f and v.alive and vr and fr and (vr.Position - fr.Position).Magnitude <= 45 then
				table.insert(victims, v)
			end
		end
		if #victims == 0 then
			notify(f, "No enemy within reach of the Black Hole!")
			return
		end
		f.activeLeft -= 1
		ffaSend(match, "ffa", `{f.name} opens a BLACK HOLE!`)
		for _, v in victims do
			task.spawn(function()
				blackHoleEffect(v)
				if v.alive and match.running then
					ffaEliminate(match, v, f)
				end
			end)
		end
	elseif id == "Cleave" then
		local target = nearestEnemy(match, f, 35)
		if not target then
			notify(f, "No enemy within reach of the blade!")
			return
		end
		f.activeLeft -= 1
		ffaSend(match, "ffa", `{f.name} swings their blade!`)
		task.spawn(function()
			cleaveEffect(f, target)
			if target.alive and match.running then
				ffaEliminate(match, target, f)
			end
		end)
	elseif id == "MeteorPie" then
		local target = nearestEnemy(match, f, 80)
		if not target then
			notify(f, "No enemy in range for the Meteor Pie!")
			return
		end
		f.activeLeft -= 1
		ffaSend(match, "ffa", `{f.name} conjures a METEOR PIE!`)
		task.spawn(function()
			meteorEffect(target)
			if target.alive and match.running then
				target.hp = math.max(0, target.hp - Config.MeteorDamage)
				flash(target)
				floatText(target, `-{Config.MeteorDamage}`, Color3.fromRGB(255, 140, 40))
				if target.hp <= 0 then
					ffaEliminate(match, target, f)
				else
					ffaSend(match, "ffa")
				end
			end
		end)
	elseif id == "TimeFreeze" then
		f.activeLeft -= 1
		local frozen = {}
		for _, v in match.fighters do
			if v ~= f and v.alive then
				v.frozenUntil = os.clock() + Config.FFAFreezeSeconds
				local root = getRoot(v)
				if root then
					root.Anchored = true
				end
				freezeEffect(v)
				table.insert(frozen, v)
			end
		end
		ffaSend(match, "ffa", `{f.name} stops time!`)
		task.delay(Config.FFAFreezeSeconds, function()
			for _, v in frozen do
				thaw(v)
				local root = getRoot(v)
				if root and v.alive then
					root.Anchored = false
				end
			end
		end)
	end
	ffaSend(match, "ffa")
end

-- Bots chase the nearest fighter, strafe, and throw with a little aim error.
local function runBots(match)
	while match.running do
		local now = os.clock()
		for _, bot in match.fighters do
			if bot.isBot and bot.alive and now >= bot.frozenUntil then
				local root = getRoot(bot)
				local humanoid = bot.model:FindFirstChildOfClass("Humanoid")
				local target = nearestEnemy(match, bot, 400)
				local targetRoot = target and getRoot(target)
				if root and humanoid and targetRoot then
					local offset = Vector3.new(targetRoot.Position.X - root.Position.X, 0, targetRoot.Position.Z - root.Position.Z)
					local distance = offset.Magnitude
					if distance > 0.5 then
						local toward = offset.Unit
						if distance > 26 then
							humanoid:MoveTo(root.Position + toward * 16)
						elseif distance < 12 then
							humanoid:MoveTo(root.Position - toward * 12)
						else
							local side = Vector3.new(-toward.Z, 0, toward.X) * (bot.strafeDir or 1)
							humanoid:MoveTo(root.Position + side * 10)
							if math.random() < 0.15 then
								bot.strafeDir = -(bot.strafeDir or 1)
							end
						end
						if now >= bot.throwReadyAt and distance < 70 then
							local jitter = math.rad((math.random() * 2 - 1) * (bot.aimError or 8))
							ffaThrow(match, bot, CFrame.Angles(0, jitter, 0):VectorToWorldSpace(toward))
							bot.throwReadyAt = now + Config.FFAThrowCooldown * (1.4 + math.random())
						end
					end
				end
			end
		end
		task.wait(0.25)
	end
end

-- Once a second: refresh the clock on every HUD, and apply regeneration (Mama Mia).
local function runTicker(match)
	local lastRegen = os.clock()
	while match.running do
		task.wait(1)
		local now = os.clock()
		if now - lastRegen >= 6 then
			lastRegen = now
			for _, f in match.fighters do
				if f.alive and f.char and f.char.healPerTurn and f.hp < f.maxHp then
					f.hp = math.min(f.maxHp, f.hp + f.char.healPerTurn)
					floatText(f, `+{f.char.healPerTurn}`, Color3.fromRGB(120, 235, 140))
				end
			end
		end
		if match.running then
			ffaSend(match, "ffa")
		end
	end
end

local function runFFA(arena, fighters)
	local match = {
		arena = arena,
		ffa = true,
		fighters = fighters,
		running = true,
		endsAt = os.clock() + 3 + Config.FFAMatchSeconds,
		lastMessage = "Get ready!",
	}
	local points = arena.spawnPoints(#fighters)
	for i, f in fighters do
		f.alive = true
		f.kills = 0
		f.throwReadyAt = 0
		f.dodgeReadyAt = 0
		f.rollingUntil = 0
		f.frozenUntil = 0
		local root = getRoot(f)
		if root then
			getCharacter(f):PivotTo(points[i])
			root.Anchored = true -- held in place for the countdown
			if not f.isBot then
				applyLook(f)
				ffaPlayers[f.player] = { match = match, fighter = f }
			end
		end
	end

	for s = 3, 1, -1 do
		ffaSend(match, "ffa_intro", `Free For All starts in {s}...`)
		task.wait(1)
	end
	match.endsAt = os.clock() + Config.FFAMatchSeconds
	for _, f in fighters do
		local root = getRoot(f)
		if root then
			root.Anchored = false
		end
	end
	ffaSend(match, "ffa", "FIGHT!")
	task.spawn(runBots, match)
	task.spawn(runTicker, match)

	local winner
	while true do
		task.wait(0.2)
		local alive, last = 0, nil
		for _, f in fighters do
			if f.alive and not f.isBot and f.player.Parent ~= Players then
				f.alive = false -- a player who left is out
				f.hp = 0
			end
			if f.alive then
				alive += 1
				last = f
			end
		end
		if alive <= 1 then
			winner = last
			break
		end
		if os.clock() >= match.endsAt then
			-- time is up: the most HP wins, kills break ties
			for _, f in fighters do
				if f.alive and (not winner or f.hp > winner.hp or (f.hp == winner.hp and f.kills > winner.kills)) then
					winner = f
				end
			end
			break
		end
	end
	match.running = false

	for _, f in fighters do
		if not f.isBot then
			local coins = (f == winner and Config.FFAWinCoins or Config.FFALossCoins) + f.kills * Config.FFAKillCoins
			getProfile(f.player).coins += coins
			sendProfile(f.player)
		end
	end
	ffaSend(match, "ffa_over", winner and `{winner.name} wins the Free For All!` or "Nobody won.")
	task.wait(Config.ResultSeconds)
	for _, f in fighters do
		if not f.isBot and f.player.Parent == Players then
			f.player:LoadCharacter()
		end
	end
end

-- Nuclear Bomb in a Free For All: everyone else in the arena is eliminated.
local function ffaNuke(match, f)
	if f.isBot or not f.alive or os.clock() < f.frozenUntil then
		return
	end
	local profile = getProfile(f.player)
	if (profile.abilities.NuclearBomb or 0) <= 0 then
		return
	end
	profile.abilities.NuclearBomb -= 1
	sendProfile(f.player)
	ffaSend(match, "ffa", `{f.name} launches a NUCLEAR BOMB!`)
	nukeFlash(match.arena)
	task.spawn(function()
		nukeEffect(match.arena.center)
		for _, v in match.fighters do
			if v ~= f and v.alive and match.running then
				ffaEliminate(match, v, f)
			end
		end
	end)
end

ffaNukeEvent.OnServerEvent:Connect(function(player)
	local entry = ffaPlayers[player]
	if entry and entry.match.running then
		ffaNuke(entry.match, entry.fighter)
	end
end)

ffaThrowEvent.OnServerEvent:Connect(function(player, direction)
	local entry = ffaPlayers[player]
	if entry and entry.match.running and typeof(direction) == "Vector3" then
		ffaThrow(entry.match, entry.fighter, direction)
	end
end)
ffaDodgeEvent.OnServerEvent:Connect(function(player)
	local entry = ffaPlayers[player]
	if entry and entry.match.running then
		ffaDodge(entry.match, entry.fighter)
	end
end)
ffaAbilityEvent.OnServerEvent:Connect(function(player)
	local entry = ffaPlayers[player]
	if entry and entry.match.running then
		ffaAbility(entry.match, entry.fighter)
	end
end)

-- Waiting Area, arenas, bot kiosk and spectating -----------------------------

local function inBox(cframe, size, position)
	local rel = cframe:PointToObjectSpace(position)
	return math.abs(rel.X) <= size.X / 2 and math.abs(rel.Y) <= size.Y / 2 and math.abs(rel.Z) <= size.Z / 2
end

local function isInZone(position)
	local rel = zone.CFrame:PointToObjectSpace(position)
	return math.abs(rel.X) <= zone.Size.X / 2 and math.abs(rel.Z) <= zone.Size.Z / 2 and rel.Y > -2 and rel.Y < 12
end

local ffaZone = map.ffaZone

local function isInFFAZone(position)
	local rel = ffaZone.CFrame:PointToObjectSpace(position)
	return math.abs(rel.X) <= ffaZone.Size.X / 2
		and math.abs(rel.Z) <= ffaZone.Size.Z / 2
		and rel.Y > -2
		and rel.Y < 12
end

-- Tracks who is in the Waiting Areas (the queues) and which arena each player is watching.
task.spawn(function()
	while true do
		for _, p in Players:GetPlayers() do
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			local position = root and root.Position

			if position and isInZone(position) then
				inZone[p] = true
				zoneSince[p] = zoneSince[p] or os.clock()
			else
				inZone[p] = nil
				zoneSince[p] = nil
				if not reserved[p] then
					botChoice[p] = nil
				end
			end

			if position and isInFFAZone(position) then
				inFFAZone[p] = true
				ffaZoneSince[p] = ffaZoneSince[p] or os.clock()
			else
				inFFAZone[p] = nil
				ffaZoneSince[p] = nil
			end

			local arena = fightingArena[p]
			if not arena and position then
				for _, a in viewAreas do
					if inBox(a.regionCFrame, a.regionSize, position) then
						arena = a
						break
					end
				end
			end
			if viewing[p] ~= arena then
				viewing[p] = arena
				if arena then
					stateEvent:FireClient(p, arena.latest or idleState(arena))
				end
			end
		end
		task.wait(0.25)
	end
end)

local function arenaStatus()
	local list = {}
	for _, a in arenas do
		table.insert(list, { id = a.id, busy = a.busy == true, label = a.label })
	end
	table.insert(list, { id = ffaArena.id, busy = ffaArena.busy == true, label = ffaArena.label })
	return list
end

-- Everyone who is not watching an arena sees the lobby message.
task.spawn(function()
	while true do
		local allBusy = true
		for _, a in arenas do
			if not a.busy then
				allBusy = false
			end
		end
		local ffaWaiting = 0
		for _, q in Players:GetPlayers() do
			if inFFAZone[q] and ready[q] then
				ffaWaiting += 1
			end
		end
		local status = arenaStatus()
		for _, p in Players:GetPlayers() do
			if not viewing[p] then
				local message = "Step into the Waiting Area to play, or watch a match!"
				local pending = pendingInfo[p]
				if pending then
					message = `Arena {pending.arena.id}: {pending.label} starts in {pending.seconds}...`
				elseif ffaPending[p] then
					message = `Free For All starts in {ffaPending[p]}...`
				elseif inFFAZone[p] then
					if ffaArena.busy then
						message = "A Free For All is in progress. Hang on, or watch from the stands!"
					else
						message = `Free For All: {ffaWaiting} player(s) + {ffaBots} bot(s). It needs {Config.FFAMinPlayers} to start. Use the kiosk to add bots!`
					end
				elseif inZone[p] then
					if allBusy then
						message = "All arenas are busy. You're in the queue!"
					elseif Config.BotEnabled then
						message = "Waiting for an opponent... or fight a bot!"
					else
						message = "Waiting for an opponent..."
					end
				end
				stateEvent:FireClient(p, { phase = "lobby", message = message, arenas = status })
			end
		end
		task.wait(0.5)
	end
end)

map.botPrompt.Enabled = Config.BotEnabled
map.botPrompt.Triggered:Connect(function(player)
	if Config.BotEnabled and inZone[player] and not reserved[player] then
		botMenuEvent:FireClient(player)
	end
end)

chooseBotEvent.OnServerEvent:Connect(function(player, levelId)
	if levelId == "cancel" then
		if not reserved[player] then
			botChoice[player] = nil
		end
	elseif typeof(levelId) == "string" and getBotLevel(levelId) and inZone[player] and not reserved[player] then
		botChoice[player] = levelId
	end
end)

travelEvent.OnServerEvent:Connect(function(player, where, arenaId)
	local character = player.Character
	if reserved[player] or not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	if where == "stands" then
		local arena = typeof(arenaId) == "number" and arenas[arenaId]
		if arenaId == "FFA" then
			arena = ffaArena
		end
		if arena then
			character:PivotTo(arena.standsSpot())
		end
	elseif where == "lobby" then
		character:PivotTo(map.lobbySpot())
	end
end)

-- Matchmaking ----------------------------------------------------------------

local function getQueue()
	local list = {}
	for _, p in Players:GetPlayers() do
		if ready[p] and inZone[p] and not reserved[p] then
			table.insert(list, p)
		end
	end
	table.sort(list, function(x, y)
		return zoneSince[x] < zoneSince[y]
	end)
	return list
end

local function stillHere(p)
	return p.Parent == Players and inZone[p] == true
end

-- Reserves the arena, runs the countdown, then the match. All of it happens in its own thread so
-- other arenas keep going.
local function startMatch(arena, a, b, levelId)
	local level = levelId and getBotLevel(levelId)
	arena.busy = true
	reserved[a] = true
	if b then
		reserved[b] = true
	end
	local label = level and `{a.DisplayName} vs PizzaBot ({level.name})` or `{a.DisplayName} vs {b.DisplayName}`
	arena.label = label

	task.spawn(function()
		local cancelled = false
		for s = Config.IntermissionSeconds, 1, -1 do
			if not stillHere(a) or (b and not stillHere(b)) or (levelId and botChoice[a] ~= levelId) then
				cancelled = true
				break
			end
			local info = { arena = arena, seconds = s, label = label }
			pendingInfo[a] = info
			if b then
				pendingInfo[b] = info
			end
			task.wait(1)
		end
		pendingInfo[a] = nil
		if b then
			pendingInfo[b] = nil
		end

		if not cancelled and stillHere(a) and (not b or stillHere(b)) then
			local fighterA = newFighter(a)
			local fighterB = level and makeBot(level) or newFighter(b)
			fightingArena[a] = arena
			if b then
				fightingArena[b] = arena
			end

			local ok, err = pcall(runMatch, arena, fighterA, fighterB)
			if not ok then
				warn("Match error: " .. tostring(err))
				for _, f in { fighterA, fighterB } do
					if not f.isBot and f.player.Parent == Players then
						f.player:LoadCharacter()
					end
				end
			end
			if fighterB.isBot and fighterB.model.Parent then
				fighterB.model:Destroy()
			end

			fightingArena[a] = nil
			if b then
				fightingArena[b] = nil
			end
		end

		botChoice[a] = nil
		reserved[a] = nil
		if b then
			reserved[b] = nil
		end
		arena.busy = false
		arena.label = nil
		sendToViewers(arena, idleState(arena))
	end)
end

-- Admin chat commands ---------------------------------------------------------
--   /coins <amount> [player|me|all]   give (or take, with a negative number) coins
--   /nuke [player|me|all] [count]     give Nuclear Bombs
--   /commands                         list these
-- A player is matched by the start of their name or display name. Only admins can use them.

local function tell(player, text, isError)
	charResultEvent:FireClient(player, if isError then { error = text } else { message = text })
end

local function findTargets(admin, text)
	text = (text or "me"):lower()
	if text == "me" then
		return { admin }
	elseif text == "all" then
		return Players:GetPlayers()
	end
	local found = {}
	for _, p in Players:GetPlayers() do
		if p.Name:lower():sub(1, #text) == text or p.DisplayName:lower():sub(1, #text) == text then
			table.insert(found, p)
		end
	end
	return found
end

local function describe(targets)
	return #targets == 1 and targets[1].DisplayName or `{#targets} players`
end

local function runCommand(admin, name, args)
	if not isAdmin(admin) then
		tell(admin, "Only admins can use that command.", true)
		return
	end
	if name == "coins" then
		local amount = math.floor(tonumber(args[1] or "") or 0)
		if amount == 0 or math.abs(amount) > 1000000 then
			tell(admin, "Usage: /coins <amount> [player|me|all]", true)
			return
		end
		local targets = findTargets(admin, args[2])
		if #targets == 0 then
			tell(admin, `No player matches "{args[2]}".`, true)
			return
		end
		for _, p in targets do
			local profile = getProfile(p)
			profile.coins = math.max(0, profile.coins + amount)
			sendProfile(p)
			task.spawn(saveProfile, p)
			if p ~= admin then
				tell(p, `An admin gave you {amount} coins!`)
			end
		end
		tell(admin, `Gave {amount} coins to {describe(targets)}.`)
	elseif name == "nuke" then
		local count = math.clamp(math.floor(tonumber(args[2] or "1") or 1), 1, 99)
		local targets = findTargets(admin, args[1])
		if #targets == 0 then
			tell(admin, `No player matches "{args[1]}".`, true)
			return
		end
		for _, p in targets do
			local profile = getProfile(p)
			profile.abilities.NuclearBomb = (profile.abilities.NuclearBomb or 0) + count
			sendProfile(p)
			task.spawn(saveProfile, p)
			if p ~= admin then
				tell(p, `An admin gave you {count} Nuclear Bomb(s)! Arm it on your turn, or press T in a Free For All.`)
			end
		end
		tell(admin, `Gave {count} Nuclear Bomb(s) to {describe(targets)}.`)
	elseif name == "commands" then
		tell(admin, "/coins <amount> [player|me|all]   /nuke [player|me|all] [count]")
	end
end

local COMMANDS = { "coins", "nuke", "commands" }

local function handleChat(player, message)
	local words = {}
	for word in message:gmatch("%S+") do
		table.insert(words, word)
	end
	local name = words[1] and words[1]:lower():match("^/(%a+)$")
	if name and table.find(COMMANDS, name) then
		table.remove(words, 1)
		runCommand(player, name, words)
	end
end

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	for _, name in COMMANDS do
		local command = Instance.new("TextChatCommand")
		command.Name = `PizzaCommand_{name}`
		command.PrimaryAlias = `/{name}`
		command.Parent = TextChatService
		command.Triggered:Connect(function(source, text)
			local player = Players:GetPlayerByUserId(source.UserId)
			if player then
				handleChat(player, text)
			end
		end)
	end
else
	-- legacy chat
	local function watch(player)
		player.Chatted:Connect(function(message)
			handleChat(player, message)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

-- Free For All matchmaking: its own waiting area and queue ----------------------

-- The kiosk cycles the number of bots for the next Free For All: 0, 1, 2 ... max, then back to 0.
map.ffaBotPrompt.Triggered:Connect(function(player)
	if not inFFAZone[player] or ffaArena.busy then
		return
	end
	ffaBots = (ffaBots + 1) % (Config.FFAMaxBots + 1)
	charResultEvent:FireClient(player, {
		message = `Free For All bots: {ffaBots} (the kiosk adds one each press and wraps to 0 after {Config.FFAMaxBots})`,
	})
end)

local function getFFAQueue()
	local list = {}
	for _, p in Players:GetPlayers() do
		if ready[p] and inFFAZone[p] and not reserved[p] then
			table.insert(list, p)
		end
	end
	table.sort(list, function(x, y)
		return ffaZoneSince[x] < ffaZoneSince[y]
	end)
	return list
end

local function startFFA(queue)
	local humans = {}
	for i = 1, math.min(#queue, Config.FFAMaxPlayers) do
		humans[i] = queue[i]
	end
	ffaArena.busy = true
	ffaArena.label = `{#humans} player(s) + {math.min(ffaBots, Config.FFAMaxPlayers - #humans)} bot(s)`
	for _, p in humans do
		reserved[p] = true
	end

	task.spawn(function()
		local cancelled = false
		for s = Config.FFACountdown, 1, -1 do
			-- anyone who walks out of the waiting area drops out; too few fighters cancels the start
			local here = {}
			for _, p in humans do
				if p.Parent == Players and inFFAZone[p] then
					table.insert(here, p)
				else
					reserved[p] = nil
					ffaPending[p] = nil
				end
			end
			humans = here
			local bots = math.min(ffaBots, Config.FFAMaxPlayers - #humans)
			if #humans < 1 or #humans + bots < Config.FFAMinPlayers then
				cancelled = true
				break
			end
			for _, p in humans do
				ffaPending[p] = s
			end
			task.wait(1)
		end
		for _, p in humans do
			ffaPending[p] = nil
		end

		if not cancelled and #humans >= 1 then
			local fighters = {}
			for _, p in humans do
				table.insert(fighters, newFighter(p))
				fightingArena[p] = ffaArena
			end
			local level = getBotLevel(Config.FFABotLevel) or Config.BotLevels[2]
			for i = 1, math.min(ffaBots, Config.FFAMaxPlayers - #humans) do
				local bot = makeBot(level)
				bot.name = `PizzaBot {i}`
				bot.userId = -100 - i
				bot.aimError = level.aimError
				table.insert(fighters, bot)
			end

			local ok, err = pcall(runFFA, ffaArena, fighters)
			if not ok then
				warn("Free For All error: " .. tostring(err))
				for _, f in fighters do
					if not f.isBot and f.player.Parent == Players then
						f.player:LoadCharacter()
					end
				end
			end
			for _, f in fighters do
				if f.isBot and f.model.Parent then
					f.model:Destroy()
				end
				if not f.isBot then
					ffaPlayers[f.player] = nil
				end
			end
		end

		for _, p in humans do
			reserved[p] = nil
			fightingArena[p] = nil
		end
		ffaBots = 0
		ffaArena.busy = false
		ffaArena.label = nil
		sendToViewers(ffaArena, idleState(ffaArena))
	end)
end

task.spawn(function()
	while true do
		task.wait(0.5)
		if not ffaArena.busy then
			local queue = getFFAQueue()
			if #queue >= 1 and #queue + ffaBots >= Config.FFAMinPlayers then
				startFFA(queue)
			end
		end
	end
end)

while true do
	local arena
	for _, a in arenas do
		if not a.busy then
			arena = a
			break
		end
	end

	if arena then
		local queue = getQueue()
		local playerA, playerB, levelId
		for _, p in queue do
			if botChoice[p] then
				playerA, levelId = p, botChoice[p]
				break
			end
		end
		if not playerA and #queue >= 2 then
			playerA, playerB = queue[1], queue[2]
		end
		if playerA then
			startMatch(arena, playerA, playerB, levelId)
		end
	end
	task.wait(0.25)
end
