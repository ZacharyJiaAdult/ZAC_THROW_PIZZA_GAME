local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("BattleConfig"))

local remotes = Instance.new("Folder")
remotes.Name = "BattleRemotes"
local stateEvent = Instance.new("RemoteEvent")
stateEvent.Name = "State"
stateEvent.Parent = remotes
local throwEvent = Instance.new("RemoteEvent")
throwEvent.Name = "Throw"
throwEvent.Parent = remotes
remotes.Parent = ReplicatedStorage

local ARENA_CENTER = Vector3.new(0, 300, 0)
local PAD_OFFSET = 18

local floor = Instance.new("Part")
floor.Name = "ArenaFloor"
floor.Anchored = true
floor.Size = Vector3.new(60, 2, 30)
floor.Position = ARENA_CENTER
floor.Material = Enum.Material.Slate
floor.Color = Color3.fromRGB(190, 70, 55)
floor.Parent = workspace

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
	return { player = player, name = player.DisplayName, userId = player.UserId, hp = Config.StartingHealth }
end

local function makeBot()
	local model = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	model.Name = "PizzaBot"
	model.Parent = workspace
	return { isBot = true, model = model, name = "PizzaBot", userId = -1, hp = Config.StartingHealth }
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
	local conn = throwEvent.OnServerEvent:Connect(function(sender)
		if sender == player then
			thrown = true
		end
	end)
	local started = os.clock()
	while not thrown and player.Parent == Players and os.clock() - started < Config.TurnSeconds do
		task.wait(0.1)
	end
	conn:Disconnect()
end

local function rollDice(f)
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
			waitForThrow(f)

			send("rolling", match, `{f.name} rolls the d{Config.DieSides}...`)
			local roll, die = rollDice(f)
			send("rolling", match, `{f.name} rolled a {roll}!`)
			task.wait(0.6)
			die:Destroy()

			throwPizza(f, foe)
			foe.hp = math.max(0, foe.hp - roll)
			flash(foe)
			send("hit", match, `{f.name} hits {foe.name} for {roll} damage!`)
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

-- Lobby loop -----------------------------------------------------------------

while true do
	local queue = Players:GetPlayers()
	local needed = Config.BotEnabled and 1 or Config.MinPlayers
	if #queue < needed then
		broadcast({ phase = "lobby", message = `Waiting for players ({#queue}/{needed})...` })
		task.wait(1)
	else
		for i = #queue, 2, -1 do
			local j = math.random(1, i)
			queue[i], queue[j] = queue[j], queue[i]
		end
		for s = Config.IntermissionSeconds, 1, -1 do
			broadcast({ phase = "lobby", message = `Match starts in {s}...` })
			task.wait(1)
		end
		local p1, p2 = queue[1], queue[2]
		if p1.Parent == Players and (not p2 or p2.Parent == Players) then
			-- With one player in the server, the practice bot fills the second slot.
			local fighterA = newFighter(p1)
			local fighterB = p2 and newFighter(p2) or makeBot()
			runMatch(fighterA, fighterB)
		end
	end
end
