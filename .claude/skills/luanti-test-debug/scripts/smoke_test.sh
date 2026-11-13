#!/usr/bin/env bash
# Test de génération dans le vrai moteur : monde TEMPORAIRE hors du projet (mapgen v7, graine
# fixe, carte de ±10000). Un mod d'aide, écrit dans ce monde et jamais dans le projet, génère le
# centre d'une caverne primordiale (avec le cratère de son volcan) par core.emerge_area, puis
# compte les nœuds et, dans la caverne et ses parois : l'eau et la lave en contact avec le vide
# (fuites), les liquides qui coulent, les blocs de donjon à l'air libre, la part du sol éclairé ;
# et les créatures placées. Puis il arrête le serveur.
#
# Usage : .claude/skills/luanti-test-debug/scripts/smoke_test.sh
# Variables : SEED (42), LEVEL (1 : n° de la caverne, 1 à 5), HALF (80 : demi-côté de la zone ;
#             260 : toute la caverne, avec ses bords, plus long),
#             SMOKE_TIMEOUT (300 s), LUANTI_BIN, GAMEID (minetest), EXTRA_WORLDMODS
# Codes : 0 = OK, 1 = erreur, fuite d'eau ou de lave, donjon visible ou génération inachevée,
#         2 = impossible de lancer.

set -uo pipefail
. "$(dirname "$0")/lib.sh"

SEED="${SEED:-42}"
LEVEL="${LEVEL:-1}"
HALF="${HALF:-80}"
TIMEOUT="${SMOKE_TIMEOUT:-300}"
HELPER_NAME="${MODNAME}_smoke"

LUANTI="$(find_luanti)" || { echo "ERREUR : binaire Luanti introuvable (définir LUANTI_BIN)."; exit 2; }
require_mods

# --- Monde temporaire et mod d'aide -----------------------------------------
WORK="${TMPDIR:-/tmp}/${MODNAME}_smoketest"
WORLD="$WORK/world"
LOG="$WORK/debug.txt"
CONF="$WORK/test.conf"
rm -rf "$WORK"
make_world "$WORLD" false
HELPER="$WORLD/worldmods/$HELPER_NAME"
mkdir -p "$HELPER"
printf 'name = %s\ndepends = %s\n' "$HELPER_NAME" "$MODNAME" > "$HELPER/mod.conf"
cat > "$HELPER/init.lua" <<'LUA'
-- Mod d'aide du smoke test de paleocave (monde temporaire uniquement).
local TAG = "[paleocave_smoke] "
local LEVEL = tonumber(core.settings:get("paleocave_smoke_level")) or 1
local HALF = tonumber(core.settings:get("paleocave_smoke_half")) or 80

local function log(msg)
	core.log("action", TAG .. msg)
end

-- Créatures ajoutées par le générateur (core.after après chaque mapchunk), comptées au passage.
local calls, added = {}, {}
local add_entity = core.add_entity
core.add_entity = function(pos, name, ...)
	local obj = add_entity(pos, name, ...)
	calls[name] = (calls[name] or 0) + 1
	if obj then
		added[name] = (added[name] or 0) + 1
	end
	return obj
end

