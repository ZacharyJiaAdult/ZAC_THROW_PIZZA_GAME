-- Builds the map at server start: a Waiting Area with a bot kiosk, and several arenas with spectator stands.
-- Layout (north is -Z, the baseplate top is y = 0, the spawn is at the origin):
--   spawn (0, 0, 0)  ->  Waiting Area (z -60..-30)  ->  a row of arenas along z = -130, spaced 100 studs apart
local ArenaMap = {}

local ARENA_Z = -130
local ARENA_SPACING = 100

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
	titleLabel.Size = UDim2.fromScale(1, subtitle and 0.6 or 1)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = Color3.fromRGB(255, 220, 60)
	titleLabel.Text = title
	titleLabel.Parent = gui

	if subtitle then
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
end

-- One arena: floor, fighter pads, glass walls, two stands and a name board.
local function buildArena(map, id, center)
	local cx, cz = center.X, center.Z

	part(map, {
		Name = `Arena{id}Floor`,
		Size = Vector3.new(60, 2, 30),
		Position = center,
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(190, 70, 55),
	})
	for side, color in { [-1] = Color3.fromRGB(70, 130, 220), [1] = Color3.fromRGB(240, 130, 40) } do
		part(map, {
			Name = `Arena{id}Pad`,
			Size = Vector3.new(10, 0.2, 10),
			Position = center + Vector3.new(side * 18, 1.1, 0),
			Material = Enum.Material.Neon,
			Color = color,
			CanCollide = false,
		})
	end

	-- Glass walls keep spectators out of the arena but let them watch
	local function wall(name, size, position)
		part(map, {
			Name = `Arena{id}{name}`,
			Size = size,
			Position = position,
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(180, 220, 255),
			Transparency = 0.85,
		})
	end
	wall("GlassSouth", Vector3.new(62, 14, 1), Vector3.new(cx, 9, cz + 16))
	wall("GlassNorth", Vector3.new(62, 14, 1), Vector3.new(cx, 9, cz - 16))
	wall("GlassWest", Vector3.new(1, 14, 33), Vector3.new(cx - 31, 9, cz))
	wall("GlassEast", Vector3.new(1, 14, 33), Vector3.new(cx + 31, 9, cz))

	-- Spectator stands on both long sides, four rising tiers each
	for tier = 1, 4 do
		local height = tier * 2
		local color = if tier % 2 == 0 then Color3.fromRGB(120, 120, 130) else Color3.fromRGB(90, 90, 100)
		part(map, {
			Name = `Arena{id}StandSouth`,
			Size = Vector3.new(70, height, 3),
			Position = Vector3.new(cx, height / 2, cz + 18 + (tier - 1) * 3),
			Material = Enum.Material.Concrete,
			Color = color,
		})
		part(map, {
			Name = `Arena{id}StandNorth`,
			Size = Vector3.new(70, height, 3),
			Position = Vector3.new(cx, height / 2, cz - 18 - (tier - 1) * 3),
			Material = Enum.Material.Concrete,
			Color = color,
		})
	end

	-- Name board behind the north stand, readable from the south stand
	for _, dx in { -12, 12 } do
		part(map, {
			Name = `Arena{id}SignPost`,
			Size = Vector3.new(2, 14, 2),
			Position = Vector3.new(cx + dx, 7, cz - 35),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(110, 75, 45),
		})
	end
	local board = part(map, {
		Name = `Arena{id}Sign`,
		Size = Vector3.new(30, 6, 1),
		Position = Vector3.new(cx, 15, cz - 35),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(40, 30, 35),
	})
	addSignText(board, Enum.NormalId.Back, `ARENA {id}`, nil)
end

-- Free For All: a big open arena with cover pillars, glass walls and stands on both long sides.
local FFA_ARENA_X = 250
local FFA_WAITING_X = 150

