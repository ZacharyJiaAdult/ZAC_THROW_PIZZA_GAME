return {
	MinPlayers = 2,
	BotEnabled = true, -- a lone player gets a practice bot as the opponent (set false for real PvP only)
	StartingHealth = 100,
	MaxRounds = 5, -- one round = both fighters take a turn; a tie after the last round goes to sudden death
	DieSides = 20, -- damage dealt equals the roll
	TurnSeconds = 15, -- auto-throws if the player does nothing
	RollSeconds = 1.2,
	IntermissionSeconds = 5,
	StartingCoins = 100, -- progress is not saved between sessions yet
	WinCoins = 50,
	LossCoins = 20,
	ResultSeconds = 6, 
}
