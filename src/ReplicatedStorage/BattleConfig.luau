return {
	ArenaCount = 3, -- arenas that can run matches at the same time
	BotEnabled = true, -- adds the "Fight Bot" kiosk to the Waiting Area (false = real PvP only)
	-- Bot difficulty, picked at the kiosk. hp/armour are the bot's; rollMode "advantage" rolls two dice and
	-- keeps the higher, "disadvantage" keeps the lower. coinMult scales the coins you win by beating it.
	BotLevels = {
		{ id = "Easy", name = "Easy", hp = 80, armour = 0, rollMode = "disadvantage", coinMult = 0.5, dodgeChance = 0.1, aimError = 14, color = Color3.fromRGB(90, 190, 90), desc = "80 HP, rolls twice and keeps the lower" },
		{ id = "Medium", name = "Medium", hp = 100, armour = 1, rollMode = "normal", coinMult = 1, dodgeChance = 0.2, aimError = 8, color = Color3.fromRGB(240, 170, 50), desc = "100 HP, 1 armour, plain d20" },
		{ id = "Hard", name = "Hard", hp = 120, armour = 3, rollMode = "advantage", coinMult = 2, dodgeChance = 0.3, aimError = 3, color = Color3.fromRGB(220, 70, 60), desc = "120 HP, 3 armour, rolls twice and keeps the higher" },
	},
	StartingHealth = 100,
	MaxRounds = 5, -- one round = both fighters take a turn; a tie after the last round goes to sudden death
	DieSides = 20, -- damage dealt equals the roll
	TurnSeconds = 15, -- auto-throws if the player does nothing
	RollSeconds = 1.2,
	DodgesPerMatch = 2, -- each fighter can dodge this many throws per match (a dodge means zero damage)
	DodgeSeconds = 1.5, -- how long the defender has to press DODGE once a throw is on its way
	-- Free For All (real time, not turn based): players move freely and throw pizzas on a cooldown
	FFAMinPlayers = 3, -- fighters needed to start (players plus bots)
	FFAMaxPlayers = 8,
	FFAMaxBots = 4, -- the kiosk cycles 0..this many bots
	FFABotLevel = "Medium",
	FFACountdown = 10, -- seconds in the waiting area before the match starts
	FFAMatchSeconds = 150, -- when time runs out the highest HP wins
	FFAThrowCooldown = 1.1,
	FFADodgeCooldown = 3, -- the roll makes you take zero damage for FFADodgeSeconds
	FFADodgeSeconds = 0.6,
	FFAProjectileSpeed = 70, -- studs per second
	FFAProjectileRange = 90,
	FFAFreezeSeconds = 3, -- Time Freeze duration in the Free For All
	FFAWinCoins = 100,
	FFALossCoins = 20,
	FFAKillCoins = 15,
	MeteorDamage = 40, -- Sauce Sorcerer: Meteor Pie damage (cannot be dodged or blocked)
	IntermissionSeconds = 5,
	StartingCoins = 100, -- what a new player begins with (progress is saved to a DataStore on a published place)
	WinCoins = 50,
	LossCoins = 20,
	ResultSeconds = 6, 
}
