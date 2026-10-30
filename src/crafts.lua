core.register_craft({
	output = "paleocave:limestone_brick 4",
	recipe = {
		{"paleocave:limestone", "paleocave:limestone"},
		{"paleocave:limestone", "paleocave:limestone"},
	},
})

-- The bones found in PaleoTest's fossil blocks make bone blocks.
if core.get_modpath("bones") then
	core.register_craft({
		type = "shapeless",
		output = "paleocave:bone_block",
		recipe = {"bones:bones"},
	})
end
