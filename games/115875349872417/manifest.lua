return {
	name = "redliner - game",
	original = "redliner/115875349872417 - game",

	-- Universal files that must not load in this place:
	exclude = {
		modules = {},
		patches = {}
	},

	-- Universal VapeTweaker module names to remove after loading:
	remove = {},

	modules = true,
	patches = true
}
