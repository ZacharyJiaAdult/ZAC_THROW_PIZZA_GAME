local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("BattleRemotes")
local stateEvent = remotes:WaitForChild("State")
local throwEvent = remotes:WaitForChild("Throw")

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

local turnToken = 0

throwButton.Activated:Connect(function()
	turnToken += 1
	throwButton.Visible = false
	throwEvent:FireServer()
end)

stateEvent.OnClientEvent:Connect(function(state)
	turnToken += 1
	message.Text = state.message or ""

	if state.round and state.round > 0 then
		roundLabel.Text = state.round > state.maxRounds and "SUDDEN DEATH"
			or `Round {state.round} / {state.maxRounds}`
	else
		roundLabel.Text = "Pizza Battle"
	end

	for i, bar in bars do
		local fighter = state.fighters and state.fighters[i]
		bar.bg.Visible = fighter ~= nil
		if fighter then
			local ratio = math.clamp(fighter.hp / state.maxHp, 0, 1)
			bar.text.Text = `{fighter.name}  {fighter.hp}/{state.maxHp}`
			bar.stroke.Enabled = state.phase == "turn" and state.turnUserId == fighter.userId
			TweenService:Create(bar.fill, TweenInfo.new(0.4), {
				Size = UDim2.fromScale(ratio, 1),
				BackgroundColor3 = Color3.fromHSV(0.33 * ratio, 0.75, 0.85),
			}):Play()
		end
	end

	local myTurn = state.phase == "turn" and state.turnUserId == player.UserId
	throwButton.Visible = myTurn
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
