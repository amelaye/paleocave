local modpath = core.get_modpath("paleocave")

paleocave = {
	S = core.get_translator("paleocave"),
}

dofile(modpath .. "/src/caves.lua")
dofile(modpath .. "/src/nodes.lua")
dofile(modpath .. "/src/crafts.lua")
dofile(modpath .. "/src/spawning.lua")
dofile(modpath .. "/src/structures.lua")
dofile(modpath .. "/src/mapgen.lua")
