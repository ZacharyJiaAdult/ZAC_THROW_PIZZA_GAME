local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("BattleConfig"))
local Items = require(ReplicatedStorage:WaitForChild("BattleItems"))
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

-- Shop profiles live in memory only (no saving yet).
local profiles = {}

local function getProfile(player)
	local profile = profiles[player]
	if not profile then
		profile = { coins = Config.StartingCoins, armour = {}, abilities = {} }
		profiles[player] = profile
	end
	return profile
end

local function sendProfile(player)
	if player.Parent == Players then
		profileEvent:FireClient(player, getProfile(player))
	end
end

startEvent.OnServerEvent:Connect(function(player)
	ready[player] = true
	sendProfile(player)
end)

Players.PlayerRemoving:Connect(function(player)
	ready[player] = nil
	inZone[player] = nil
	zoneSince[player] = nil
	botChoice[player] = nil
	reserved[player] = nil
	fightingArena[player] = nil
	viewing[player] = nil
	pendingInfo[player] = nil
	profiles[player] = nil
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
		if item.rarity == rarity then
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
	return { phase = "lobby", arenaId = arena.id, message = `Arena {arena.id}: no match right now` }
end

local function send(phase, match, message, turnUserId)
	local fighters = {}
	for _, f in match.fighters do
		table.insert(fighters, { userId = f.userId, name = f.name, hp = f.hp, maxHp = f.maxHp })
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
	return {
		player = player,
		name = player.DisplayName,
		userId = player.UserId,
		hp = Config.StartingHealth,
		maxHp = Config.StartingHealth,
		armour = Items.armourReduction(getProfile(player).equipped),
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

local function placeFighter(f, side, arena)
	local root = getRoot(f)
	if not root then
		return false
	end
	local pos = arena.center + Vector3.new(side * PAD_OFFSET, 4, 0)
	local lookAt = arena.center + Vector3.new(-side * PAD_OFFSET, 4, 0)
	getCharacter(f):PivotTo(CFrame.lookAt(pos, lookAt))
	root.Anchored = true
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

local function throwPizza(from, to)
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
end

-- Match ----------------------------------------------------------------------

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

			send("turn", match, `{f.name}: throw the pizza!`, f.userId)
			local ability = waitForThrow(f)

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
			end

			send("rolling", match, `{f.name} rolls the d{Config.DieSides}...`)
			local roll, die = rollDice(f, ability)
			send("rolling", match, `{f.name} rolled a {roll}!`)
			task.wait(0.6)
			die:Destroy()

			local damage = roll
			if ability == "ExtraCheese" then
				damage += Items.CheeseBonus
			end
			local blocked = math.min(foe.armour, damage - 1) -- a hit always does at least 1
			damage -= blocked

			throwPizza(f, foe)
			foe.hp = math.max(0, foe.hp - damage)
			flash(foe)
			local note = blocked > 0 and ` ({blocked} blocked by armour)` or ""
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

-- Waiting Area, arenas, bot kiosk and spectating -----------------------------

local function inBox(cframe, size, position)
	local rel = cframe:PointToObjectSpace(position)
	return math.abs(rel.X) <= size.X / 2 and math.abs(rel.Y) <= size.Y / 2 and math.abs(rel.Z) <= size.Z / 2
end

local function isInZone(position)
	local rel = zone.CFrame:PointToObjectSpace(position)
	return math.abs(rel.X) <= zone.Size.X / 2 and math.abs(rel.Z) <= zone.Size.Z / 2 and rel.Y > -2 and rel.Y < 12
end

-- Tracks who is in the Waiting Area (the queue) and which arena each player is watching.
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

			local arena = fightingArena[p]
			if not arena and position then
				for _, a in arenas do
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
		local status = arenaStatus()
		for _, p in Players:GetPlayers() do
			if not viewing[p] then
				local message = "Step into the Waiting Area to play, or watch a match!"
				local pending = pendingInfo[p]
				if pending then
					message = `Arena {pending.arena.id}: {pending.label} starts in {pending.seconds}...`
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
