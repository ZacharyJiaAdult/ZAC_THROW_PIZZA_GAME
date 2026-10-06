-- Builds the map at server start: a Waiting Area with a bot kiosk, and the arena with spectator stands.
-- Layout (north is -Z, the baseplate top is y = 0, the spawn is at the origin):
--   spawn (0, 0, 0)  ->  Waiting Area (z -60..-30)  ->  stands + arena (z -150..-100)
local ArenaMap = {}

local ARENA_CENTER = Vector3.new(0, 1, -130)
local STAND_SPOT_Z = -106 -- third tier of the south stand

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	p.Parent = parent
	return p
end

local function addSignText(board, face, title, subtitle)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = board

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.fromScale(1, 0.6)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = Color3.fromRGB(255, 220, 60)
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Position = UDim2.fromScale(0, 0.6)
	subtitleLabel.Size = UDim2.fromScale(1, 0.3)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = Enum.Font.GothamBold
	subtitleLabel.TextScaled = true
	subtitleLabel.TextColor3 = Color3.new(1, 1, 1)
	subtitleLabel.Text = subtitle
	subtitleLabel.Parent = gui
end

function ArenaMap.build()
	local old = workspace:FindFirstChild("PizzaMap")
	if old then
		old:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "PizzaMap"
	map.Parent = workspace

	-- Arena ------------------------------------------------------------------
	part(map, {
		Name = "ArenaFloor",
		Size = Vector3.new(60, 2, 30),
		Position = ARENA_CENTER,
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(190, 70, 55),
	})
	for side, color in { [-1] = Color3.fromRGB(70, 130, 220), [1] = Color3.fromRGB(240, 130, 40) } do
		part(map, {
			Name = "FighterPad",
			Size = Vector3.new(10, 0.2, 10),
			Position = ARENA_CENTER + Vector3.new(side * 18, 1.1, 0),
			Material = Enum.Material.Neon,
			Color = color,
			CanCollide = false,
		})
	end

	-- Glass walls keep spectators out of the arena but let them watch
	local glass = {
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(180, 220, 255),
		Transparency = 0.85,
	}
	local function wall(name, size, position)
		part(map, {
			Name = name,
			Size = size,
			Position = position,
			Material = glass.Material,
			Color = glass.Color,
			Transparency = glass.Transparency,
		})
	end
	wall("GlassSouth", Vector3.new(62, 14, 1), Vector3.new(0, 9, -114))
	wall("GlassNorth", Vector3.new(62, 14, 1), Vector3.new(0, 9, -146))
	wall("GlassWest", Vector3.new(1, 14, 33), Vector3.new(-31, 9, -130))
	wall("GlassEast", Vector3.new(1, 14, 33), Vector3.new(31, 9, -130))

	-- Spectator stands on both long sides, four rising tiers each
	for tier = 1, 4 do
		local height = tier * 2
		local color = if tier % 2 == 0 then Color3.fromRGB(120, 120, 130) else Color3.fromRGB(90, 90, 100)
		part(map, {
			Name = "StandSouth",
			Size = Vector3.new(70, height, 3),
			Position = Vector3.new(0, height / 2, -112 + (tier - 1) * 3),
			Material = Enum.Material.Concrete,
			Color = color,
		})
		part(map, {
			Name = "StandNorth",
			Size = Vector3.new(70, height, 3),
			Position = Vector3.new(0, height / 2, -148 - (tier - 1) * 3),
			Material = Enum.Material.Concrete,
			Color = color,
		})
	end

	-- Waiting Area -----------------------------------------------------------
	part(map, {
		Name = "WaitingFrame",
		Size = Vector3.new(64, 0.9, 34),
		Position = Vector3.new(0, 0.45, -45),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 220, 60),
	})
	local zone = part(map, {
		Name = "WaitingZone",
		Size = Vector3.new(60, 1, 30),
		Position = Vector3.new(0, 0.5, -45),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(70, 190, 120),
	})

	for _, x in { -20, 20 } do
		part(map, {
			Name = "SignPost",
			Size = Vector3.new(2, 12, 2),
			Position = Vector3.new(x, 6, -61),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(110, 75, 45),
		})
	end
	local board = part(map, {
		Name = "WaitingSign",
		Size = Vector3.new(44, 10, 1),
		Position = Vector3.new(0, 13, -61),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(40, 30, 35),
	})
	-- Players walk in from the spawn (+Z) and look toward -Z, so they see the sign's Back face
	addSignText(board, Enum.NormalId.Back, "WAITING AREA", "Step inside to join the next match")

	-- Bot kiosk: hold the prompt to fight PizzaBot instead of waiting for a person
	local kiosk = part(map, {
		Name = "BotKiosk",
		Size = Vector3.new(5, 4, 5),
		Position = Vector3.new(22, 3, -45),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(200, 60, 55),
	})
	local kioskGui = Instance.new("BillboardGui")
	kioskGui.Size = UDim2.fromOffset(200, 50)
	kioskGui.StudsOffset = Vector3.new(0, 4, 0)
	kioskGui.AlwaysOnTop = true
	kioskGui.Parent = kiosk
	local kioskLabel = Instance.new("TextLabel")
	kioskLabel.Size = UDim2.fromScale(1, 1)
	kioskLabel.BackgroundTransparency = 1
	kioskLabel.Font = Enum.Font.GothamBlack
	kioskLabel.TextScaled = true
	kioskLabel.TextColor3 = Color3.fromRGB(255, 220, 60)
	kioskLabel.TextStrokeTransparency = 0
	kioskLabel.Text = "FIGHT BOT"
	kioskLabel.Parent = kioskGui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Fight PizzaBot"
	prompt.ObjectText = "Practice Bot"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = kiosk

	local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation")

	return {
		folder = map,
		arenaCenter = ARENA_CENTER,
		zone = zone,
		botPrompt = prompt,
		-- a random seat in the stands, facing the arena
		standsSpot = function()
			local pos = Vector3.new(math.random(-25, 25), 9.5, STAND_SPOT_Z)
			return CFrame.lookAt(pos, Vector3.new(0, pos.Y, ARENA_CENTER.Z))
		end,
		lobbySpot = function()
			if spawnLocation then
				return spawnLocation.CFrame + Vector3.new(0, 4, 0)
			end
			return CFrame.new(0, 5, 0)
		end,
	}
end

return ArenaMap
