local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("BattleConfig"))
local Items = require(ReplicatedStorage:WaitForChild("BattleItems"))
local ArenaMap = require(script.Parent:WaitForChild("ArenaMap"))

local remotes = Instance.new("Folder")
remotes.Name = "BattleRemotes"
local stateEvent = Instance.new("RemoteEvent")
stateEvent.Name = "State"
stateEvent.Parent = remotes
local throwEvent = Instance.new("RemoteEvent")
throwEvent.Name = "Throw"
throwEvent.Parent = remotes
local startEvent = Instance.new("RemoteEvent")
startEvent.Name = "Start"
startEvent.Parent = remotes
local profileEvent = Instance.new("RemoteEvent")
profileEvent.Name = "Profile"
profileEvent.Parent = remotes
local buyEvent = Instance.new("RemoteEvent")
buyEvent.Name = "BuyCrate"
buyEvent.Parent = remotes
local equipEvent = Instance.new("RemoteEvent")
equipEvent.Name = "Equip"
equipEvent.Parent = remotes
local crateEvent = Instance.new("RemoteEvent")
crateEvent.Name = "CrateResult"
crateEvent.Parent = remotes
local travelEvent = Instance.new("RemoteEvent")
travelEvent.Name = "Travel"
travelEvent.Parent = remotes
remotes.Parent = ReplicatedStorage

-- Players only join the match queue after pressing START on the title screen.
local ready = {}
local waitingSince = {} -- player -> when they stepped into the Waiting Area
local wantsBot = {} -- player -> true once they used the bot kiosk
local inMatch = {} -- player -> true while fighting

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
	waitingSince[player] = nil
	wantsBot[player] = nil
	inMatch[player] = nil
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

local PAD_OFFSET = 18

local map = ArenaMap.build()
local ARENA_CENTER = map.arenaCenter

-- Broadcasting ---------------------------------------------------------------

local latest = { phase = "lobby", message = "Waiting for players..." }

local function broadcast(state)
	latest = state
	stateEvent:FireAllClients(state)
end

Players.PlayerAdded:Connect(function(player)
	task.wait(3)
	stateEvent:FireClient(player, latest)
end)

local function send(phase, match, message, turnUserId)
	local fighters = {}
	for _, f in match.fighters do
		table.insert(fighters, { userId = f.userId, name = f.name, hp = f.hp })
	end
	broadcast({
		phase = phase,
		round = match.round,
		maxRounds = Config.MaxRounds,
		maxHp = Config.StartingHealth,
		fighters = fighters,
		turnUserId = turnUserId,
		turnSeconds = Config.TurnSeconds,
		message = message,
	})
end

-- Fighters (a real player or the practice bot) -------------------------------

local function newFighter(player)
	return {
		player = player,
		name = player.DisplayName,
		userId = player.UserId,
		hp = Config.StartingHealth,
		armour = Items.armourReduction(getProfile(player).equipped),
	}
end

local function makeBot()
	local model = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	model.Name = "PizzaBot"
	model.Parent = workspace
	return { isBot = true, model = model, name = "PizzaBot", userId = -1, hp = Config.StartingHealth, armour = 0 }
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

local function placeFighter(f, side)
	local root = getRoot(f)
	if not root then
		return false
	end
	local pos = ARENA_CENTER + Vector3.new(side * PAD_OFFSET, 4, 0)
	local lookAt = ARENA_CENTER + Vector3.new(-side * PAD_OFFSET, 4, 0)
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

local function waitForThrow(f)
	if f.isBot then
		task.wait(1.5) -- the bot "thinks" for a moment, then throws
		return
	end
	local player = f.player
	local thrown = false
	local chosen -- the ability the player armed, if any (validated by the match loop)
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
	local base = (root and root.Position or ARENA_CENTER) + Vector3.new(0, 6, 0)

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
	if ability == "DoubleDice" then
		roll = math.max(roll, math.random(1, Config.DieSides))
	elseif ability == "LuckyPepperoni" then
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