local function listing(counts, total)
	local list = {}
	for name, n in pairs(counts) do
		list[#list + 1] = {name = name, n = n}
	end
	table.sort(list, function(a, b) return a.n > b.n end)
	local out = {}
	for k, e in ipairs(list) do
		if total and k > total then
			break
		end
		out[#out + 1] = e.name .. "=" .. e.n
	end
	return #out > 0 and table.concat(out, " ") or "aucune"
end

local function report(level, p1, p2, t0)
	local seconds = (core.get_us_time() - t0) / 1e6
	local id = core.get_content_id
	local c_air, c_light = id("air"), id("paleocave:ambersol_light")
	local c_grass, c_lava = id("paleocave:primordial_grass"), id("default:lava_source")
	-- liquides ("source" ou "flowing") et blocs des donjons du générateur de carte
	local liquid, dungeon, walkable = {}, {}, {}
	for name, def in pairs(core.registered_nodes) do
		walkable[id(name)] = def.walkable ~= false
		if def.liquidtype == "source" or def.liquidtype == "flowing" then
			liquid[id(name)] = def.liquidtype
		end
	end
	for _, name in ipairs({"default:cobble", "default:mossycobble", "stairs:stair_cobble",
			"stairs:stair_mossycobble"}) do
		if core.registered_nodes[name] then
			dungeon[id(name)] = true
		end
	end
	-- colonnes de la caverne ou de ses parois de calcaire (ailleurs : grottes ordinaires)
	local caves, cavern = paleocave.caves, {}
	for z = p1.z, p2.z do
		for x = p1.x, p2.x do
			local inside = (x - level.x) ^ 2 + (z - level.z) ^ 2 < level.radius ^ 2
			cavern[(z - p1.z) * (p2.x - p1.x + 1) + (x - p1.x)] =
				inside and select(5, caves.column_model(level, x, z)) or false
		end
	end
	local by_id, leaks, floors, lit, dark = {}, 0, 0, 0, 0
	local lava_leaks, lava, flowing, exposed = 0, 0, 0, 0
	local function void(n)
		return n == c_air or n == c_light
	end
	-- lecture par tranches de 16 rangées (avec une couche de plus tout autour : les voisins
	-- des bords sont lus aussi), pour tenir en mémoire même pour toute la caverne
	local vm, data, light = core.get_voxel_manip(), {}, {}
	for z0 = p1.z, p2.z, 16 do
		local z1 = math.min(z0 + 15, p2.z)
		local e1, e2 = vm:read_from_map(vector.new(p1.x - 1, p1.y - 1, z0 - 1), vector.new(p2.x + 1, p2.y + 1, z1 + 1))
		local area = VoxelArea:new({MinEdge = e1, MaxEdge = e2})
		data, light = vm:get_data(data), vm:get_light_data(light)
		local ystride, zstride = area.ystride, area.zstride
		local around = {-1, 1, -zstride, zstride, -ystride}
		local all = {-1, 1, -zstride, zstride, -ystride, ystride}
		for z = z0, z1 do
			for y = p1.y, p2.y do
				local vi = area:index(p1.x, y, z)
				local ci = (z - p1.z) * (p2.x - p1.x + 1)
				for x = p1.x, p2.x do
					local cid = data[vi]
					by_id[cid] = (by_id[cid] or 0) + 1
					local mine = cavern[ci + x - p1.x]
					if cid == c_lava then
						lava = lava + 1
					end
					if not mine then -- luacheck: ignore 542
						-- hors de la caverne : rien à vérifier
					elseif liquid[cid] == "source" then
						-- liquide à côté ou au-dessus d'un vide : il coulerait
						for _, d in ipairs(around) do
							if void(data[vi + d]) then
								if cid == c_lava then
									lava_leaks = lava_leaks + 1
								else
									leaks = leaks + 1
								end
								break
							end
						end
					elseif liquid[cid] == "flowing" then
						flowing = flowing + 1
					elseif dungeon[cid] then
						for _, d in ipairs(all) do
							if void(data[vi + d]) then
								exposed = exposed + 1
								break
							end
						end
					elseif cid == c_grass and not walkable[data[vi + ystride]] then
						floors = floors + 1
						local l = light[vi + ystride] % 16
						if l >= 8 then
							lit = lit + 1
						elseif l < 4 then
							dark = dark + 1
						end
					end
					vi = vi + 1
				end
			end
		end
	end
	local by_name = {}
	for cid, n in pairs(by_id) do
		by_name[core.get_name_from_content_id(cid)] = n
	end
	local wanted, placed = 0, 0
	for _, n in pairs(calls) do wanted = wanted + n end
	for _, n in pairs(added) do placed = placed + n end
	log(("zone générée en %.1f s"):format(seconds))
	log("nœuds : " .. listing(by_name, 40))
	log("créatures placées : " .. listing(added) .. (" (%d/%d ajouts réussis)"):format(placed, wanted))
	log(("bilan : fuites=%d fuites_lave=%d coule=%d donjon=%d lave=%d sol=%d sol_eclaire=%d%% sol_sombre=%d%%"):format(
		leaks, lava_leaks, flowing, exposed, lava, floors,
		floors > 0 and math.floor(100 * lit / floors + 0.5) or 0,
		floors > 0 and math.floor(100 * dark / floors + 0.5) or 0))
	core.request_shutdown("paleocave smoke test done", false, 0)
end

core.after(1, function()
	local levels = paleocave.caves.get_levels()
	local where = {}
	for k, l in ipairs(levels) do
		where[#where + 1] = ("%d:(%d, %d) mer %d"):format(k, l.x, l.z, l.sea)
	end
	log("cavernes : " .. table.concat(where, "  "))
	local level = levels[LEVEL]
	if level and level.volcano then
		local v = level.volcano
		log(("volcan de la caverne %d : (%d, %d), lave à %d, bord à %d"):format(LEVEL, v.x, v.z, v.lava, v.rim))
	end
	if not level then
		core.log("error", TAG .. "pas de caverne n°" .. LEVEL)
		core.request_shutdown("paleocave smoke test failed", false, 0)
		return
	end
	local p1 = {x = level.x - HALF, y = level.ymin, z = level.z - HALF}
	local p2 = {x = level.x + HALF, y = level.ymax, z = level.z + HALF}
	log(("caverne %d : génération de %s à %s"):format(LEVEL, core.pos_to_string(p1), core.pos_to_string(p2)))
	local t0 = core.get_us_time()
	core.emerge_area(vector.subtract(p1, 1), vector.add(p2, 1), function(_, _, remaining)
		if remaining == 0 then
			core.after(2, report, level, p1, p2, t0) -- les créatures arrivent au pas suivant
		end
	end)
end)
LUA

cat > "$CONF" <<CONF
mg_name = v7
fixed_map_seed = $SEED
mapgen_limit = 10000
bind_address = 127.0.0.1
server_announce = false
enable_rollback_recording = false
deprecated_lua_api_handling = log
debug_log_level = action
paleocave_smoke_level = $LEVEL
paleocave_smoke_half = $HALF
CONF

echo "Luanti : $("$LUANTI" --version 2>/dev/null | head -1)  |  jeu : $GAMEID  |  graine : $SEED  |  caverne $LEVEL, zone ±$HALF"
PID="$(start_server "$WORLD" "$CONF" "$LOG" "$WORK/console.txt")"

# --- Attente de la fin (le mod d'aide arrête le serveur) --------------------
t=0
while kill -0 "$PID" 2>/dev/null; do
	[ "$t" -ge "$TIMEOUT" ] && break
	sleep 1; t=$((t + 1))
done
stop_server "$PID"

# --- Analyse -----------------------------------------------------------------
echo "------------------------------------------------------------------"
status=0
analyse_log "$LOG" || status=1
bilan="$(grep "\[$HELPER_NAME\] bilan" "$LOG")"
if [ -z "$bilan" ]; then
	echo "ÉCHEC : génération inachevée en ${TIMEOUT}s (ou serveur arrêté avant)."
	status=1
else
	if ! echo "$bilan" | grep -q "fuites=0 "; then
		echo "ÉCHEC : de l'eau touche le vide (elle coulera dans la caverne)."
		status=1
	fi
	if ! echo "$bilan" | grep -q "fuites_lave=0 "; then
		echo "ÉCHEC : de la lave touche le vide (elle coulera)."
		status=1
	fi
	if ! echo "$bilan" | grep -q "coule=0 "; then
		echo "ÉCHEC : de l'eau ou de la lave coule déjà dans la caverne."
		status=1
	fi
	if ! echo "$bilan" | grep -q "donjon=0 "; then
		echo "ÉCHEC : des blocs de donjon sont à l'air libre dans la caverne."
		status=1
	fi
	if echo "$bilan" | grep -q " lave=0 "; then
		echo "Attention : pas de lave dans la zone (cratère du volcan hors zone ?)."
	fi
fi
[ "$status" = 0 ] && echo "OK : caverne $LEVEL générée sans erreur, sans fuite d'eau ni de lave, sans donjon visible."
echo "Log complet : $LOG"
exit $status
