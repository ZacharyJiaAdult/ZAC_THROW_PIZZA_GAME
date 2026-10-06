-- Dresses the world around the play areas: a grass ground with dirt patches, winding stone paths with lamps,
-- trees, rocks, bushes, flowers and distant hills. A fixed random seed keeps the map identical every time,
-- but nothing is laid out on a grid, so it never reads as a repeating pattern.
local Scenery = {}

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

-- distance on the ground plane from (px, pz) to the segment a-b
local function distanceToSegment(px, pz, a, b)
	local abx, abz = b.X - a.X, b.Z - a.Z
	local lengthSquared = abx * abx + abz * abz
	local t = 0
	if lengthSquared > 0 then
		t = math.clamp(((px - a.X) * abx + (pz - a.Z) * abz) / lengthSquared, 0, 1)
	end
	local cx, cz = a.X + abx * t, a.Z + abz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

-- exclusions: { { x, z, hx, hz }, ... } rectangles to keep clear. paths: { { Vector3, ... }, ... } polylines.
function Scenery.build(parent, exclusions, paths)
	local rng = Random.new(2026)
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = parent

	local function blocked(x, z, margin)
		for _, rect in exclusions do
			if math.abs(x - rect.x) < rect.hx + margin and math.abs(z - rect.z) < rect.hz + margin then
				return true
			end
		end
		for _, path in paths do
			for i = 1, #path - 1 do
				if distanceToSegment(x, z, path[i], path[i + 1]) < margin + 6 then
					return true
				end
			end
		end
		return false
	end

	-- Ground ---------------------------------------------------------------
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		for _, child in baseplate:GetChildren() do
			if child:IsA("Texture") or child:IsA("Decal") then
				child:Destroy() -- the grid texture is what made the ground look tiled
			end
		end
		baseplate.Material = Enum.Material.Grass
		baseplate.Color = Color3.fromRGB(96, 140, 72)
	end

	-- patches of dirt, lighter grass and sand, in uneven sizes
	local patchColors = {
		{ Enum.Material.Ground, Color3.fromRGB(125, 100, 70) },
		{ Enum.Material.Grass, Color3.fromRGB(118, 160, 84) },
		{ Enum.Material.Sand, Color3.fromRGB(196, 178, 128) },
		{ Enum.Material.Grass, Color3.fromRGB(80, 122, 62) },
	}
	for _ = 1, 45 do
		local x, z = rng:NextNumber(-450, 540), rng:NextNumber(-330, 150)
		if not blocked(x, z, 6) then
			local choice = patchColors[rng:NextInteger(1, #patchColors)]
			local width, depth = rng:NextNumber(12, 42), rng:NextNumber(12, 42)
			part(folder, {
				Name = "GroundPatch",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.2, width, depth),
				CFrame = CFrame.new(x, 0.08, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.pi / 2),
				Material = choice[1],
				Color = choice[2],
				CanCollide = false,
			})
		end
	end

	-- Paths and lamps ----------------------------------------------------------
	local stoneColors = { Color3.fromRGB(150, 142, 128), Color3.fromRGB(135, 128, 116), Color3.fromRGB(160, 150, 130) }
	for _, path in paths do
		local travelled, nextLamp, lampSide = 0, 14, 1
		for i = 1, #path - 1 do
			local a, b = path[i], path[i + 1]
			local delta = b - a
			local length = delta.Magnitude
			local dir = delta.Unit
			local side = Vector3.new(-dir.Z, 0, dir.X)
			local steps = math.max(1, math.floor(length / 11))
			for s = 0, steps - 1 do
				local p0 = a + delta * (s / steps) + side * rng:NextNumber(-1.3, 1.3)
				local p1 = a + delta * ((s + 1) / steps) + side * rng:NextNumber(-1.3, 1.3)
				local mid = (p0 + p1) / 2
				part(folder, {
					Name = "PathStone",
					Size = Vector3.new(rng:NextNumber(8, 11), 0.3, (p1 - p0).Magnitude + 1.5),
					CFrame = CFrame.lookAt(Vector3.new(mid.X, 0.15, mid.Z), Vector3.new(p1.X, 0.15, p1.Z)),
					Material = Enum.Material.Cobblestone,
					Color = stoneColors[rng:NextInteger(1, #stoneColors)],
				})
				travelled += (p1 - p0).Magnitude
				if travelled >= nextLamp then
					nextLamp = travelled + rng:NextNumber(26, 40)
					lampSide = -lampSide
					local at = mid + side * (7 * lampSide)
					part(folder, {
						Name = "LampPole",
						Shape = Enum.PartType.Cylinder,
						Size = Vector3.new(9, 0.8, 0.8),
						CFrame = CFrame.new(at.X, 4.5, at.Z) * CFrame.Angles(0, 0, math.pi / 2),
						Material = Enum.Material.Metal,
						Color = Color3.fromRGB(50, 50, 55),
						CanCollide = false,
					})
					local head = part(folder, {
						Name = "LampHead",
						Shape = Enum.PartType.Ball,
						Size = Vector3.new(2.2, 2.2, 2.2),
						Position = Vector3.new(at.X, 9.6, at.Z),
						Material = Enum.Material.Neon,
						Color = Color3.fromRGB(255, 220, 140),
						CanCollide = false,
					})
					local light = Instance.new("PointLight")
					light.Color = Color3.fromRGB(255, 215, 150)
					light.Brightness = 1.2
					light.Range = 26
					light.Parent = head
				end
			end
		end
	end

	-- Trees: two shapes, random sizes and greens, never closer than 11 studs to each other ---------
	local trees = {}
	local function farFromTrees(x, z)
		for _, t in trees do
			if (t[1] - x) ^ 2 + (t[2] - z) ^ 2 < 121 then
				return false
			end
		end
		return true
	end
	for _ = 1, 600 do
		if #trees >= 85 then
			break
		end
		local x, z = rng:NextNumber(-440, 530), rng:NextNumber(-330, 150)
		if not blocked(x, z, 10) and farFromTrees(x, z) then
			table.insert(trees, { x, z })
			local height = rng:NextNumber(8, 17)
			local trunkWidth = rng:NextNumber(1.4, 2.4)
			part(folder, {
				Name = "TreeTrunk",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(height, trunkWidth, trunkWidth),
				CFrame = CFrame.new(x, height / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
				Material = Enum.Material.Wood,
				Color = Color3.fromRGB(100 + rng:NextInteger(0, 30), 68 + rng:NextInteger(0, 20), 40),
			})
			local leaf = Color3.fromHSV(rng:NextNumber(0.24, 0.36), rng:NextNumber(0.45, 0.7), rng:NextNumber(0.4, 0.65))
			if rng:NextInteger(1, 2) == 1 then
				for _ = 1, 3 do
					local d = rng:NextNumber(8, 14)
					part(folder, {
						Name = "TreeCrown",
						Shape = Enum.PartType.Ball,
						Size = Vector3.new(d, d, d),
						Position = Vector3.new(x + rng:NextNumber(-2.5, 2.5), height + rng:NextNumber(0, 4), z + rng:NextNumber(-2.5, 2.5)),
						Material = Enum.Material.Grass,
						Color = leaf,
						CanCollide = false,
					})
				end
			else
				for level = 0, 2 do
					local d = 11 - level * 3
					part(folder, {
						Name = "PineCrown",
						Shape = Enum.PartType.Ball,
						Size = Vector3.new(d, d * 0.9, d),
						Position = Vector3.new(x, height * 0.7 + level * 4.2, z),
						Material = Enum.Material.Grass,
						Color = leaf:Lerp(Color3.fromRGB(20, 70, 40), 0.4),
						CanCollide = false,
					})
				end
			end
		end
	end

	-- Rocks: lumpy blocks, tilted and half buried -------------------------------------------------
	local rocks = 0
	for _ = 1, 200 do
		if rocks >= 55 then
			break
		end
		local x, z = rng:NextNumber(-440, 530), rng:NextNumber(-330, 150)
		if not blocked(x, z, 6) then
			rocks += 1
			local size = Vector3.new(rng:NextNumber(3, 9), rng:NextNumber(2, 6), rng:NextNumber(3, 9))
			local grey = rng:NextInteger(95, 150)
			part(folder, {
				Name = "Rock",
				Size = size,
				CFrame = CFrame.new(x, size.Y / 2 - 0.6, z)
					* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.3, 0.3)),
				Material = if rng:NextInteger(1, 2) == 1 then Enum.Material.Slate else Enum.Material.Rock,
				Color = Color3.fromRGB(grey, grey - 4, grey - 10),
			})
		end
	end

	-- Bushes and flowers, in small clusters --------------------------------------------------------
	local flowerColors = {
		Color3.fromRGB(235, 70, 80),
		Color3.fromRGB(250, 220, 70),
		Color3.fromRGB(245, 140, 190),
		Color3.fromRGB(245, 245, 245),
		Color3.fromRGB(170, 110, 230),
	}
	for _ = 1, 70 do
		local x, z = rng:NextNumber(-440, 530), rng:NextNumber(-330, 150)
		if not blocked(x, z, 4) then
			for _ = 1, rng:NextInteger(1, 3) do
				local d = rng:NextNumber(3, 5.5)
				part(folder, {
					Name = "Bush",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(d, d * 0.8, d),
					Position = Vector3.new(x + rng:NextNumber(-3, 3), d * 0.35, z + rng:NextNumber(-3, 3)),
					Material = Enum.Material.Grass,
					Color = Color3.fromHSV(rng:NextNumber(0.25, 0.34), 0.6, rng:NextNumber(0.35, 0.55)),
					CanCollide = false,
				})
			end
		end
	end
	for _ = 1, 40 do
		local x, z = rng:NextNumber(-440, 530), rng:NextNumber(-330, 150)
		if not blocked(x, z, 3) then
			local color = flowerColors[rng:NextInteger(1, #flowerColors)]
			for _ = 1, rng:NextInteger(3, 6) do
				part(folder, {
					Name = "Flower",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(0.9, 0.9, 0.9),
					Position = Vector3.new(x + rng:NextNumber(-3, 3), 0.5, z + rng:NextNumber(-3, 3)),
					Material = Enum.Material.SmoothPlastic,
					Color = color,
					CanCollide = false,
				})
			end
		end
	end

	-- Hills on the outskirts, well away from every play area and path -------------------------------
	local hills = 0
	for _ = 1, 300 do
		if hills >= 10 then
			break
		end
		local x, z = rng:NextNumber(-520, 620), rng:NextNumber(-420, 220)
		local diameter = rng:NextNumber(70, 150)
		-- keep to the outer ring: far from the central strip where everything is built
		local far = z < -270 or z > 80 or x < -250 or x > 400
		if far and not blocked(x, z, diameter / 2 + 10) then
			hills += 1
			part(folder, {
				Name = "Hill",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(diameter, diameter, diameter),
				Position = Vector3.new(x, -diameter * 0.28, z),
				Material = Enum.Material.Grass,
				Color = Color3.fromHSV(rng:NextNumber(0.24, 0.32), rng:NextNumber(0.4, 0.55), rng:NextNumber(0.45, 0.62)),
			})
		end
	end

	return folder
end

return Scenery
