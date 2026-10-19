--!strict
-- Glass Clash buttons in the Roblox top bar (TopbarPlus, src/shared/Vendor/Icon; decision 98).
-- Each button or dropdown item opens one ScreenGui authored in StarterGui (tools/studio/build_topbar_screens.luau
-- makes the placeholders; restyle them in Studio). Image keys point into Config/UIAssets.
-- HideInMatch: the button hides while the player is queued, fighting, watching or on results.

export type Item = {
	Id: string,
	Label: string,
	Image: string,
	Screen: string,
}

export type Button = {
	Id: string,
	Caption: string,
	Image: string,
	HideInMatch: boolean,
	Screen: string?,
	Items: { Item }?,
}

local Topbar = {
	-- Width of the gift dropdown rows (pixels, before Roblox's own top bar scaling).
	DropdownWidth = 230,
	Buttons = {
		{
			Id = "Settings",
			Caption = "Settings",
			Image = "topbar/settings",
			HideInMatch = false,
			Screen = "SettingsScreen",
		},
		{
			Id = "Rewards",
			Caption = "Rewards",
			Image = "topbar/gift",
			HideInMatch = true,
			Items = {
				{ Id = "Daily", Label = "Daily Rewards", Image = "topbar/daily", Screen = "DailyRewardsScreen" },
				{
					Id = "Playtime",
					Label = "Playtime Rewards",
					Image = "topbar/playtime",
					Screen = "PlaytimeRewardsScreen",
				},
				{ Id = "Codes", Label = "Codes", Image = "topbar/codes", Screen = "CodesScreen" },
				-- Quests (topbar/quests, QuestsScreen) is held back until its design is decided.
			},
		},
	} :: { Button },
}

return Topbar
