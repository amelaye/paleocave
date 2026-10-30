-- Structures of the primordial caverns, built while a level is generated
-- (see mapgen.lua), entirely inside the mapchunk:
-- * ruins of primordial houses, after the caveman houses of Alex's Caves:
--   limestone walls broken down unevenly, sometimes an upper story of
--   metasequoia timber, cave paintings and amber lamps inside, a pile of
--   bones, plants growing through the floor and a chest left upstairs;
-- * dinosaur skeletons of bone blocks lying half buried on the floors, and
--   skeletons of marine reptiles on the sea floors.
-- Slabs, stairs and smaller shapes (moreblocks, else the stairs mod) give the
-- broken walls, the rubble and the bones their irregular outline.

local structures = {}
paleocave.structures = structures

local ruins = core.settings:get_bool("paleocave_ruins", true)
local skeletons = core.settings:get_bool("paleocave_skeletons", true)
structures.enabled = ruins or skeletons

local RUIN_CHANCE = 75 -- percent of the level mapchunks trying to host ruins
local SITE_RADIUS = 12 -- levelled ground holding the houses
local SKELETON_CHANCE = 60 -- percent of the level mapchunks trying to hold a dinosaur skeleton
local SEA_SKELETON_CHANCE = 45 -- and the skeleton of a marine reptile
local TAU = 2 * math.pi

local c = {} -- content ids
local m = {} -- materials: content ids of a block and of its shapes
local initialized

local function id(name)
	return name and core.registered_nodes[name] and core.get_content_id(name)
end

-- Content ids of a block and of its shapes. Missing ones are taken from
-- `base`, then from close shapes.
local function material(names, base)
	local mat = {}
	for kind, name in pairs(names or {}) do
		mat[kind] = id(name)
	end
	for kind, cid in pairs(base or {}) do
		mat[kind] = mat[kind] or cid
	end
	mat.slab_three_quarter = mat.slab_three_quarter or mat.slab
	return mat
end

