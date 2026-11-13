#!/usr/bin/env bash
# Test de chargement : démarre un serveur Luanti headless (vrai moteur) avec paleocave, ses
# dépendances et les mods de .claude/test_mods.txt, dans un monde TEMPORAIRE hors du projet,
# laisse tourner quelques secondes, arrête, puis analyse le log.
# Sans joueur, aucun chunk n'est généré : la génération se teste avec smoke_test.sh.
#
# Usage : .claude/skills/luanti-test-debug/scripts/load_test.sh [secondes_après_démarrage]
# Variables : LUANTI_BIN, GAMEID (minetest), EXTRA_WORLDMODS, START_TIMEOUT (60),
#             MG_NAME (v7 ; en singlenode, mapgen.lua s'arrête dès le début)
# Codes : 0 = OK, 1 = erreurs/avertissements du mod, 2 = impossible de lancer.

set -uo pipefail
. "$(dirname "$0")/lib.sh"

RUN_AFTER_START="${1:-5}"
START_TIMEOUT="${START_TIMEOUT:-60}"
MG_NAME="${MG_NAME:-v7}"

LUANTI="$(find_luanti)" || { echo "ERREUR : binaire Luanti introuvable (définir LUANTI_BIN)."; exit 2; }
require_mods

# --- Monde temporaire --------------------------------------------------------
WORK="${TMPDIR:-/tmp}/${MODNAME}_loadtest"
WORLD="$WORK/world"
LOG="$WORK/debug.txt"
CONF="$WORK/test.conf"
rm -rf "$WORK"
make_world "$WORLD" false

cat > "$CONF" <<CONF
mg_name = $MG_NAME
bind_address = 127.0.0.1
server_announce = false
enable_rollback_recording = false
deprecated_lua_api_handling = log
debug_log_level = action
CONF

echo "Luanti : $("$LUANTI" --version 2>/dev/null | head -1)  |  jeu : $GAMEID  |  mod : $MODNAME  |  mapgen : $MG_NAME"
mods="$(test_mods | tr '\n' ' ')"
[ -n "$mods" ] && echo "Mods de test : $mods"
extra="$(extra_worldmods | tr '\n' ' ')"
[ -n "$extra" ] && echo "Mods par chemin : $extra"

PID="$(start_server "$WORLD" "$CONF" "$LOG" "$WORK/console.txt")"

# --- Attente du démarrage puis arrêt ----------------------------------------
started=0; t=0
while kill -0 "$PID" 2>/dev/null; do
	if grep -q "listening on" "$LOG" 2>/dev/null; then started=1; break; fi
	[ "$t" -ge "$START_TIMEOUT" ] && break
	sleep 1; t=$((t + 1))
done
[ "$started" = 1 ] && sleep "$RUN_AFTER_START"   # laisse tourner core.after / timers / ABM
stop_server "$PID"

# --- Analyse -----------------------------------------------------------------
echo "------------------------------------------------------------------"
status=0
if [ "$started" != 1 ]; then
	echo "ÉCHEC : le serveur n'a pas démarré (crash au chargement ou timeout ${START_TIMEOUT}s)."
	status=1
fi
analyse_log "$LOG" || status=1
[ "$status" = 0 ] && echo "OK : '$MODNAME' se charge sans erreur ni avertissement."
echo "Log complet : $LOG"
exit $status
