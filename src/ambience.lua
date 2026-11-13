-- Ambience of the primordial caverns, and only there:
-- * jungle sounds, one recording after another, cross-faded, with the frogs
--   and crickets of the swamp near the underground seas;
-- * a light green haze: the distance fades into it instead of the dark grey
--   of Luanti's sky underground, and colours are a little more vivid. The sky
--   and the saturation of each player are saved on the way in and given back
--   on the way out.

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

-- Pale jungle green. The haze only starts at 3/4 of the viewing range, and the
-- background beyond it takes the same colour, or the haze would fade into grey.
local HAZE = {r = 200, g = 227, b = 160}
local SKY = {type = "plain", base_color = HAZE, clouds = false,
	fog = {fog_color = HAZE, fog_start = 0.75}}
local SATURATION = 1.1

local playing = {} -- player name -> {handle, ends}
local hazy = {} -- player name -> {sky, saturation} to give back on the way out

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

-- Whether the haze is the player's sky: another mod may have set its own
-- since (Everness does when the player changes biome).
local function has_haze(player)
	local sky = player:get_sky(true)
	local color = sky.base_color or {}
	return sky.type == "plain" and color.r == HAZE.r and color.g == HAZE.g and color.b == HAZE.b
end

local function haze_on(player, name)
	local saved = hazy[name]
	if not saved then
		local lighting = player:get_lighting() or {}
		hazy[name] = {sky = player:get_sky(true), saturation = lighting.saturation or 1}
		player:set_lighting({saturation = SATURATION})
	elseif has_haze(player) then
		return
	else
		-- the sky of the other mod is the one to give back
		saved.sky = player:get_sky(true)
	end
	player:set_sky(SKY)
end

local function haze_off(player, name)
	local saved = hazy[name]
	if saved then
		hazy[name] = nil
		player:set_sky(saved.sky)
		player:set_lighting({saturation = saved.saturation})
	end
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
		if level then
			haze_on(player, name)
		else
			haze_off(player, name)
		end
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
	local name = player:get_player_name()
	playing[name] = nil
	hazy[name] = nil
end)
