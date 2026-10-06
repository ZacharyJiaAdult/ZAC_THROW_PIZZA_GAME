local Items = {}

Items.Rarities = { "Common", "Rare", "Epic" }
Items.RarityColors = {
	Common = Color3.fromRGB(210, 210, 210),
	Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(200, 100, 255),
}

-- Ability tuning
Items.HealAmount = 15 -- Healing Slice
Items.CheeseBonus = 5 -- Extra Cheese
Items.LuckyMin = 10 -- Lucky Pepperoni: the die never rolls below this
Items.DuplicateRefund = 25 -- coins back for pulling armour you already own

-- kind = "armour": equip one piece, it cuts every hit you take by `reduction` (a hit always does at least 1).
-- kind = "ability": consumed when used; arm one on your turn before throwing.
Items.List = {
	CardboardVest = { name = "Cardboard Vest", kind = "armour", rarity = "Common", reduction = 1, desc = "-1 damage taken" },
	OvenMitts = { name = "Oven Mitts", kind = "armour", rarity = "Rare", reduction = 2, desc = "-2 damage taken" },
	PizzaPanShield = { name = "Pizza Pan Shield", kind = "armour", rarity = "Rare", reduction = 3, desc = "-3 damage taken" },
	ChefPlate = { name = "Chef's Plate Mail", kind = "armour", rarity = "Epic", reduction = 5, desc = "-5 damage taken" },

	ExtraCheese = { name = "Extra Cheese", kind = "ability", rarity = "Common", desc = "+5 damage on this throw" },
	LuckyPepperoni = { name = "Lucky Pepperoni", kind = "ability", rarity = "Common", desc = "The die can't roll below 10" },
	DoubleDice = { name = "Double Dice", kind = "ability", rarity = "Rare", desc = "Roll two d20 and keep the higher" },
	HealingSlice = { name = "Healing Slice", kind = "ability", rarity = "Epic", desc = "Heal 15 HP, then throw" },
}

-- weights are relative odds of each rarity
Items.Crates = {
	{
		id = "Bronze",
		name = "Bronze Crate",
		price = 50,
		blurb = "Mostly common loot",
		color = Color3.fromRGB(205, 127, 50),
		weights = { Common = 80, Rare = 18, Epic = 2 },
	},
	{
		id = "Silver",
		name = "Silver Crate",
		price = 120,
		blurb = "Good odds at rare gear",
		color = Color3.fromRGB(200, 205, 215),
		weights = { Common = 40, Rare = 50, Epic = 10 },
	},
	{
		id = "Gold",
		name = "Gold Crate",
		price = 250,
		blurb = "Best shot at epics",
		color = Color3.fromRGB(255, 205, 60),
		weights = { Common = 10, Rare = 50, Epic = 40 },
	},
}

function Items.getCrate(id)
	for _, crate in Items.Crates do
		if crate.id == id then
			return crate
		end
	end
	return nil
end

function Items.armourReduction(id)
	local item = id and Items.List[id]
	return item and item.reduction or 0
end

return Items
