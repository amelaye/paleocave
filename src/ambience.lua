-- Jungle ambience in the primordial caverns, and only there: one recording
-- after another, cross-faded, with the frogs and crickets of the swamp near
-- the underground seas.

local caves = paleocave.caves

-- sound, length in seconds
local JUNGLE = {
	{"paleocave_jungle.1", 39.99},
	{"paleocave_jungle.2", 58.06},
	{"paleocave_jungle.3", 63.84},
}
local SWAMP = {
	{"paleocave_jungle_swamp", 46.0},
}

local GAIN = 0.35
local FADE = 3     -- seconds of cross-fade between two recordings
local INTERVAL = 1 -- seconds between two checks of where the players are

local playing = {} -- player name -> {handle, ends}

local function fade_out(state)
	-- the sound stops once faded to 0
	core.sound_fade(state.handle, GAIN / FADE, 0)
end

local function start(name, list, now)
	local track = list[math.random(#list)]
	local handle = core.sound_play(track[1], {to_player = name, gain = 0.01})
	core.sound_fade(handle, GAIN / FADE, GAIN)
	return {handle = handle, ends = now + track[2] - FADE}
end

local clock, timer = 0, 0
core.register_globalstep(function(dtime)
	clock = clock + dtime
	timer = timer + dtime
	if timer < INTERVAL then
		return
	end
	timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local pos = player:get_pos()
		local level = pos.y <= caves.TOP and pos.y >= caves.BOTTOM and caves.level_at(pos)
		local state = playing[name]
		if not level then
			if state then
				fade_out(state)
				playing[name] = nil
			end
		elseif not state or clock >= state.ends then
			if state then
				fade_out(state)
			end
			local list = JUNGLE
			if math.abs(pos.y - level.sea) <= 12 and core.find_node_near(pos, 10, "group:water") then
				list = SWAMP
			end
			playing[name] = start(name, list, clock)
		end
	end
end)

core.register_on_leaveplayer(function(player)
	playing[player:get_player_name()] = nil
end)
