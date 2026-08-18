return {
	name = "jailbreak - main",
	original = "jailbreak/606849621 - main",

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
