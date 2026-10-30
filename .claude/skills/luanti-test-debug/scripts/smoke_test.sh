#!/usr/bin/env bash
# Smoke test du mod paleocave dans un jeu Luanti déjà installé.
# Crée un monde jetable, y lie le mod (worldmods/paleocave), génère une zone
# du premier niveau des cavernes primordiales, compte les nœuds puis s'arrête.
# Usage (depuis la racine du mod) :
#   GAMEID=<id du jeu> bash .claude/skills/luanti-test-debug/scripts/smoke_test.sh
# Variables : GAMEID (obligatoire), SMOKE_SECONDS (défaut 90), LUANTI_BIN
set -uo pipefail

MOD_DIR="$PWD"
[ -f "$MOD_DIR/mod.conf" ] || { echo "Lancer depuis la racine du mod (mod.conf introuvable)." >&2; exit 2; }
[ -n "${GAMEID:-}" ] || { echo "Définir GAMEID (id du jeu qui contient paleotest)." >&2; exit 2; }
TIMEOUT="${SMOKE_SECONDS:-90}"

BIN="${LUANTI_BIN:-}"
if [ -z "$BIN" ]; then
	for c in luanti minetest /Applications/Luanti.app/Contents/MacOS/luanti \
		/Applications/minetest.app/Contents/MacOS/minetest; do
		if command -v "$c" >/dev/null 2>&1; then BIN="$(command -v "$c")"; break; fi
	done
fi
[ -n "$BIN" ] && [ -x "$BIN" ] || { echo "Luanti introuvable (définir LUANTI_BIN)." >&2; exit 2; }

TMP="$(mktemp -d)"
WORLD="$TMP/world"
LOG="$TMP/debug.txt"
mkdir -p "$WORLD/worldmods/paleocave_smoke"
ln -s "$MOD_DIR" "$WORLD/worldmods/paleocave"
printf 'gameid = %s\n' "$GAMEID" > "$WORLD/world.mt"

cat > "$WORLD/worldmods/paleocave_smoke/mod.conf" <<'EOF'
name = paleocave_smoke
depends = paleocave
EOF
cat > "$WORLD/worldmods/paleocave_smoke/init.lua" <<'EOF'
local p1, p2 = {x = -40, y = -2160, z = -40}, {x = 40, y = -2060, z = 40}
core.after(2, function()
	core.emerge_area(p1, p2, function(_, _, remaining)
		if remaining > 0 then return end
		local names = {"paleocave:limestone", "paleocave:primordial_grass", "paleocave:amber",
			"paleocave:archaic_vine", "default:water_source", "air"}
		local report = {}
		for _, name in ipairs(names) do
			report[#report + 1] = name .. "=" .. #core.find_nodes_in_area(p1, p2, name)
		end
		core.log("action", "[paleocave_smoke] " .. table.concat(report, " "))
		core.request_shutdown("paleocave smoke test done")
	end)
end)
EOF

cat > "$TMP/minetest.conf" <<'EOF'
deprecated_lua_api_handling = log
debug_log_level = action
server_announce = false
bind_address = 127.0.0.1
port = 30987
EOF

echo "Luanti : $BIN   jeu : $GAMEID"
echo "Monde  : $WORLD"
"$BIN" --server --world "$WORLD" --config "$TMP/minetest.conf" --logfile "$LOG" >/dev/null 2>&1 &
PID=$!
for _ in $(seq "$TIMEOUT"); do
	kill -0 "$PID" 2>/dev/null || break
	sleep 1
done
kill "$PID" 2>/dev/null; wait "$PID" 2>/dev/null

[ -s "$LOG" ] || { echo "Log vide : le serveur n'a pas démarré." >&2; exit 1; }
errors=$(grep -c "ERROR\[" "$LOG" || true)
echo "--- RAPPORT"
grep "\[paleocave_smoke\]" "$LOG" || echo "(pas de rapport : la génération n'a pas abouti dans le délai)"
echo "--- ERREURS ($errors)"
grep -A 15 "ERROR\[" "$LOG" | head -60
echo "--- AVERTISSEMENTS uniques"
grep "WARNING\[" "$LOG" | sed 's/^[0-9: -]*//' | sort | uniq -c | sort -rn | head -30
echo "--- Log complet : $LOG"
[ "$errors" -eq 0 ] && grep -q "\[paleocave_smoke\]" "$LOG"