local function buildFFAArena(map, center)
	local cx, cz = center.X, center.Z

	part(map, {
		Name = "FFAFloor",
		Size = Vector3.new(80, 2, 80),
		Position = center,
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(95, 65, 145),
	})
	-- cover to hide behind: thrown pizzas splat against these
	for _, offset in { { -14, -14 }, { 14, -14 }, { -14, 14 }, { 14, 14 } } do
		part(map, {
			Name = "FFAPillar",
			Size = Vector3.new(6, 12, 6),
			Position = Vector3.new(cx + offset[1], 8, cz + offset[2]),
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(120, 110, 140),
		})
	end

	local function wall(name, size, position)
		part(map, {
			Name = name,
			Size = size,
			Position = position,
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(190, 170, 235),
			Transparency = 0.85,
		})
	end
	wall("FFAGlassSouth", Vector3.new(84, 14, 1), Vector3.new(cx, 9, cz + 41))
	wall("FFAGlassNorth", Vector3.new(84, 14, 1), Vector3.new(cx, 9, cz - 41))
	wall("FFAGlassWest", Vector3.new(1, 14, 84), Vector3.new(cx - 41, 9, cz))
	wall("FFAGlassEast", Vector3.new(1, 14, 84), Vector3.new(cx + 41, 9, cz))

	for tier = 1, 4 do
		local height = tier * 2
		local color = if tier % 2 == 0 then Color3.fromRGB(125, 110, 150) else Color3.fromRGB(95, 85, 120)
		part(map, {
			Name = "FFAStandSouth",
			Size = Vector3.new(90, height, 3),
			Position = Vector3.new(cx, height / 2, cz + 44 + (tier - 1) * 3),
			Material = Enum.Material.Concrete,
			Color = color,
		})
		part(map, {
			Name = "FFAStandNorth",
			Size = Vector3.new(90, height, 3),
			Position = Vector3.new(cx, height / 2, cz - 44 - (tier - 1) * 3),
			Material = Enum.Material.Concrete,
			Color = color,
		})
	end

	for _, dx in { -14, 14 } do
		part(map, {
			Name = "FFASignPost",
			Size = Vector3.new(2, 16, 2),
			Position = Vector3.new(cx + dx, 8, cz - 62),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(110, 75, 45),
		})
	end
	local board = part(map, {
		Name = "FFASign",
		Size = Vector3.new(34, 7, 1),
		Position = Vector3.new(cx, 18, cz - 62),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(40, 30, 35),
	})
	addSignText(board, Enum.NormalId.Back, "FREE FOR ALL", nil)
end

-- The Free For All's own waiting area, with a kiosk that adds bots so a small group can still play.
local function buildFFAWaiting(map)
	part(map, {
		Name = "FFAWaitingFrame",
		Size = Vector3.new(64, 0.9, 34),
		Position = Vector3.new(FFA_WAITING_X, 0.45, -45),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(200, 90, 255),
	})
	local zone = part(map, {
		Name = "FFAWaitingZone",
		Size = Vector3.new(60, 1, 30),
		Position = Vector3.new(FFA_WAITING_X, 0.5, -45),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(120, 70, 190),
	})
	for _, dx in { -20, 20 } do
		part(map, {
			Name = "FFASignPost",
			Size = Vector3.new(2, 12, 2),
			Position = Vector3.new(FFA_WAITING_X + dx, 6, -61),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(110, 75, 45),
		})
	end
	local board = part(map, {
		Name = "FFAWaitingSign",
		Size = Vector3.new(44, 10, 1),
		Position = Vector3.new(FFA_WAITING_X, 13, -61),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(40, 30, 35),
	})
	addSignText(board, Enum.NormalId.Back, "FREE FOR ALL", "Real-time brawl: last one standing wins")

	local kiosk = part(map, {
		Name = "FFABotKiosk",
		Size = Vector3.new(5, 4, 5),
		Position = Vector3.new(FFA_WAITING_X + 22, 3, -45),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(160, 60, 200),
	})
	local kioskGui = Instance.new("BillboardGui")
	kioskGui.Size = UDim2.fromOffset(220, 50)
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
	kioskLabel.Text = "ADD BOTS"
	kioskLabel.Parent = kioskGui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Add a bot"
	prompt.ObjectText = "Free For All bots"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = kiosk
	return zone, prompt
end

