# Fonctions communes aux scripts de test de paleocave (vrai moteur Luanti).
# À sourcer, pas à exécuter :   . "$(dirname "$0")/lib.sh"
#
# Variables reconnues :
#   LUANTI_BIN       binaire Luanti (sinon : PATH, /Applications, ~/Downloads/luanti.app)
#   LUANTI_USER_DIR  données utilisateur (sinon ~/Library/Application Support/luanti ou minetest)
#   GAMEID           jeu (défaut : minetest = Minetest Game)
#   EXTRA_WORLDMODS  "chemin1:chemin2" : mods pris par chemin, sans les installer
#                    (ex. des clones de paleotest, mob_core et mobkit)

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
CLAUDE_DIR="$MOD_DIR/.claude"
SCRIPTS_DIR="$CLAUDE_DIR/skills/luanti-test-debug/scripts"
MODNAME="$(sed -n 's/^name *= *//p' "$MOD_DIR/mod.conf" | tr -d '[:space:]')"
GAMEID="${GAMEID:-minetest}"

if [ -n "${LUANTI_USER_DIR:-}" ]; then USER_DIR="$LUANTI_USER_DIR"
elif [ -d "$HOME/Library/Application Support/luanti" ]; then USER_DIR="$HOME/Library/Application Support/luanti"
else USER_DIR="$HOME/Library/Application Support/minetest"; fi

# Chemin du binaire Luanti, ou échec.
find_luanti() {
	local c
	for c in "${LUANTI_BIN:-}" "$(command -v luanti 2>/dev/null)" \
		"/Applications/Luanti.app/Contents/MacOS/luanti" \
		"/Applications/luanti.app/Contents/MacOS/luanti" \
		"$HOME/Downloads/luanti.app/Contents/MacOS/luanti"; do
		if [ -n "$c" ] && [ -x "$c" ]; then echo "$c"; return 0; fi
	done
	return 1
}

# Dossier du jeu (l'id "minetest" correspond au dossier minetest_game).
game_dir() {
	local d
	for d in "$USER_DIR/games/$GAMEID" "$USER_DIR/games/${GAMEID}_game"; do
		[ -d "$d" ] && { echo "$d"; return 0; }
	done
	return 1
}

# Noms des mods sous un dossier (le dossier lui-même, ses mods ou ceux de ses modpacks).
mods_in() {
	[ -d "$1" ] || return 0
	find -L "$1" -maxdepth 3 -name init.lua 2>/dev/null | while IFS= read -r f; do
		dir="$(dirname "$f")"
		name="$(sed -n 's/^name *= *//p' "$dir/mod.conf" 2>/dev/null | tr -d '[:space:]')"
		echo "${name:-$(basename "$dir")}"
	done
	return 0
}

# Chemins existants de EXTRA_WORLDMODS, un par ligne.
extra_worldmods() {
	local p IFS=':'
	for p in ${EXTRA_WORLDMODS:-}; do
		[ -d "$p" ] && echo "$p"
	done
	return 0
}

# Mods de .claude/test_mods.txt, un par ligne.
test_mods() {
	[ -f "$CLAUDE_DIR/test_mods.txt" ] || return 0
	sed -e 's/#.*//' -e 's/[[:space:]]//g' "$CLAUDE_DIR/test_mods.txt" | grep -v '^$'
	return 0
}

# Dépendances obligatoires du mod (depends de mod.conf).
hard_depends() {
	sed -n 's/^depends *= *//p' "$MOD_DIR/mod.conf" | tr ',' '\n' | tr -d ' \t\r' | grep -v '^$'
	return 0
}

# Mods requis (dépendances + test_mods.txt) introuvables dans le jeu, dans <user>/mods et
# dans EXTRA_WORLDMODS, un par ligne.
missing_mods() {
	local available gd
	gd="$(game_dir)"
	available="$( {
		[ -n "$gd" ] && mods_in "$gd/mods"
		mods_in "$USER_DIR/mods"
		extra_worldmods | while IFS= read -r p; do mods_in "$p"; done
	} | sort -u)"
	{ hard_depends; test_mods; } | sort -u | while IFS= read -r m; do
		echo "$available" | grep -qx "$m" || echo "$m"
	done
	return 0
}

# Arrête le script (code 2) si des mods requis manquent.
require_mods() {
	local missing
	missing="$(missing_mods)"
	[ -z "$missing" ] && return 0
	echo "ERREUR : mods requis introuvables : $(echo $missing)"
	echo "  Les installer dans $USER_DIR/mods (et les lister dans .claude/test_mods.txt),"
	echo "  ou les passer par chemin sans installation : EXTRA_WORLDMODS=chemin1:chemin2"
	exit 2
}

