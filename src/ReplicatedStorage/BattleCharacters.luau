-- Special characters. Buy one with coins, or with Robux once its developer product is set up.
-- Every character has one unique ability; the server reads the data fields below to apply it.
--   armourBonus       flat damage cut on every hit taken
--   critChance        chance (0-1) that a throw deals double damage
--   healPerTurn       HP healed at the start of each of your turns
--   firstHitBlocked   the first hit taken each match does no damage
--   rerollAtOrBelow   a die roll at or below this is rerolled once
--   lifesteal         HP healed each time a throw deals damage
--   slash             can arm Cleaver Slash once per match: an unavoidable one-hit knockout
--   coinsLocked       cannot be bought with coins (Robux or admin grant only)
--
-- To sell a character for Robux: create a Developer Product for it on the Creator Dashboard
-- (Monetization > Developer Products), then paste its ID into robuxProductId. 0 = not set up yet.
local Characters = {}

Characters.Default = "ClassicChef"

Characters.List = {
	{
		id = "ClassicChef",
		name = "Classic Chef",
		price = 0,
		robuxPrice = 0,
		robuxProductId = 0,
		abilityName = "No special ability",
		desc = "Everyone starts here.",
		color = Color3.fromRGB(235, 235, 235),
	},
	{
		id = "PepperoniPete",
		name = "Pepperoni Pete",
		price = 500,
		robuxPrice = 49,
		robuxProductId = 0,
		abilityName = "Spicy Crit",
		desc = "25% chance for a throw to deal double damage.",
		color = Color3.fromRGB(200, 50, 50),
		critChance = 0.25,
	},
	{
		id = "MamaMia",
		name = "Mama Mia",
		price = 600,
		robuxPrice = 59,
		robuxProductId = 0,
		abilityName = "Mama's Blessing",
		desc = "Heals 5 HP at the start of each of your turns.",
		color = Color3.fromRGB(240, 150, 190),
		healPerTurn = 5,
	},
	{
		id = "SirCrust",
		name = "Sir Crust",
		price = 700,
		robuxPrice = 69,
		robuxProductId = 0,
		abilityName = "Crusty Armour",
		desc = "Take 3 less damage from every hit.",
		color = Color3.fromRGB(190, 140, 80),
		armourBonus = 3,
	},
	{
		id = "CheeseWizard",
		name = "Cheese Wizard",
		price = 800,
		robuxPrice = 79,
		robuxProductId = 0,
		abilityName = "Melted Barrier",
		desc = "The first hit you take each match does no damage.",
		color = Color3.fromRGB(250, 210, 70),
		firstHitBlocked = true,
	},
	{
		id = "LuckyLuigi",
		name = "Lucky Luigi",
		price = 900,
		robuxPrice = 89,
		robuxProductId = 0,
		abilityName = "Lucky Roll",
		desc = "A die roll of 5 or less is rerolled once.",
		color = Color3.fromRGB(80, 190, 100),
		rerollAtOrBelow = 5,
	},
	{
		id = "PizzaPirate",
		name = "Pizza Pirate",
		price = 1200,
		robuxPrice = 149,
		robuxProductId = 0,
		abilityName = "Plunder",
		desc = "Heal 3 HP every time your throw deals damage.",
		color = Color3.fromRGB(60, 90, 160),
		lifesteal = 3,
	},
	-- Not sold for coins: Robux (once robuxProductId is set) or granted by an admin in-game.
	{
		id = "HeadChef",
		name = "Head Chef",
		price = 0,
		coinsLocked = true,
		robuxPrice = 999,
		robuxProductId = 0,
		abilityName = "Cleaver Slash",
		desc = "Once per match, slash the air and defeat your opponent in one blow. Robux or admin only.",
		color = Color3.fromRGB(255, 215, 80),
		slash = true,
	},
}

Characters.ById = {}
for _, character in Characters.List do
	Characters.ById[character.id] = character
end

-- The character sold by a Robux developer product, if any.
function Characters.byProduct(productId)
	if productId == 0 then
		return nil
	end
	for _, character in Characters.List do
		if character.robuxProductId == productId then
			return character
		end
	end
	return nil
end

return Characters