local function init()
	initialized = true
	local shapes = paleocave.shapes
	c.air = core.get_content_id("air")
	c.dirt = id("default:dirt")
	c.gravel = id("default:gravel") or c.dirt
	c.water = id("default:water_source")
	c.amber = id("paleocave:amber")
	c.fossil = id("paleotest:fossil_block")
	c.skull = id("bones:bones")
	c.chest = id("default:chest")
	c.paintings = {}
	for _, name in ipairs(paleocave.paintings) do
		c.paintings[#c.paintings + 1] = id("paleocave:cave_painting_" .. name)
	end
	c.plants = {}
	for _, entry in ipairs({{"default:fern_1", 0}, {"default:fern_2", 0}, {"default:junglegrass", 0},
			{"paleotest:horsetail_3", 2}, {"paleotest:cycad_3", 2}, {"paleocave:tree_star", 0}}) do
		local cid = id(entry[1])
		if cid then
			c.plants[#c.plants + 1] = {cid = cid, param2 = entry[2]}
		end
	end
	m.brick = material(shapes.limestone_brick)
	m.limestone = material(shapes.limestone)
	m.bone = material(shapes.bone_block)
	m.planks = material({
		full = "paleotest:metasequoia_wood",
		slab = "stairs:slab_metasequoia_wood",
		stair = "stairs:stair_metasequoia_wood",
	}, material({full = "default:wood"}))
	m.log = material(shapes.metasequoia_tree or {full = "paleotest:metasequoia_tree"}, m.planks)
	if not (c.dirt and m.planks.full and m.log.full) then
		ruins = false
		core.log("warning", "[paleocave] blocks missing: no primordial ruins")
	end
end

local function index(ctx, x, z)
	return (z - ctx.minp.z) * ctx.side + (x - ctx.minp.x) + 1
end

local function rand(rng, a, b)
	return a + (b - a) * rng:next(0, 1000) / 1000
end

-- b, the builder: {ctx, rng, y0 = ground level of the site, houses = their
-- rectangles}

-- Writes a node, only inside the mapchunk.
local function put(b, x, y, z, cid, p2)
	local ctx = b.ctx
	if cid and y >= ctx.minp.y and y <= ctx.maxp.y and x >= ctx.minp.x and x <= ctx.maxp.x
			and z >= ctx.minp.z and z <= ctx.maxp.z then
		local vi = ctx.area:index(x, y, z)
		ctx.data[vi], ctx.param2[vi] = cid, p2 or 0
	end
end

local function get(b, x, y, z)
	return b.ctx.data[b.ctx.area:index(x, y, z)]
end

-- facedir turning a stair so that it rises towards (dx, dz)
local function towards(dx, dz)
	if math.abs(dx) > math.abs(dz) then
		return dx > 0 and 1 or 3
	end
	return dz > 0 and 0 or 2
end

-- facedir turning the front of a node (chest, skull) towards (dx, dz)
local function facing(dx, dz)
	return (towards(dx, dz) + 2) % 4
end

-- wallmounted param2 of a painting hung on the wall at (dx, dz)
local function wallmounted(dx, dz)
	if dx ~= 0 then
		return dx > 0 and 2 or 3
	end
	return dz > 0 and 4 or 5
end

-- main axis of a direction, as a unit vector
local function axis(dx, dz)
	if math.abs(dx) > math.abs(dz) then
		return dx > 0 and 1 or -1, 0
	end
	return 0, dz > 0 and 1 or -1
end

-- Node topping a broken wall: `fill` is the part of the top cell still
-- standing, `slope` how the wall rises along (wx, wz). Slabs where the wall is
-- level, stairs climbing towards its higher part.
local function cap(mat, fill, slope, wx, wz)
	if fill < 0.2 then
		return nil
	end
	if fill >= 0.85 or not mat.slab then
		return fill >= 0.5 and mat.full or nil, 0
	end
	if fill >= 0.4 and math.abs(slope) > 0.3 and mat.stair then
		return mat.stair, towards(wx * slope, wz * slope)
	end
	if fill < 0.4 then
		return mat.slab_quarter, 0
	end
	return fill < 0.7 and mat.slab or mat.slab_three_quarter, 0
end

-- A small loose piece (microblock, panel or quarter slab) turned at random,
-- nil without moreblocks.
local function piece(mat, rng)
	local roll = rng:next(1, 3)
	return roll == 1 and mat.micro or roll == 2 and mat.panel or mat.slab_quarter, rng:next(0, 3)
end

-- A fallen piece of wall lying on the ground.
local function rubble(b, x, z)
	local rng, y0 = b.rng, b.y0
	if get(b, x, y0 + 1, z) ~= c.air then
		return
	end
	local mat = rng:next(1, 4) == 1 and m.limestone or m.brick
	local roll, cid, p2 = rng:next(1, 100), nil, 0
	if roll <= 30 then
		cid = mat.slab
	elseif roll <= 50 then
		-- some lie upside down
		cid, p2 = mat.stair, rng:next(0, 3) + (rng:next(1, 4) == 1 and 20 or 0)
	elseif roll <= 80 then
		cid, p2 = piece(mat, rng)
	else
		cid = mat.full
	end
	put(b, x, y0 + 1, z, cid, p2)
end

-- Raises or lowers the floor of a column to y, topped with `top`: filled with
-- `below` (dirt) or emptied to `above` (air).
local function level(ctx, x, z, y, top, below, above)
	local i = index(ctx, x, z)
	local f, area, data = ctx.floors[i], ctx.area, ctx.data
	for yy = math.min(f, y + 1), math.max(f, y - 1) do
		data[area:index(x, yy, z)] = yy < y and (below or c.dirt) or (above or c.air)
	end
	local vi = area:index(x, y, z)
	data[vi], ctx.param2[vi] = top, 0
	ctx.floors[i] = y
end

-- Ground level for a site of radius r around (x0, z0), or nil: dry floors
-- within `tolerance` of it, `height` free nodes above it, all inside the
-- mapchunk.
local function site(ctx, x0, z0, r, tolerance, height)
	local floors, ceilings, reserved = ctx.floors, ctx.ceilings, ctx.reserved
	local r2, sum, n = r * r, 0, 0
	for dz = -r, r do
		for dx = -r, r do
			if dx * dx + dz * dz <= r2 then
				local i = index(ctx, x0 + dx, z0 + dz)
				local f = floors[i]
				if not f or f <= ctx.sea or reserved[i] then
					return nil
				end
				sum, n = sum + f, n + 1
			end
		end
	end
	local y0 = math.floor(sum / n + 0.5)
	if y0 - tolerance <= ctx.minp.y or y0 + height > ctx.maxp.y then
		return nil
	end
	local data, area = ctx.data, ctx.area
	for dz = -r, r do
		for dx = -r, r do
			if dx * dx + dz * dz <= r2 then
				local x, z = x0 + dx, z0 + dz
				local i = index(ctx, x, z)
				local f = floors[i]
				if math.abs(f - y0) > tolerance or ceilings[i] < y0 + height then
					return nil
				end
				for y = f + 1, y0 + height - 1 do
					if data[area:index(x, y, z)] ~= c.air then
						return nil
					end
				end
			end
		end
	end
	return y0
end

-- Whether the columns of a rectangle have air up to y (inclusive) and a
-- ceiling above it.
local function open_above(ctx, x0, z0, x1, z1, y0, y)
	if y > ctx.maxp.y then
		return false
	end
	for z = z0, z1 do
		for x = x0, x1 do
			if ctx.ceilings[index(ctx, x, z)] <= y then
				return false
			end
			for yy = y0 + 1, y do
				if ctx.data[ctx.area:index(x, yy, z)] ~= c.air then
					return false
				end
			end
		end
	end
	return true
end

-- Houses --

local function is_corner(h, x, z)
	return (x == h.x0 or x == h.x1) and (z == h.z0 or z == h.z1)
end

-- Block of a wall course: bricks with some rough limestone, a fossil block or
-- bones laid in now and then; log posts at the corners, a log band under the
-- upper floor, timber upstairs.
local function wall_block(h, y, post, along, rng)
	if post then
		return m.log.full, 0
	elseif h.timber and y > 5 then
		return m.planks.full, 0
	elseif h.stories == 2 and y == 5 then
		return m.log.full, along
	end
	local roll = rng:next(1, 100)
	if roll <= 3 and c.fossil then
		return c.fossil, 0
	elseif roll <= 6 then
		return m.bone.full, along
	elseif roll <= 20 then
		return m.limestone.full, 0
	end
	return m.brick.full, 0
end

local function course_material(h, y, post)
	if post then
		return m.log
	elseif h.timber and y > 5 then
		return m.planks
	elseif h.stories == 2 and y == 5 then
		return m.log
	end
	return m.brick
end

-- The walls, walked around the house: {x, z, walking direction (wx, wz),
-- inward normal (nx, nz)}.
local function wall_ring(h)
	local ring = {}
	for x = h.x0, h.x1 - 1 do
		ring[#ring + 1] = {x, h.z0, 1, 0, 0, 1}
	end
	for z = h.z0, h.z1 - 1 do
		ring[#ring + 1] = {h.x1, z, 0, 1, -1, 0}
	end
	for x = h.x1, h.x0 + 1, -1 do
		ring[#ring + 1] = {x, h.z1, -1, 0, 0, -1}
	end
	for z = h.z1, h.z0 + 1, -1 do
		ring[#ring + 1] = {h.x0, z, 0, -1, 1, 0}
	end
	return ring
end

-- Height left of each wall column: the walls stand lower where breaches
-- opened, the corners hold best.
local function wall_heights(h, ring, rng)
	local top, n = h.top, #ring
	local decay = h.stories == 2 and rand(rng, 0.75, 1) or rand(rng, 0.55, 1)
	local breaches = {}
	for k = 1, rng:next(1, 3) do
		breaches[k] = {t = rng:next(1, n), half = rand(rng, 1, 3), depth = rand(rng, 0.4, 1)}
	end
	local phase, waves = rand(rng, 0, TAU), rng:next(1, 3)
	local heights = {}
	for t, cell in ipairs(ring) do
		local height = (top + 0.7) * decay + 0.6 * math.sin(phase + TAU * waves * t / n)
			+ rand(rng, -0.4, 0.4)
		for _, breach in ipairs(breaches) do
			local dist = math.min(math.abs(t - breach.t), n - math.abs(t - breach.t))
			local k = 1 - (dist / (breach.half + 1)) ^ 2
			if k > 0 then
				height = height - breach.depth * (top + 1) * k
			end
		end
		if is_corner(h, cell[1], cell[2]) then
			height = height + 1.5
		end
		heights[t] = math.max(0, math.min(height, top + 0.9))
	end
	return heights
end

-- Some interior cell against a wall, at height y above the ground: x, z, and
-- the direction of the wall (dx, dz). Not a corner, not a kept-clear column.
local function against_wall(b, h, ring, y, rng)
	for _ = 1, 12 do
		local cell = ring[rng:next(1, #ring)]
		local x, z = cell[1] + cell[5], cell[2] + cell[6]
		if not is_corner(h, cell[1], cell[2]) and x > h.x0 and x < h.x1 and z > h.z0 and z < h.z1
				and not h.keep[index(b.ctx, x, z)] and get(b, x, b.y0 + y, z) == c.air then
			return x, z, -cell[5], -cell[6]
		end
	end
end

-- Whether a wall node can hold a painting or be replaced by an amber lamp.
local function plain_wall(cid)
	return cid == m.brick.full or cid == m.limestone.full or cid == m.planks.full
end

local function build_house(b, h)
	local rng, y0, ctx = b.rng, b.y0, b.ctx
	h.keep = {}
	local ring = wall_ring(h)
	local heights = wall_heights(h, ring, rng)

	-- floor of worn paving, the inside cleared
	for z = h.z0 + 1, h.z1 - 1 do
		for x = h.x0 + 1, h.x1 - 1 do
			local roll = rng:next(1, 100)
			put(b, x, y0, z, roll <= 45 and m.limestone.full or roll <= 70 and m.brick.full
				or roll <= 82 and c.gravel or c.dirt)
			for y = 1, h.top + 1 do
				put(b, x, y0 + y, z, c.air)
			end
		end
	end

	-- broken walls
	for t, cell in ipairs(ring) do
		local x, z, wx, wz = cell[1], cell[2], cell[3], cell[4]
		local post = h.posts and is_corner(h, x, z)
		local along = wx ~= 0 and 12 or 4
		local height = heights[t]
		local full = math.floor(height)
		for y = 1, full do
			put(b, x, y0 + y, z, wall_block(h, y, post, along, rng))
		end
		local mat = course_material(h, full + 1, post)
		local slope = (heights[t % #ring + 1] - heights[(t - 2) % #ring + 1]) / 2
		local cid, p2 = cap(mat, height - full, slope, wx, wz)
		if cid and rng:next(1, 100) <= 15 then
			cid, p2 = piece(mat, rng) -- crumbled
		end
		put(b, x, y0 + full + 1, z, cid, p2)
	end

	-- doorway facing the middle of the site, windows here and there
	local door_side = {}
	for t, cell in ipairs(ring) do
		if cell[5] == -h.ddx and cell[6] == -h.ddz and not is_corner(h, cell[1], cell[2]) then
			door_side[#door_side + 1] = t
		end
	end
	local first = math.max(1, math.floor(#door_side / 2) + rng:next(-1, 0))
	local width = #door_side >= 7 and rng:next(1, 3) == 1 and 2 or 1
	local is_door = {}
	for k = first, math.min(first + width - 1, #door_side) do
		local t = door_side[k]
		local cell = ring[t]
		is_door[t] = true
		for y = 1, 3 do
			put(b, cell[1], y0 + y, cell[2], c.air)
		end
		if heights[t] >= 4 then
			put(b, cell[1], y0 + 4, cell[2], m.log.full, cell[3] ~= 0 and 12 or 4) -- lintel
		end
		h.keep[index(ctx, cell[1] + cell[5], cell[2] + cell[6])] = true
	end
	for t, cell in ipairs(ring) do
		if t % 3 == 0 and not is_door[t] and not is_door[t - 1] and not is_door[t + 1]
				and not is_corner(h, cell[1], cell[2]) and rng:next(1, 100) <= 60 then
			local prev, nxt = heights[(t - 2) % #ring + 1], heights[t % #ring + 1]
			for _, window in ipairs({{2, 3, 4}, {7, 8, 9}}) do
				-- the wall must go on above the window and on both sides
				if math.min(heights[t], prev, nxt) >= window[3] then
					put(b, cell[1], y0 + window[1], cell[2], c.air)
					put(b, cell[1], y0 + window[2], cell[2], c.air)
				end
			end
		end
	end

	local floor_y = 0 -- floor of the room holding the chest
	if h.stories == 2 then
		-- staircase along the back wall, up to the landing
		local ux, uz = h.ddz, h.ddx
		if rng:next(1, 2) == 1 then
			ux, uz = -ux, -uz
		end
		local sx, sz
		if h.ddz ~= 0 then
			sz = h.ddz < 0 and h.z1 - 1 or h.z0 + 1
			sx = ux > 0 and h.x0 + 1 or h.x1 - 1
		else
			sx = h.ddx < 0 and h.x1 - 1 or h.x0 + 1
			sz = uz > 0 and h.z0 + 1 or h.z1 - 1
		end
		local stairwell = {}
		for k = 0, 4 do
			local x, z = sx + ux * k, sz + uz * k
			h.keep[index(ctx, x, z)] = true
			if k < 4 then
				stairwell[index(ctx, x, z)] = true
				for y = 1, k do
					put(b, x, y0 + y, z, m.brick.full)
				end
				put(b, x, y0 + k + 1, z, m.brick.stair or m.brick.full, towards(ux, uz))
			end
		end
		h.keep[index(ctx, sx - ux, sz - uz)] = true

		-- upper floor of planks on log beams, fallen in here and there
		local along_x = h.x1 - h.x0 <= h.z1 - h.z0
		local holes = {}
		for z = h.z0 + 1, h.z1 - 1 do
			for x = h.x0 + 1, h.x1 - 1 do
				local i = index(ctx, x, z)
				local coarse = math.floor((x - h.x0) / 2) * 16 + math.floor((z - h.z0) / 2)
				if holes[coarse] == nil then
					holes[coarse] = rng:next(1, 100) <= 22
				end
				local beam = along_x and (z - h.z0) % 3 == 2 or not along_x and (x - h.x0) % 3 == 2
				local landing = x == sx + ux * 4 and z == sz + uz * 4
				if stairwell[i] then
					put(b, x, y0 + 5, z, c.air)
				elseif beam then
					put(b, x, y0 + 5, z, m.log.full, along_x and 12 or 4)
				elseif landing or not holes[coarse] then
					if rng:next(1, 100) <= 20 and not landing then
						put(b, x, y0 + 5, z, m.planks.slab or m.planks.full) -- sagging boards
					else
						put(b, x, y0 + 5, z, m.planks.full)
					end
				else
					put(b, x, y0 + 5, z, c.air)
				end
			end
		end
		floor_y = 5
	end

	-- inside: paintings, amber lamps, a pile of bones, plants, the chest
	for _, y in ipairs(h.stories == 2 and {2, 7} or {2}) do
		for _ = 1, rng:next(1, 3) do
			local x, z, dx, dz = against_wall(b, h, ring, y, rng)
			if x and #c.paintings > 0 and plain_wall(get(b, x + dx, y0 + y, z + dz)) then
				put(b, x, y0 + y, z, c.paintings[rng:next(1, #c.paintings)], wallmounted(dx, dz))
			end
		end
		local x, z, dx, dz = against_wall(b, h, ring, y + 1, rng)
		if x and plain_wall(get(b, x + dx, y0 + y + 1, z + dz)) then
			put(b, x + dx, y0 + y + 1, z + dz, c.amber)
		end
	end
	local x, z = against_wall(b, h, ring, 1, rng)
	if x then
		put(b, x, y0 + 1, z, m.bone.full, ({0, 4, 12})[rng:next(1, 3)])
		if c.skull and rng:next(1, 100) <= 50 then
			put(b, x, y0 + 2, z, c.skull, rng:next(0, 3))
		end
		for _ = 1, rng:next(2, 4) do
			local px, pz = x + rng:next(-1, 1), z + rng:next(-1, 1)
			if px > h.x0 and px < h.x1 and pz > h.z0 and pz < h.z1 and not h.keep[index(ctx, px, pz)]
					and get(b, px, y0 + 1, pz) == c.air then
				local cid, p2 = piece(m.bone, rng)
				put(b, px, y0 + 1, pz, cid or m.bone.slab, p2)
			end
		end
	end
	for _ = 1, #c.plants > 0 and rng:next(0, 3) or 0 do
		local px, pz = rng:next(h.x0 + 1, h.x1 - 1), rng:next(h.z0 + 1, h.z1 - 1)
		if not h.keep[index(ctx, px, pz)] and get(b, px, y0 + 1, pz) == c.air then
			local plant = c.plants[rng:next(1, #c.plants)]
			put(b, px, y0, pz, c.dirt)
			put(b, px, y0 + 1, pz, plant.cid, plant.param2)
		end
	end
	if c.chest and (h.stories == 2 or rng:next(1, 2) == 1) then
		for _ = 1, 4 do
			local cx, cz, dx, dz = against_wall(b, h, ring, floor_y + 1, rng)
			if cx and (floor_y == 0 or get(b, cx, y0 + floor_y, cz) == m.planks.full) then
				put(b, cx, y0 + floor_y + 1, cz, c.chest, facing(-dx, -dz))
				ctx.chests[#ctx.chests + 1] = {x = cx, y = y0 + floor_y + 1, z = cz}
				break
			end
		end
	end

	-- fallen stones around the breaches, a fallen beam now and then
	for t, cell in ipairs(ring) do
		local missing = h.top - heights[t]
		if missing > 1 and not is_door[t] then
			for _ = 1, math.floor(missing / 2 + rand(rng, 0, 1)) do
				local s = rng:next(1, 3) == 1 and 1 or -1 -- mostly outside
				local dist, shift = rng:next(1, 3), rng:next(-1, 1)
				local rx = cell[1] + cell[5] * s * dist + cell[3] * shift
				local rz = cell[2] + cell[6] * s * dist + cell[4] * shift
				local inside = rx > h.x0 and rx < h.x1 and rz > h.z0 and rz < h.z1
				local i = index(ctx, rx, rz)
				if (inside and not h.keep[i]) or (not inside and b.ground[i]
						and not structures.near({footprints = b.houses}, rx, rz, 0)) then
					rubble(b, rx, rz)
				end
			end
		end
	end
	if h.stories == 2 and rng:next(1, 2) == 1 then
		local cell = ring[rng:next(1, #ring)]
		local ax, az = cell[3], cell[4]
		for k = 0, rng:next(1, 2) do
			local rx = cell[1] - cell[5] * 2 + ax * k
			local rz = cell[2] - cell[6] * 2 + az * k
			if b.ground[index(ctx, rx, rz)] and get(b, rx, y0 + 1, rz) == c.air
					and not structures.near({footprints = b.houses}, rx, rz, 0) then
				put(b, rx, y0 + 1, rz, m.log.full, ax ~= 0 and 12 or 4)
			end
		end
	end
end

-- Sites --

-- a few columns around a candidate centre, checked before the whole ground
local PROBES = {{0, 0}, {14, 0}, {-14, 0}, {0, 14}, {0, -14}, {10, 10}, {10, -10},
	{-10, 10}, {-10, -10}, {7, 0}, {-7, 0}, {0, 7}, {0, -7}}

local function build_site(ctx, cx, cz, y0)
	local rng = ctx.rng
	local b = {ctx = ctx, rng = rng, y0 = y0, houses = {}, ground = {}}
	-- levelled ground, still overgrown, with gravel and old paving here and there
	local outer = SITE_RADIUS + 2
	for dz = -outer, outer do
		for dx = -outer, outer do
			local d = math.sqrt(dx * dx + dz * dz)
			if d <= outer then
				local x, z = cx + dx, cz + dz
				local f = ctx.floors[index(ctx, x, z)]
				local top = ctx.data[ctx.area:index(x, f, z)]
				if d > SITE_RADIUS then
					level(ctx, x, z, math.floor(y0 + (f - y0) * (d - SITE_RADIUS) / 2 + 0.5), top)
				else
					local roll = rng:next(1, 100)
					level(ctx, x, z, y0, roll <= 12 and c.gravel or roll <= 20 and c.dirt
						or roll <= 26 and m.limestone.full or top)
					b.ground[index(ctx, x, z)] = true
				end
			end
		end
	end

	-- one large house, or two or three smaller ones
	local count = rng:next(1, 3)
	local largest = count == 1 and 11 or 8
	for _ = 1, count do
		for _ = 1, 30 do
			local w, d = rng:next(7, largest), rng:next(7, largest)
			local x0 = cx + rng:next(-SITE_RADIUS + 1, SITE_RADIUS - w)
			local z0 = cz + rng:next(-SITE_RADIUS + 1, SITE_RADIUS - d)
			local x1, z1 = x0 + w - 1, z0 + d - 1
			local fits = true
			for _, corner in ipairs({{x0, z0}, {x1, z0}, {x0, z1}, {x1, z1}}) do
				fits = fits and (corner[1] - cx) ^ 2 + (corner[2] - cz) ^ 2 <= (SITE_RADIUS - 0.5) ^ 2
			end
			for _, house in ipairs(b.houses) do
				fits = fits and (x0 > house[3] + 2 or x1 < house[1] - 2 or z0 > house[4] + 2
					or z1 < house[2] - 2)
			end
			if fits then
				local ddx, ddz = axis(cx - (x0 + x1) / 2, cz - (z0 + z1) / 2)
				local stories = rng:next(1, 100) <= 70 and open_above(ctx, x0, z0, x1, z1, y0, y0 + 10)
					and 2 or 1
				local h = {x0 = x0, z0 = z0, x1 = x1, z1 = z1, ddx = ddx, ddz = ddz,
					stories = stories, top = stories == 2 and 9 or 4,
					timber = stories == 2 and rng:next(1, 3) == 1, posts = rng:next(1, 2) == 1}
				b.houses[#b.houses + 1] = {x0, z0, x1, z1}
				ctx.footprints[#ctx.footprints + 1] = {x0, z0, x1, z1}
				for z = z0 - 1, z1 + 1 do
					for x = x0 - 1, x1 + 1 do
						ctx.reserved[index(ctx, x, z)] = true
					end
				end
				build_house(b, h)
				break
			end
		end
	end
end

local function try_site(ctx)
	local rng, margin = ctx.rng, SITE_RADIUS + 3
	for _ = 1, 32 do
		local x = rng:next(ctx.minp.x + margin, ctx.maxp.x - margin)
		local z = rng:next(ctx.minp.z + margin, ctx.maxp.z - margin)
		local f = ctx.floors[index(ctx, x, z)]
		local promising = f and f > ctx.sea + 1
		for k = 2, #PROBES do
			local pf = promising and ctx.floors[index(ctx, x + PROBES[k][1], z + PROBES[k][2])]
			if not pf or pf <= ctx.sea or math.abs(pf - f) > 4 then
				promising = false
				break
			end
		end
		local y0 = promising and site(ctx, x, z, SITE_RADIUS + 2, 3, 7)
		if y0 then
			build_site(ctx, x, z, y0)
			return
		end
	end
end

-- Skeletons --

-- Lengths of the tail, ribcage and neck (ranges) and of the skull, in nodes;
-- height of the spine over the ribcage, half-width of the ribs, length of
-- the limbs.
local SKELETONS = {
	land = {
		{tail = {7, 8}, body = {6, 7}, neck = {3, 4}, skull = 3, height = 3, ribs = 3, limbs = 3},
		{tail = {5, 6}, body = {4, 5}, neck = {2, 3}, skull = 2, height = 2, ribs = 2, limbs = 2},
	},
	sea = {
		-- mosasaur: long tail and jaws
		{tail = {8, 9}, body = {5, 6}, neck = {1, 2}, skull = 4, height = 2, ribs = 2, limbs = 2},
		-- plesiosaur: long neck, small head, long flippers
		{tail = {3, 4}, body = {5, 5}, neck = {7, 8}, skull = 2, height = 2, ribs = 2, limbs = 3},
	},
}

-- Skeleton lying along (ax, az) from its hips at (ox, oz), half buried: a
-- spine curving down to the tail and to the skull, ribs arching over the
-- ground, limbs splayed out. Under water, full blocks only: shapes would
-- hold air.
local function build_skeleton(b, ox, oz, ax, az, k)
	local rng, y0, bone = b.rng, b.y0, m.bone
	local px, pz = az, ax
	local along, across = ax ~= 0 and 12 or 4, ax ~= 0 and 4 or 12
	local sink = rng:next(1, 100) <= 40 and 1 or 0 -- buried deeper
	local function set(t, s, y, cid, p2)
		if k.marine and cid then
			cid = bone.full
		end
		put(b, ox + ax * t + px * s, y0 + y - sink, oz + az * t + pz * s, cid, p2)
	end

	-- spine, stairs smoothing its steps
	local front, hb = k.body + k.neck, k.height
	local heights = {}
	for t = -k.tail, front do
		local h = hb
		if t < 0 then
			h = hb * ((t + k.tail + 1) / (k.tail + 1)) ^ 1.3
		elseif t > k.body then
			h = hb - (hb - 1) * (t - k.body) / k.neck
		end
		heights[t] = math.floor(h + 0.5)
	end
	for t = -k.tail, front do
		local y, nxt = heights[t], heights[t + 1]
		if t > -k.tail or rng:next(1, 100) > 40 then -- the tip of the tail may be lost
			set(t, 0, y, bone.full, along)
		end
		if nxt == y + 1 then
			set(t, 0, nxt, bone.stair, towards(ax, az))
		elseif nxt == y - 1 then
			set(t + 1, 0, y, bone.stair, towards(-ax, -az))
		end
	end

	-- ribs arching down to the ground, every other node of the ribcage
	local w = k.ribs
	local function arch(u)
		return hb * math.sqrt(math.max(0, 1 - (u / (w + 0.5)) ^ 2))
	end
	for t = 0, k.body, 2 do
		for side = -1, 1, 2 do
			if rng:next(1, 100) <= 85 then
				local reach = rng:next(1, 100) <= 25 and rng:next(1, w) or w -- broken ribs
				local prev = hb
				for s = 1, reach do
					local lo = s == w and 0 or math.floor(arch(s + 0.5) + 0.5)
					local hi = math.max(lo, math.floor(arch(s - 0.5) + 0.5))
					for y = lo, hi do
						if y == hi and s > 1 and (s == w or hi < prev) then
							set(t, s * side, y, bone.stair, towards(-side * px, -side * pz))
						else
							set(t, s * side, y, bone.full, s == w and 0 or across)
						end
					end
					prev = hi
				end
			end
		end
	end

	-- limbs at the hips and shoulders, toes or flippers at their ends
	for _, t in ipairs({0, k.body}) do
		for side = -1, 1, 2 do
			if rng:next(1, 100) <= 80 then
				for s = w + 1, w + k.limbs do
					set(t, s * side, s == w + 1 and 1 or 0, bone.full, across)
				end
				if not k.marine then
					local cid, p2 = piece(bone, rng)
					set(t, (w + k.limbs + 1) * side, 1, cid, p2)
				end
			end
		end
	end

	-- skull resting on the ground, lower jaw in it
	for i = 0, k.skull - 1 do
		local t = front + 1 + i
		set(t, 0, 0, bone.full, along)
		if i == k.skull - 1 then
			set(t, 0, 1, bone.stair, towards(-ax, -az)) -- tip of the snout
		else
			set(t, 0, 1, bone.full, along)
		end
		if i == 0 and k.skull >= 3 then
			set(t, 0, 2, bone.full, along)
			set(t, 1, 1, bone.full, along)
			set(t, -1, 1, bone.full, along)
		elseif i == 1 and k.skull >= 3 then
			set(t, 0, 2, bone.stair, towards(-ax, -az))
			set(t, 1, 1, bone.slab, 0)
			set(t, -1, 1, bone.slab, 0)
		elseif i == 0 then
			set(t, 1, 1, bone.slab, 0)
			set(t, -1, 1, bone.slab, 0)
		end
	end
	if not k.marine and bone.micro then
		for side = -1, 1, 2 do
			set(front + k.skull, side, 1, bone.micro, rng:next(0, 3)) -- teeth
		end
	end

	-- a few bones scattered around
	if not k.marine then
		for _ = 1, rng:next(3, 6) do
			local t, s = rng:next(-k.tail, front + k.skull), rng:next(-w - 2, w + 2)
			local x, z = ox + ax * t + px * s, oz + az * t + pz * s
			if get(b, x, y0 + 1, z) == c.air then
				local cid, p2 = piece(bone, rng)
				put(b, x, y0 + 1, z, cid, p2)
			end
		end
	end
end

-- Columns around a skeleton from its hips at (ox, oz), as a rectangle.
local function skeleton_rect(ox, oz, ax, az, k)
	local back, ahead = -k.tail - 1, k.body + k.neck + k.skull + 1
	local half = k.ribs + k.limbs + 2
	local px, pz = az, ax
	local xa, za = ox + ax * back - px * half, oz + az * back - pz * half
	local xb, zb = ox + ax * ahead + px * half, oz + az * ahead + pz * half
	return math.min(xa, xb), math.min(za, zb), math.max(xa, xb), math.max(za, zb)
end

-- Ground level for a skeleton over a rectangle, or nil: a flat dry floor, or
-- a flat sea floor deep enough under the water, inside the mapchunk and free
-- above.
local function skeleton_site(ctx, x0, z0, x1, z1, marine, height)
	if x0 < ctx.minp.x or z0 < ctx.minp.z or x1 > ctx.maxp.x or z1 > ctx.maxp.z then
		return nil
	end
	local floors, ceilings, reserved = ctx.floors, ctx.ceilings, ctx.reserved
	local sum, n = 0, 0
	for z = z0, z1 do
		for x = x0, x1 do
			local i = index(ctx, x, z)
			local f = floors[i]
			if not f or reserved[i] or (marine and f > ctx.sea - height - 3)
					or (not marine and f <= ctx.sea + 1) then
				return nil
			end
			sum, n = sum + f, n + 1
		end
	end
	local y0 = math.floor(sum / n + 0.5)
	if y0 - 1 < ctx.minp.y or y0 + height + 1 > ctx.maxp.y then
		return nil
	end
	local free = marine and c.water or c.air
	for z = z0, z1 do
		for x = x0, x1 do
			local i = index(ctx, x, z)
			local f = floors[i]
			if math.abs(f - y0) > 1 or ceilings[i] < y0 + height + 2 then
				return nil
			end
			for y = f + 1, y0 + height + 1 do
				if ctx.data[ctx.area:index(x, y, z)] ~= free then
					return nil
				end
			end
		end
	end
	return y0
end

local function try_skeleton(ctx, marine)
	local rng = ctx.rng
	local kinds = marine and SKELETONS.sea or SKELETONS.land
	for _ = 1, 40 do
		local kind = kinds[rng:next(1, #kinds)]
		local k = {tail = rng:next(kind.tail[1], kind.tail[2]), body = rng:next(kind.body[1], kind.body[2]),
			neck = rng:next(kind.neck[1], kind.neck[2]), skull = kind.skull, height = kind.height,
			ribs = kind.ribs, limbs = kind.limbs, marine = marine}
		local ax, az = 0, rng:next(0, 1) * 2 - 1
		if rng:next(1, 2) == 1 then
			ax, az = az, 0
		end
		-- hips placed so that the whole skeleton is in the mapchunk
		local rx0, rz0, rx1, rz1 = skeleton_rect(0, 0, ax, az, k)
		local ox = rng:next(ctx.minp.x - rx0, ctx.maxp.x - rx1)
		local oz = rng:next(ctx.minp.z - rz0, ctx.maxp.z - rz1)
		local f = ctx.floors[index(ctx, ox, oz)]
		local x0, z0, x1, z1 = skeleton_rect(ox, oz, ax, az, k)
		local y0 = f and (marine and f < ctx.sea - k.height - 3 or not marine and f > ctx.sea + 1)
			and skeleton_site(ctx, x0, z0, x1, z1, marine, k.height)
		if y0 then
			for z = z0, z1 do
				for x = x0, x1 do
					local i = index(ctx, x, z)
					local top = ctx.data[ctx.area:index(x, ctx.floors[i], z)]
					if marine then
						level(ctx, x, z, y0, top, top, c.water)
					else
						level(ctx, x, z, y0, top)
					end
					ctx.reserved[i] = true
				end
			end
			ctx.footprints[#ctx.footprints + 1] = {x0, z0, x1, z1}
			build_skeleton({ctx = ctx, rng = rng, y0 = y0}, ox, oz, ax, az, k)
			return
		end
	end
end

-- Builds the structures of a level in the mapchunk, after its terrain. ctx
-- holds the mapgen buffers (data, param2, floors, ceilings, reserved: columns
-- the decorations and creatures leave alone) and gathers the footprints of
-- the structures and the chests to fill once the mapchunk is written.
function structures.build(ctx)
	if not initialized then
		init()
	end
	local rng = ctx.rng
	if ruins and ctx.side > 2 * (SITE_RADIUS + 3) and rng:next(1, 100) <= RUIN_CHANCE then
		try_site(ctx)
	end
	if skeletons and rng:next(1, 100) <= SKELETON_CHANCE then
		try_skeleton(ctx, false)
	end
	if skeletons and c.water and rng:next(1, 100) <= SEA_SKELETON_CHANCE then
		try_skeleton(ctx, true)
	end
end

-- Whether (x, z) is within `margin` nodes of a structure built in this
-- mapchunk.
function structures.near(ctx, x, z, margin)
	for _, r in ipairs(ctx.footprints) do
		if x >= r[1] - margin and x <= r[3] + margin and z >= r[2] - margin and z <= r[4] + margin then
			return true
		end
	end
	return false
end

-- What the cavemen left in their chests: food, charcoal, flint, a stone
-- weapon, amber and the odd fossil.
local LOOT = {
	{"paleotest:dinosaur_meat_cooked", 1, 4, 70},
	{"default:coal_lump", 2, 6, 60},
	{"default:flint", 1, 3, 50},
	{"paleocave:amber", 1, 3, 40},
	{"default:sword_stone", 1, 1, 25},
	{"paleotest:fossil", 1, 2, 30},
	{"paleocave:mosquito_in_amber", 1, 1, 20},
	{"paleocave:tree_star", 1, 3, 25},
	{"paleotest:seeds_cycad", 1, 2, 15},
}

-- Fills the chests of the ruins once their mapchunk is written.
function structures.fill_chests(list)
	local def = core.registered_nodes["default:chest"]
	for _, pos in ipairs(list) do
		if def.on_construct then
			def.on_construct(pos)
		end
		local inv = core.get_meta(pos):get_inventory()
		if inv:get_size("main") == 0 then
			inv:set_size("main", 32)
		end
		local rng = PcgRandom(core.hash_node_position(pos))
		for _, entry in ipairs(LOOT) do
			if core.registered_items[entry[1]] and rng:next(1, 100) <= entry[4] then
				inv:add_item("main", entry[1] .. " " .. rng:next(entry[2], entry[3]))
			end
		end
	end
end