local function runMatch(a, b)
	local match = { round = 0, fighters = { a, b } }
	local fighters = match.fighters

	if not (placeFighter(a, -1) and placeFighter(b, 1)) then
		for _, f in fighters do
			if f.isBot then
				f.model:Destroy()
			end
		end
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
					f.hp = math.min(Config.StartingHealth, f.hp + Items.HealAmount)
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

	for _, f in fighters do
		if not f.isBot then
			local profile = getProfile(f.player)
			profile.coins += f == winner and Config.WinCoins or Config.LossCoins
			sendProfile(f.player)
		end
	end

	send("over", match, `{winner.name} wins {reason}!`)
	task.wait(Config.ResultSeconds)

	for _, f in fighters do
		if f.isBot then
			f.model:Destroy()
		elseif f.player.Parent == Players then
			f.player:LoadCharacter()
		end
	end
end

-- Waiting Area, bot kiosk and spectating -------------------------------------

local zone = map.zone

local function isInZone(position)
	local rel = zone.CFrame:PointToObjectSpace(position)
	return math.abs(rel.X) <= zone.Size.X / 2 and math.abs(rel.Z) <= zone.Size.Z / 2 and rel.Y > -2 and rel.Y < 12
end

-- Standing in the Waiting Area is what puts a player in the queue.
task.spawn(function()
	while true do
		for _, p in Players:GetPlayers() do
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if root and not inMatch[p] and isInZone(root.Position) then
				waitingSince[p] = waitingSince[p] or os.clock()
			else
				waitingSince[p] = nil
				wantsBot[p] = nil
			end
		end
		task.wait(0.25)
	end
end)

map.botPrompt.Enabled = Config.BotEnabled
map.botPrompt.Triggered:Connect(function(player)
	if Config.BotEnabled and waitingSince[player] then
		wantsBot[player] = true
	end
end)

travelEvent.OnServerEvent:Connect(function(player, where)
	local character = player.Character
	if inMatch[player] or not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	if where == "stands" then
		character:PivotTo(map.standsSpot())
	elseif where == "lobby" then
		character:PivotTo(map.lobbySpot())
	end
end)

-- Lobby loop -----------------------------------------------------------------

local function getQueue()
	local list = {}
	for _, p in Players:GetPlayers() do
		if ready[p] and waitingSince[p] and not inMatch[p] then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b)
		return waitingSince[a] < waitingSince[b]
	end)
	return list
end

local function stillWaiting(p)
	return p.Parent == Players and waitingSince[p] ~= nil and not inMatch[p]
end

while true do
	local queue = getQueue()
	local playerA, playerB, vsBot
	for _, p in queue do
		if wantsBot[p] then
			playerA, vsBot = p, true
			break
		end
	end
	if not playerA and #queue >= 2 then
		playerA, playerB = queue[1], queue[2]
	end

	if not playerA then
		local message = "Step into the Waiting Area to play!"
		if #queue > 0 then
			message = Config.BotEnabled and "Waiting for an opponent... or fight the bot!" or "Waiting for an opponent..."
		end
		broadcast({ phase = "lobby", message = message })
		task.wait(0.5)
		continue
	end

	local versus = vsBot and `{playerA.DisplayName} vs PizzaBot` or `{playerA.DisplayName} vs {playerB.DisplayName}`
	local cancelled = false
	for s = Config.IntermissionSeconds, 1, -1 do
		if not stillWaiting(playerA) or (playerB and not stillWaiting(playerB)) or (vsBot and not wantsBot[playerA]) then
			cancelled = true
			break
		end
		broadcast({ phase = "lobby", message = `{versus} starts in {s}...` })
		task.wait(1)
	end

	if not cancelled and stillWaiting(playerA) and (not playerB or stillWaiting(playerB)) then
		local fighterA = newFighter(playerA)
		local fighterB = vsBot and makeBot() or newFighter(playerB)
		inMatch[playerA] = true
		if playerB then
			inMatch[playerB] = true
		end

		local ok, err = pcall(runMatch, fighterA, fighterB)
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

		inMatch[playerA] = nil
		if playerB then
			inMatch[playerB] = nil
		end
		wantsBot[playerA] = nil
	end
end
