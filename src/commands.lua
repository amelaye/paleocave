local S = paleocave.S

core.register_chatcommand("paleocave", {
	description = S("Show the nearest primordial cavern"),
	privs = {teleport = true},
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then
			return false, S("You must be in game to use this command.")
		end
		local pos = paleocave.caves.find_nearest(player:get_pos())
		if not pos then
			return false, S("No primordial cavern found nearby.")
		end
		return true, S("Nearest primordial cavern: @1", core.pos_to_string(pos))
	end,
})
