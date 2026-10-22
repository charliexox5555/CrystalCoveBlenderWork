-- Device fitting numbers for ResponsiveController (decision 106). Pure data.
return {
	CompactShortSide = 500, -- viewports whose short side is below this (px) are phones: bigger windows, smaller headline
	CompactWidth = 0.96, -- phone windows may use this share of the safe area's width...
	CompactHeight = 0.94, -- ...and height (title banner and close diamond included)
	SafeWidth = 0.88, -- TV: windows stay inside this share of the screen (overscan)
	SafeHeight = 0.86,
	EdgeMargin = 0.02, -- gap kept between a window's decorations and the screen edge (share of height)
	CompactHeadline = 0.12, -- phone: PULL BACK / countdown headline height (share of screen; authored 0.2)
	BillboardReferenceHeight = 600, -- player billboards grow on screens shorter than this (px)...
	BillboardMaxScale = 1.8, -- ...up to this factor
	BillboardMinScale = 1.5, -- every screen: at the authored 5 x 2.5 studs the glassy chip and HP line were ~6 px
}
