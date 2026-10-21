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
	Wallet: boolean?, -- keep the HUD coin/Marble counters on screen (rewards fly into them)
}

export type Button = {
	Id: string,
	Caption: string,
	Image: string,
	Headshot: boolean?, -- draw the local player's avatar headshot instead of Image (Image is the fallback)
	HideInMatch: boolean,
	Screen: string?,
	Items: { Item }?,
}

local Topbar = {
	-- Width of the gift dropdown rows (pixels, before Roblox's own top bar scaling).
	DropdownWidth = 230,
	-- Above the menu windows (DisplayOrder 20) so the dropdown opens over an open menu; below toasts (30+).
	DisplayOrder = 25,
	-- Containers whose children pop in one after another when a screen opens (Motion.stagger).
	Stagger = { "Days", "Rewards", "Rows" },
	Buttons = {
		-- Profile (decision 104): your own avatar headshot, left of Settings. Hidden in matches like the gift.
		{
			Id = "Profile",
			Caption = "Profile",
			Image = "screens/profile/icon_glassies",
			Headshot = true,
			HideInMatch = true,
			Screen = "ProfileScreen",
		},
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
				{
					Id = "Daily",
					Label = "Daily Rewards",
					Image = "topbar/daily",
					Screen = "DailyRewardsScreen",
					Wallet = true,
				},
				{
					Id = "Playtime",
					Label = "Playtime Rewards",
					Image = "topbar/playtime",
					Screen = "PlaytimeRewardsScreen",
					Wallet = true,
				},
				{ Id = "Codes", Label = "Codes", Image = "topbar/codes", Screen = "CodesScreen", Wallet = true },
				-- Quests (topbar/quests, QuestsScreen) is held back until its design is decided.
			},
		},
	} :: { Button },
}

return Topbar