# Lie un mod (ou un modpack) dans un dossier worldmods/, sous le nom de son mod.conf.
link_worldmod() {
	local src="$1" dest="$2" name=""
	[ -f "$src/init.lua" ] && name="$(sed -n 's/^name *= *//p' "$src/mod.conf" 2>/dev/null | tr -d '[:space:]')"
	ln -sfn "$src" "$dest/${name:-$(basename "$src")}"
}

# Crée un monde dans $1 : le mod et les EXTRA_WORLDMODS liés dans worldmods/, les mods de
# test_mods.txt activés (sauf ceux déjà fournis par EXTRA_WORLDMODS). $2 : creative (true/false).
make_world() {
	local world="$1" creative="${2:-false}" extra_names="" p m
	mkdir -p "$world/worldmods"
	link_worldmod "$MOD_DIR" "$world/worldmods"
	while IFS= read -r p; do
		[ -n "$p" ] || continue
		link_worldmod "$p" "$world/worldmods"
		extra_names="$extra_names $(mods_in "$p" | tr '\n' ' ')"
	done < <(extra_worldmods)
	{
		echo "gameid = $GAMEID"
		echo "world_name = $(basename "$world")"
		echo "backend = sqlite3"
		echo "auth_backend = sqlite3"
		echo "player_backend = sqlite3"
		echo "mod_storage_backend = sqlite3"
		echo "creative_mode = $creative"
		if [ "$creative" = true ]; then echo "enable_damage = false"; else echo "enable_damage = true"; fi
		while IFS= read -r m; do
			case " $extra_names " in *" $m "*) ;; *) echo "load_mod_$m = true" ;; esac
		done < <(test_mods)
	} > "$world/world.mt"
}

# Démarre un serveur headless en arrière-plan. $1 monde, $2 config, $3 log, $4 sortie console.
# Affiche le PID.
start_server() {
	local port=$((30100 + RANDOM % 800))
	"$LUANTI" --server --world "$1" --gameid "$GAMEID" --config "$2" \
		--port "$port" --logfile "$3" --log-timestamp none >"$4" 2>&1 &
	echo $!
}

# Arrête le serveur $1 (proprement, puis de force).
stop_server() {
	kill "$1" 2>/dev/null
	for _ in 1 2 3 4 5; do kill -0 "$1" 2>/dev/null || break; sleep 1; done
	kill -9 "$1" 2>/dev/null
	wait "$1" 2>/dev/null
	return 0
}

# Classe le log $1 : messages du mod, erreurs, avertissements. Code 1 si erreur ou si un
# avertissement cite le mod. Ceux des autres mods (PaleoTest, mobkit...) sont seulement affichés.
analyse_log() {
	local log="$1" errors warnings mine others own status=0
	local self="$MODNAME|$MOD_DIR/"
	errors="$(grep -E "ERROR\[|ModError|Runtime error|stack traceback" "$log" 2>/dev/null)"
	# (un même mod présent à la fois dans worldmods/ et dans <user>/mods est attendu)
	warnings="$(grep -E "WARNING\[" "$log" 2>/dev/null \
		| grep -v -E "Mod name conflict detected|Will not load: |Overridden by: ")"
	mine="$(echo "$warnings" | grep -E "$self")"
	others="$(echo "$warnings" | grep -v -E "$self" | grep -i -E "deprecated|unknown|undeclared|global")"
	own="$(grep -E "\[$MODNAME[a-z_]*\]" "$log" 2>/dev/null)"
	[ -n "$own" ] && { echo "Messages du mod :"; echo "$own" | sed 's/^/  /'; }
	if [ -n "$errors" ]; then
		echo "ERREURS :"; grep -E -A 12 "ERROR\[|ModError|Runtime error" "$log" | sed 's/^/  /' | head -60
		status=1
	fi
	if [ -n "$mine" ]; then
		echo "AVERTISSEMENTS DU MOD :"
		echo "$mine" | sort | uniq -c | sort -rn | sed 's/^/  /' | head -40
		status=1
	fi
	if [ -n "$others" ]; then
		echo "Avertissements des autres mods (non bloquants, $(echo "$others" | wc -l | tr -d ' ') lignes) :"
		echo "$others" | sed -E 's/\(Property .* in entity .*\)/(…)/' | sort | uniq -c | sort -rn \
			| sed 's/^/  /' | head -8
	fi
	return $status
}
