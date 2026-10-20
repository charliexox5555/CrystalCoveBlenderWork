-- The three lobby leaderboards (decision 101, Proposed). Each board shows one stat; swap a board's stat here and
-- LeaderboardService writes and reads the new one (profiles keep every stat, so nothing is lost).
-- Stats: MatchWins (all-time match wins), RobuxWeek (Robux spent this week, Monday 00:00 UTC reset), RobuxTotal
-- (Robux spent all time). Slots are as players see them from the plaza: Left, Middle, Right.
-- Boards live in workspace.Lobby.GlassClashProps as Leaderboard_<Id> (tools/studio/install_leaderboards_v3.luau).
local Leaderboards = {}

Leaderboards.Boards = {
	{
		Id = "WeeklySpend",
		Slot = "Left",
		Title = "TOP SUPPORTERS",
		Subtitle = "THIS WEEK",
		Stat = "RobuxWeek",
		Format = "Robux",
		Accent = "aqua",
		Empty = "Be this week's first supporter!",
	},
	{
		Id = "Wins",
		Slot = "Middle",
		Title = "TOTAL WINS",
		Subtitle = "ALL TIME",
		Stat = "MatchWins",
		Format = "Number",
		Accent = "amber",
		Empty = "Clash to make the board!",
	},
	{
		Id = "AllTimeSpend",
		Slot = "Right",
		Title = "TOP SUPPORTERS",
		Subtitle = "ALL TIME",
		Stat = "RobuxTotal",
		Format = "Robux",
		Accent = "amethyst",
		Empty = "Be the first supporter!",
	},
}

Leaderboards.Rows = 10
-- Ordered stores: <StoreName>_<Stat>, with the week appended for RobuxWeek (a fresh store every week).
Leaderboards.WeeklyStats = { RobuxWeek = true }

return Leaderboards
