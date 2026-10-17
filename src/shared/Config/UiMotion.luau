--!strict
-- Numbers for menu feel: background blur, camera FOV punch, idle shine, UI sound levels.
return {
	-- While a menu is open: gentle client-side blur and a small FOV pull-in. Both restore exactly on close.
	Blur = { Size = 8, InSeconds = 0.22, OutSeconds = 0.16 },
	Fov = { Delta = -5, InSeconds = 0.3, OutSeconds = 0.22 },
	-- Primary (green/amber) buttons get a slow shine sweep and a tiny breathing pulse.
	Shine = { Every = 3.2, Seconds = 0.7, Width = 0.22, Transparency = 0.55 },
	Pulse = { Scale = 0.025, Seconds = 1.4 },
	-- Per cue volume/pitch (the sounds themselves live in Config/Audio under the Ui* keys).
	Sounds = {
		Click = { Volume = 0.9, Pitch = 1 },
		Hover = { Volume = 0.25, Pitch = 1.7 },
		Open = { Volume = 0.8, Pitch = 1.1 },
		Close = { Volume = 0.7, Pitch = 0.9 },
		Tab = { Volume = 0.85, Pitch = 1.2 },
		Success = { Volume = 0.8, Pitch = 1 },
		Error = { Volume = 0.6, Pitch = 0.8 },
	},
}
