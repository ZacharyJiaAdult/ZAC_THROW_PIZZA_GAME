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

	local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation")

	return {
		folder = map,
		arenas = arenas,
		zone = zone,
		botPrompt = prompt,
		lobbySpot = function()
			if spawnLocation then
				return spawnLocation.CFrame + Vector3.new(0, 4, 0)
			end
			return CFrame.new(0, 5, 0)
		end,
	}
end

return ArenaMap