function ArenaMap.build(count)
	local old = workspace:FindFirstChild("PizzaMap")
	if old then
		old:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "PizzaMap"
	map.Parent = workspace

	-- Arenas -----------------------------------------------------------------
	local arenas = {}
	for id = 1, count do
		local cx = (id - (count + 1) / 2) * ARENA_SPACING
		local center = Vector3.new(cx, 1, ARENA_Z)
		buildArena(map, id, center)
		arenas[id] = {
			id = id,
			center = center,
			-- anyone inside this box (the stands and the arena) is watching this arena
			regionCFrame = CFrame.new(cx, 10, ARENA_Z),
			regionSize = Vector3.new(80, 40, 72),
			-- a random seat in the south stand (third tier), facing the arena
			standsSpot = function()
				local pos = Vector3.new(cx + math.random(-25, 25), 9.5, ARENA_Z + 24)
				return CFrame.lookAt(pos, Vector3.new(cx, pos.Y, ARENA_Z))
			end,
		}
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

	-- Bot kiosk: use the prompt to pick a bot difficulty instead of waiting for a person
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
	prompt.ActionText = "Choose a bot"
	prompt.ObjectText = "Practice Bot"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = kiosk

	-- Administrator Trophy: a golden cup on a pedestal. Only the owner can claim it (the server checks).
	local pedestal = part(map, {
		Name = "TrophyPedestal",
		Size = Vector3.new(6, 3, 6),
		Position = Vector3.new(-22, 2.5, -45),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(40, 35, 45),
	})
	local gold = { Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 200, 50), CanCollide = false }
	local function goldPart(name, shape, size, cframe)
		return part(map, {
			Name = name,
			Shape = shape,
			Size = size,
			CFrame = cframe,
			Material = gold.Material,
			Color = gold.Color,
			CanCollide = gold.CanCollide,
		})
	end
	local upright = CFrame.Angles(0, 0, math.pi / 2) -- cylinders lie along X; stand them up
	goldPart("TrophyBase", Enum.PartType.Block, Vector3.new(3.4, 0.6, 3.4), CFrame.new(-22, 4.3, -45))
	goldPart("TrophyStem", Enum.PartType.Cylinder, Vector3.new(3, 0.9, 0.9), CFrame.new(-22, 6.1, -45) * upright)
	local bowl = goldPart("TrophyBowl", Enum.PartType.Cylinder, Vector3.new(3.6, 4.2, 4.2), CFrame.new(-22, 9.4, -45) * upright)
	goldPart("TrophyHandleL", Enum.PartType.Ball, Vector3.new(1.8, 1.8, 1.8), CFrame.new(-24.4, 9.6, -45))
	goldPart("TrophyHandleR", Enum.PartType.Ball, Vector3.new(1.8, 1.8, 1.8), CFrame.new(-19.6, 9.6, -45))
	goldPart("TrophyStar", Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6), CFrame.new(-22, 11.9, -45))
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 210, 90)
	glow.Brightness = 2
	glow.Range = 22
	glow.Parent = bowl

	local trophyGui = Instance.new("BillboardGui")
	trophyGui.Size = UDim2.fromOffset(260, 70)
	trophyGui.StudsOffset = Vector3.new(0, 7.5, 0)
	trophyGui.AlwaysOnTop = true
	trophyGui.Parent = pedestal
	local trophyTitle = Instance.new("TextLabel")
	trophyTitle.Size = UDim2.fromScale(1, 0.62)
	trophyTitle.BackgroundTransparency = 1
	trophyTitle.Font = Enum.Font.GothamBlack
	trophyTitle.TextScaled = true
	trophyTitle.TextColor3 = Color3.fromRGB(255, 215, 80)
	trophyTitle.TextStrokeTransparency = 0
	trophyTitle.Text = "ADMINISTRATOR TROPHY"
	trophyTitle.Parent = trophyGui
	local trophyNote = Instance.new("TextLabel")
	trophyNote.Position = UDim2.fromScale(0, 0.62)
	trophyNote.Size = UDim2.fromScale(1, 0.38)
	trophyNote.BackgroundTransparency = 1
	trophyNote.Font = Enum.Font.GothamBold
	trophyNote.TextScaled = true
	trophyNote.TextColor3 = Color3.fromRGB(255, 110, 110)
	trophyNote.TextStrokeTransparency = 0
	trophyNote.Text = "Owner only"
	trophyNote.Parent = trophyGui

	local trophyPrompt = Instance.new("ProximityPrompt")
	trophyPrompt.ActionText = "Claim"
	trophyPrompt.ObjectText = "Administrator Trophy (owner only)"
	trophyPrompt.HoldDuration = 1.5
	trophyPrompt.MaxActivationDistance = 10
	trophyPrompt.RequiresLineOfSight = false
	trophyPrompt.Parent = pedestal

	-- Free For All -----------------------------------------------------------
	local ffaCenter = Vector3.new(FFA_ARENA_X, 1, ARENA_Z)
	buildFFAArena(map, ffaCenter)
	local ffaZone, ffaPrompt = buildFFAWaiting(map)

	-- a signpost in the main Waiting Area pointing east
	local pointer = part(map, {
		Name = "FFAPointer",
		Size = Vector3.new(28, 6, 1),
		Position = Vector3.new(44, 8, -62),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(40, 30, 35),
	})
	addSignText(pointer, Enum.NormalId.Back, "FREE FOR ALL >>>", nil)

	local ffa = {
		id = "FFA",
		name = "Free For All",
		center = ffaCenter,
		regionCFrame = CFrame.new(FFA_ARENA_X, 10, ARENA_Z),
		regionSize = Vector3.new(100, 40, 112),
		-- one spawn point per fighter, evenly around the arena, all facing the middle
		spawnPoints = function(n)
			local points = {}
			for i = 1, n do
				local angle = (i - 1) / n * math.pi * 2
				local pos = ffaCenter + Vector3.new(math.cos(angle) * 28, 4, math.sin(angle) * 28)
				points[i] = CFrame.lookAt(pos, Vector3.new(ffaCenter.X, pos.Y, ffaCenter.Z))
			end
			return points
		end,
		standsSpot = function()
			local pos = Vector3.new(FFA_ARENA_X + math.random(-30, 30), 9.5, ARENA_Z + 50)
			return CFrame.lookAt(pos, Vector3.new(FFA_ARENA_X, pos.Y, ARENA_Z))
		end,
	}

	local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation")

	return {
		folder = map,
		arenas = arenas,
		zone = zone,
		botPrompt = prompt,
		trophyPrompt = trophyPrompt,
		ffa = ffa,
		ffaZone = ffaZone,
		ffaBotPrompt = ffaPrompt,
		lobbySpot = function()
			if spawnLocation then
				return spawnLocation.CFrame + Vector3.new(0, 4, 0)
			end
			return CFrame.new(0, 5, 0)
		end,
	}
end

return ArenaMap
